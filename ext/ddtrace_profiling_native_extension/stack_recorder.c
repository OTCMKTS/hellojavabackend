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
// ../../../../ext/ddtrace_profiling_native_extens