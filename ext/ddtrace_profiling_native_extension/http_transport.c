#include <ruby.h>
#include <ruby/thread.h>
#include <datadog/profiling.h>
#include "helpers.h"
#include "libdatadog_helpers.h"
#include "ruby_helpers.h"

// Used to report profiling data to Datadog.
// This file implements the native bits of the Datadog::Profiling::HttpTransport class

static VALUE ok_symbol = Qnil; // :ok in Ruby
static VALUE error_symbol = Qnil; // :error in Ruby

static ID agentless_id; // id of :agentless in Ruby
static ID agent_id; // id of :agent in Ruby

static ID log_failure_to_process_tag_id; // id of :log_failure_to_process_tag in Ruby

static VALUE http_transport_class = Qnil;
static VALUE library_version_string = Qnil;

struct call_exporter_without_gvl_arguments {
  ddog_prof_Exporter *exporter;
  ddog_prof_Exporter_Request_BuildResult *build_result;
  ddog_CancellationToken *cancel_token;
  ddog_prof_Exporter_SendResult result;
  bool send_ran;
};

inline static ddog_ByteSlice byte_slice_from_ruby_string(VALUE string);
static VALUE _native_validate_exporter(VALUE self, VALUE exporter_configuration);
static ddog_prof_Exporter_NewResult create_exporter(VALUE exporter_configuration, VALUE tags_as_array);
static VALUE handle_exporter_failure(ddog_prof_Exporter_NewResult exporter_result);
static ddog_Endpoint endpoint_from(VALUE exporter_configuration);
static ddog_Vec_Tag convert_tags(VALUE tags_as_array);
static void safely_log_failure_to_process_tag(ddog_Vec_Tag tags, VALUE err_details);
static VALUE _native_do_export(
  VALUE self,
  VALUE exporter_configuration,
  VALUE upload_timeout_milliseconds,
  VALUE start_timespec_seconds,
  VALUE start_timespec_nanoseconds,
  VALUE finish_timespec_seconds,
  VALUE finish_timespec_nanoseconds,
  VALUE pprof_file_name,
  VALUE pprof_data,
  VALUE code_provenance_file_name,
  VALUE code_provenance_data,
  VALUE tags_as_array
);
static void *call_exporter_without_gvl(void *call_args);
static void interrupt_exporter_call(void *cancel_token);
static VALUE ddtrace_version(void);

void http_transport_init(VALUE profiling_module) {
  http_transport_class = rb_define_class_under(profiling_module, "HttpTransport", rb_cObject);

  rb_define_singleton_method(http_transport_class, "_native_validate_exporter",  _native_validate_exporter, 1);
  rb_define_singleton_method(http_transport_class, "_native_do_export",  _native_do_export, 11);

  ok_symbol = ID2SYM(rb_intern_const("ok"));
  error_symbol = ID2SYM(rb_intern_const("error"));
  agentless_id = rb_intern_const("agentless");
  agent_id = rb_intern_const("agent");
  log_failure_to_process_tag_id = rb_intern_const("log_failure_to_process_tag");

  library_version_string = ddtrace_version();
  rb_global_variable(&library_version_string);
}

inline static ddog_ByteSlice byte_slice_from_ruby_string(VALUE string) {
  ENFORCE_TYPE(string, T_STRING);
  ddog_ByteSlice byte_slice = {.ptr = (uint8_t *) StringValuePtr(string), .len = RSTRING_LEN(string)};
  return byte_slice;
}

static VALUE _native_validate_exporter(DDTRACE_UNUSED VALUE _self, VALUE exporter_configuration) {
  ENFORCE_TYPE(exporter_configuration, T_ARRAY);
  ddog_prof_Exporter_NewResult exporter_result = create_exporter(exporter_configuration, rb_ary_new());

  VALUE failure_tuple = handle_exporter_failure(exporter_result);
  if (!NIL_P(failure_tuple)) return failure_tuple;

  // We don't actually need the exporter for now -- we just wanted to validate that we could create it with the
  // settings we were given
  ddog_prof_Exporter_drop(exporter_result.ok);

  return rb_ary_new_from_args(2, ok_symbol, Qnil);
}

static ddog_prof_Exporter_NewResult create_exporter(VALUE exporter_configuration, VALUE tags_as_array) {
  ENFORCE_TYPE(exporter_configuration, T_ARRAY);
  ENFORCE_TYPE(tags_as_array, T_ARRAY);

  // This needs to be called BEFORE convert_tags since it can raise an exception and thus cause the ddog_Vec_Tag
  // to be leaked.
  ddog_Endpoint endpoint = endpoint_from(exporter_configuration);

  ddog_Vec_Tag tags = convert_tags(tags_as_array);

  ddog_CharSlice library_name = DDOG_CHARSLICE_C("dd-trace-rb");
  ddog_CharSlice library_version = char_slice_from_ruby_string(library_version_string);
  ddog_CharSlice profiling_family = DDOG_CHARSLICE_C("ruby");

  ddog_prof_Exporter_NewResult exporter_result =
    ddog_prof_Exporter_new(library_name, library_version, profiling_family, &tags, endpoint);

  ddog_Vec_Tag_drop(tags);

  return exporter_result;
}

static VALUE handle_exporter_failure(ddog_prof_Exporter_NewResult exporter_result) {
  return exporter_result.tag == DDOG_PROF_EXPORTER_NEW_RESULT_OK ?
    Qnil :
    rb_ary_new_from_args(2, error_symbol, get_error_details_and_drop(&exporter_result.err));
}

static ddog_Endpoint endpoint_from(VALUE exporter_configuration) {
  ENFORCE_TYPE(exporter_configuration, T_ARRAY);

  ID working_mode = SYM2ID(rb_ary_entry(exporter_configuration, 0)); // SYM2ID verifies its input so we can do this safely

  if (working_mode != agentless_id && working_mode != agent_id) {
    rb_raise(rb_eArgError, "Failed to initialize transport: Unexpected working mode, expected :agentless or :agent");
  }

  if (working_mode == agentless_id) {
    VALUE site = rb_ary_entry(exporter_configuration, 1);
    VALUE api_key = rb_ary_entry(exporter_configuration, 2);
    ENFORCE_TYPE(site, T_STRING);
    ENFORCE_TYPE(api_key, T_STRING);

    return ddog_Endpoint_agentless(char_slice_from_ruby_string(site), char_slice_from_ruby_string(api_key));
  } else { // agent_id
    VALUE base_url = rb_ary_entry(exporter_configuration, 1);
    ENFORCE_TYPE(base_url, T_STRING);

    return ddog_Endpoint_agent(char_slice_from_ruby_string(base_url));
  }
}

__attribute__((warn_unused_result))
static ddog_Vec_Tag convert_tags(VALUE tags_as_array) {
  ENFORCE_TYPE(tags_as_array, T_ARRAY);

  long tags_count = RARRAY_LEN(tags_as_array);
  ddog_Vec_Tag tags = ddog_Vec_Tag_new();

  for (long i = 0; i < tags_count; i++) {
    VALUE name_value_pair = rb_ary_entry(tags_as_array, i);

    if (!RB_TYPE_P(name_value_pair, T_ARRAY)) {
      ddog_Vec_Tag_drop(tags);
      ENFORCE_TYPE(name_value_pair, T_ARRAY);
    }

    // Note: We can index the array without checking its size first because rb_ary_entry returns Qnil if out of bounds
    VALUE tag_name = rb_ary_entry(name_value_pair, 0);
    VALUE tag_value = rb_ary_entry(name_value_pair, 1);

    if (!(RB_TYPE_P(tag_name, T_STRING) && RB_TYPE_P(tag_value, T_STRING))) {
      ddog_Vec_Tag_drop(tags);
      ENFORCE_TYPE(tag_name, T_STRING);
      ENFORCE_TYPE(tag_value, T_STRING);
    }

    ddog_Vec_Tag_PushResult push_result =
      ddog_Vec_Tag_push(&tags, char_slice_from_ruby_string(tag_name), char_slice_from_ruby_string(tag_value));

    if (push_result.tag == DDOG_VEC_TAG_PUSH_RESULT_ERR) {
      // libdatadog validates tags and may catch invalid tags that ddtrace didn't actually catch.
      // We warn users about such tags, and then just ignore them.
      safely_log_failure_to_process_tag(tags, get_error_details_and_drop(&push_result.err));
    }
  }

  return tags;
}

static VALUE log_failure_to_process_tag(VALUE err_details) {
  return rb_funcall(http_t