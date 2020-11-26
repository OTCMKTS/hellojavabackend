#include <ruby.h>
#include <ruby/thread.h>
#include <pthread.h>
#include <errno.h>
#include "helpers.h"
#include "stack_recorder.h"
#include "libdatadog_helpers.h"
#include "ruby_helpers.h"

// Used to wrap a ddog_prof_Profile in a Ruby object and expose Ruby-level serialization APIs
// This file implements the native bits of the Datadog::Profiling::StackRecorder class

// ---
// ## Synchronization mechanism for safe parallel access design notes
//
// The state of the StackRecorder is managed using a set of locks to avoid concurrency issues.
//
// This is needed because the state is expected to be accessed, in parallel, by two different threads.
//
// 1. The thread that is taking a stack sample and that called `record_sample`, let's call it the **sampler thread**.
// In the current implementation of the profiler, there can only exist one **sampler thread** at a time; if this
// constraint changes, we should revise the design of the StackRecorder.
//
// 2. The thread that serializes and reports profiles, let's call it the **serializer thread**. We enforce that there
// cannot be more than one thread attempting to serialize profiles at a time.
//
// If both the sampler and serializer threads are trying to access the same `ddog_prof_Profile` in parallel, we will
// have a concurrency issue. Thus, the StackRecorder has an added mechanism to avoid this.
//
// As an additional constraint, the **sampler thread** has absolute priority and must never block while
// recording a sample.
//
// ### The solution: Keep two profiles at the same time
//
// To solve for the constraints above, the StackRecorder keeps two `ddog_prof_Profile` profile instances inside itself.
// They are called the `slot_one_profile` and `slot_two_profile`.
//
// Each profile is paired with its own mutex. `slot_one_profile` is protected by `slot_one_mutex` and `slot_two_profile`
// is protected by `slot_two_mutex`.
//
// We additionally introduce the concept of **active** and **inactive** profile slots. At any point, the sampler thread
// can probe the mutexes to discover which of the profiles corresponds to the active slot, and then records samples in it.
// When the serializer thread is ready to serialize data, it flips the active and inactive slots; it reports the data
// on the previously-active profile slot, and the sampler thread can continue to record in the previously-inactive
// profile slot.
//
// Thus, the sampler and serializer threads never cross paths, avoiding concurrency issues. The sampler thread writes to
// the active profile slot, and the serializer thread reads from the inactive profile slot.
//
// ### Locking protocol, high-level
//
// The active profile slot is the slot for which its corresponding mutex **is unlocked**. That is, if the sampler
// thread can grab a lock for a profile slot, then that slot is the active one. (Here you see where the constraint
// stated above that only one sampler thread can exist kicks in -- this part would need to be more complex if multiple
// sampler threads were in play.)
//
// As a counterpart, the inactive profile slot mutex is **kept locked** until such time the serializer
// thread is ready to work and decides to flip the slots.
//
// When a new StackRecorder is initialized, the `slot_one_mutex` is unlocked, and the `slot_two_mutex` is kept locked,
// that is, a new instance always starts with slot one active.
//
// Additionally, an `active_slot` field is kept, containing a `1` or `2`; this is only kept for the serializer thread
// to use as a simplification, as well as for testing and debugging; the **sampler thread must never use the `active_slot`
// field**.
//
// ### Locking protocol, from the sampler thread side
//
// When the sampler thread wants to record a sample, it goes through the following steps to discover which is the
// active profile slot:
//
// 1. `pthread_mutex_trylock(slot_one_mutex)`. If it succeeds to grab the lock, this means the active profile slot is
// slot one. If it fails, we move to the next step.
//
// 2. `pthread_mutex_trylock(slot_two_mutex)`. If it succeeds to grab the lock, this means the active profile slot is
// slot two. If it fails, we move to the next step.
//
// 3. What does it mean for the sampler thread to have observed both `slot_one_mutex` as well as `slot_two_mutex` as
// being locked? There are two options:
//   a. The sampler thread got really unlucky. When it tried to grab the `slot_one_mutex`, the active profile slot was
//     the second one BUT then the serializer thread flipped the slots, and by the time the sampler thread probed the
//     `slot_two_mutex`, that one was taken. Since the serializer thread is expected only to work once a minute,
//     we retry steps 1. and 2. and should be able to find an active slot.
//   b. Something is incorrect in the StackRecorder state. In this situation, the sampler thread should give up on
//     sampling and enter an error state.
//
// Note that in the steps above, and because the sampler thread uses `trylock` to probe the mutexes, that the
// sampler thread never blocks. It either is able to find an active profile slot in a bounded amount of steps or it
// enters an error state.
//
// This guarantees that sampler performance is never constrained by serializer performance.
//
// ### Locking protocol, from the serializer thread side
//
// When the serializer thread wants to serialize a profile, it first flips the active and inactive profile slots.
//
// The flipping action is described below. Consider previously-inactive and previously-active as the state of the slots
// before the flipping happens.
//
// The flipping steps are the following:
//
// 1. Release the mutex for the previously-inactive profile slot. That slot, as seen by the sampler thread, is now
// active.
//
// 2. Grab the mutex for the previously-active profile slot. Note that this can lead to the serializer thread blocking,
// if the sampler thread is holding this mutex. After the mutex is grabbed, the previously-active slot becomes inactive,
// as seen by the sampler thread.
//
// 3. Update `active_slot`.
//
// After flipping the profile slots, the serializer thread is now free to serialize the inactive profile slot. The slot
// is kept inactive until the next time the serializer thread wants to serialize data.
//
// Note there can be a brief period between steps 1 and 2 where the serializer thread holds no lock, which means that
// the sampler thread can pick either slot. This is OK: if the sampler thread picks the previously-inactive slot, the
// samples will be reported on the next serialization; if the sampler thread picks the previously-active slot, the
// samples are still included in the current serialization. Either option is correct.
//
// ### Additional notes
//
// Q: Can the sampler thread and the serializer thread ever be the same thread? (E.g. sampling in interrupt handler)
// A: No; the current profiler design requires that sampling happens only on the thread that is holding the Global VM
// Lock (GVL). The serializer thread flipping occurs after the serializer thread releases the GVL, and thus the
// serializer thread will not be able to host the sampling process.
//
// ---

static VALUE ok_symbol = Qnil; // :ok in Ruby
static VALUE error_symbol = Qnil; // :error in Ruby

static VALUE stack_recorder_class = Qnil;

// Note: Please DO NOT use `VALUE_STRING` anywhere else, instead use `DDOG_CHARSLICE_C`.
// `VALUE_STRING` is only needed because older versions of gcc (4.9.2, used in our Ruby 2.2 CI test images)
// tripped when compiling `enabled_value_types` using `-std=gnu99` due to the extra cast that is included in
// `DDOG_CHARSLICE_C` with the following error:
//
// ```
// compiling ../../../../ext/ddtrace_profiling_native_extension/stack_recorder.c
// ../../../../ext/ddtrace_profiling_native_extension/stack_recorder.c:23:1: error: initializer element is not constant
// static const ddog_prof_ValueType enabled_value_types[] = {CPU_TIME_VALUE, CPU_SAMPLES_VALUE, WALL_TIME_VALUE};
// ^
// ```
#define VALUE_STRING(string) {.ptr = "" string, .len = sizeof(string) - 1}

#define CPU_TIME_VALUE          {.type_ = VALUE_STRING("cpu-time"),          .unit = VALUE_STRING("nanoseconds")}
#define CPU_TIME_VALUE_ID 0
#define CPU_SAMPLES_VALUE       {.type_ = VALUE_STRING("cpu-samples"),       .unit = VALUE_STRING("count")}
#define CPU_SAMPLES_VALUE_ID 1
#define WALL_TIME_VALUE         {.type_ = VALUE_STRING("wall-time"),         .unit = VALUE_STRING("nanoseconds")}
#define WALL_TIME_VALUE_ID 2
#define ALLOC_SAMPLES_VALUE     {.type_ = VALUE_STRING("alloc-samples"),     .unit = VALUE_STRING("count")}
#define ALLOC_SAMPLES_VALUE_ID 3

static const ddog_prof_ValueType all_value_types[] = {CPU_TIME_VALUE, CPU_SAMPLES_VALUE, WALL_TIME_VALUE, ALLOC_SAMPLES_VALUE};

// This array MUST be kept in sync with all_value_types above and is intended to act as a "hashmap" between VALUE_ID and the position it
// occupies on the all_value_types array.
// E.g. all_value_types_positions[CPU_TIME_VALUE_ID] => 0, means that CPU_TIME_VALUE was declared at position 0 of all_value_types.
static const uint8_t all_value_types_positions[] = {CPU_TIME_VALUE_ID, CPU_SAMPLES_VALUE_ID, WALL_TIME_VALUE_ID, ALLOC_SAMPLES_VALUE_ID};

#define ALL_VALUE_TYPES_COUNT (sizeof(all_value_types) / sizeof(ddog_prof_ValueType))

// Contains native state for each instance
struct stack_recorder_state {
  pthread_mutex_t slot_one_mutex;
  ddog_prof_Profile *slot_one_profile;

  pthread_mutex_t slot_two_mutex;
  ddog_prof_Profile *slot_two_profile;

  short active_slot; // MUST NEVER BE ACCESSED FROM record_sample; this is NOT for the sampler thread to use.

  uint8_t position_for[ALL_VALUE_TYPES_COUNT];
  uint8_t enabled_values_count;
};

// Used to return a pair of values from sampler_lock_active_profile()
struct active_slot_pair {
  pthread_mutex_t *mutex;
  ddog_prof_Profile *profile;
};

struct call_serialize_without_gvl_arguments {
  // Set by caller
  struct stack_recorder_state *state;
  ddog_Timespec finish_timestamp;

  // Set by callee
  ddog_prof_Profile *profile;
  ddog_prof_Profile_SerializeResult result;

  // Set by both
  bool serialize_ran;
};

static VALUE _native_new(VALUE klass);
static void initialize_slot_concurrency_control(struct stack_recorder_state *state);
static void stack_recorder_typed_data_free(void *data);
static VALUE _native_initialize(DDTRACE_UNUSED VALUE _self, VALUE recorder_instance, VALUE cpu_time_enabled, VALUE alloc_samples_enabled);
static VALUE _native_serialize(VALUE self, VALUE recorder_instance);
static VALUE ruby_time_from(ddog_Timespec ddprof_time);
static void *call_serialize_without_gvl(void *call_args);
static struct active_slot_pair sampler_lock_active_profile();
static void sampler_unlock_active_profile(struct active_slot_pair active_slot);
static ddog_prof_Profile *serializer_flip_active_and_inactive_slots(struct stack_recorder_state *state);
static VALUE _native_active_slot(DDTRACE_UNUSED VALUE _self, VALUE recorder_instance);
static VALUE _native_is_slot_one_mutex_locked(DDTRACE_UNUSED VALUE _self, VALUE recorder_instance);
static VALUE _native_is_slot_two_mutex_locked(DDTRACE_UNUSED VALUE _self, VALUE recorder_instance);
static VALUE test_slot_mutex_state(VALUE recorder_instance, int slot);
static ddog_Timespec time_now(void);
static VALUE _native_reset_after_fork(DDTRACE_UNUSED VALUE self, VALUE recorder_instance);
static void serializer_set_start_timestamp_for_next_profile(struct stack_recorder_state *state, ddog_Timespec timestamp);
static VALUE _native_record_endpoint(DDTRACE_UNUSED VALUE _self, VALUE recorder_instance, VALUE local_root_span_id, VALUE endpoint);

void stack_recorder_init(VALUE profiling_module) {
  stack_recorder_class = rb_define_class_under(profiling_module, "StackRecorder", rb_cObject);
  // Hosts methods used for testing the native code using RSpec
  VALUE testing_module = rb_define_module_under(stack_recorder_class, "Testing");

  // Instances of the StackRecorder class are "TypedData" objects.
  // "TypedData" objects are special objects in the Ruby VM that can wrap C structs.
  // In this case, it wraps the stack_recorder_state.
  //
  // Because Ruby doesn't know how to initialize native-leve