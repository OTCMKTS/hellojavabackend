#include <ruby.h>
#include <ruby/debug.h>
#include "extconf.h"
#include "helpers.h"
#include "libdatadog_helpers.h"
#include "ruby_helpers.h"
#include "private_vm_api_access.h"
#include "stack_recorder.h"
#include "collectors_stack.h"

// Gathers stack traces from running threads, storing them in a StackRecorder instance
// This file implements the native bits of the Datadog::Profiling::Collectors::Stack class

#define MAX_FRAMES_LIMIT            10000
#define MAX_FRAMES_LIMIT_AS_STRING "10000"

static VALUE missing_string = Qnil;

// Used as scratch space during sampling
struct sampling_buffer {
  unsigned int max_frames;
  VALUE *stack_buffer;
  int *lines_buffer;
  bool *is_ruby_frame;
  ddog_prof_Location *locations;
  ddog_prof_Line *lines;
}; // Note: typedef'd in the header to sampling_buffer

static VALUE _native_sample(
  VALUE self,
  VALUE thread,
  VALUE recorder_instance,
  VALUE metric_values_hash,
  VALUE labels_array,
  VALUE numeric_labels_array,
  VALUE max_frames,
  VALUE in_gc
);
static void maybe_add_placeholder_frames_omitted(VALUE thread, sampling_buffer* buffer, char *frames_omitted_message, int frames_omitted_message_size);
static void record_placeholder_stack_in_native_code(
  sampling_buffer* buffer,
  VALUE recorder_instance,
  sample_values values,
  ddog_prof_Slice_Label labels,
  sampling_buffer *record_buffer,
  int extra_frames_in_record_buffer
);
static void sample_thread_internal(
  VALUE thread,
  sampling_buffer* buffer,
  VALUE recorder_instance,
  sample_values values,
  ddog_prof_Slice_Label labels,
  sampling_buffer *record_buffer,
  int extra_frames_in_record_buffer
);

void collectors_stack_init(VALUE profiling_module) {
  VALUE collectors_module = rb_define_module_under(profiling_module, "Collectors");
  VALUE collectors_stack_class = rb_define_class_under(collectors_module, "Stack", rb_cObject);
  // Hosts methods used for testing the native code using RSpec
  VALUE testing_module = rb_define_module_under(collectors_stack_class, "Testing");

  rb_define_singleton_method(testing_module, "_native_sample", _native_sample, 7);

  missing_string = rb_str_new2("");
  rb_global_variable(&missing_string);
}

// This method exists only to enable testing Datadog::Profiling::Collectors::Stack behavior using RSpec.
// It SHOULD NOT be used for other purposes.
static VALUE _native_sample(
  DDTRACE_UNUSED VALUE _self,
  VALUE thread,
  VALUE recorder_instance,
  VALUE metric_values_hash,
  VALUE labels_array,
  VALUE numeric_labels_array,
  VALUE max_frames,
  VALUE in_gc
) {
  ENFORCE_TYPE(metric_values_hash, T_HASH);
  ENFORCE_TYPE(labels_array, T_ARRAY);
  ENFORCE_TYPE(numeric_labels_array, T_ARRAY);

  VALUE zero = INT2NUM(0);
  sample_values values = {
    .cpu_time_ns   = NUM2UINT(rb_hash_lookup2(metric_values_hash, rb_str_new_cstr("cpu-time"),      zero)),
    .cpu_samples   = NUM2UINT(rb_hash_lookup2(metric_values_hash, rb_str_new_cstr("cpu-samples"),   zero)),
    .wall_time_ns  = NUM2UINT(rb_hash_lookup2(metric_values_hash, rb_str_new_cstr("wall-time"),     zero)),
    .alloc_sam