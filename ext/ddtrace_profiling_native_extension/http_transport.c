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

inline static ddog_ByteSli