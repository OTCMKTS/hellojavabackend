
#include "extconf.h"

// This file exports functions used to access private Ruby VM APIs and internals.
// To do this, it imports a few VM internal (private) headers.
//
// **Important Note**: Our medium/long-term plan is to stop relying on all private Ruby headers, and instead request and
// contribute upstream changes so that they become official public VM APIs.
//
// In the meanwhile, be very careful when changing things here :)

#ifdef RUBY_MJIT_HEADER
  // Pick up internal structures from the private Ruby MJIT header file
  #include RUBY_MJIT_HEADER
#else
  // On older Rubies, use a copy of the VM internal headers shipped in the debase-ruby_core_source gem

  // We can't do anything about warnings in VM headers, so we just use this technique to suppress them.
  // See https://nelkinda.com/blog/suppress-warnings-in-gcc-and-clang/#d11e364 for details.
  #pragma GCC diagnostic push
  #pragma GCC diagnostic ignored "-Wunused-parameter"
  #pragma GCC diagnostic ignored "-Wattributes"
    #include <vm_core.h>
  #pragma GCC diagnostic pop
  #include <iseq.h>
#endif

#define PRIVATE_VM_API_ACCESS_SKIP_RUBY_INCLUDES
#include "private_vm_api_access.h"

// MRI has a similar rb_thread_ptr() function which we can't call it directly
// because Ruby does not expose the thread_data_type publicly.
// Instead, we have our own version of that function, and we lazily initialize the thread_data_type pointer
// from a known-correct object: the current thread.
//
// Note that beyond returning the rb_thread_struct*, rb_check_typeddata() raises an exception
// if the argument passed in is not actually a `Thread` instance.
static inline rb_thread_t *thread_struct_from_object(VALUE thread) {
  static const rb_data_type_t *thread_data_type = NULL;
  if (UNLIKELY(thread_data_type == NULL)) thread_data_type = RTYPEDDATA_TYPE(rb_thread_current());

  return (rb_thread_t *) rb_check_typeddata(thread, thread_data_type);
}

rb_nativethread_id_t pthread_id_for(VALUE thread) {
  // struct rb_native_thread was introduced in Ruby 3.2 (preview2): https://github.com/ruby/ruby/pull/5836
  #ifndef NO_RB_NATIVE_THREAD
    return thread_struct_from_object(thread)->nt->thread_id;
  #else
    return thread_struct_from_object(thread)->thread_id;
  #endif
}

// Queries if the current thread is the owner of the global VM lock.
//
// @ivoanjo: Ruby has a similarly-named `ruby_thread_has_gvl_p` but that API is insufficient for our needs because it can
// still return `true` even when a thread DOES NOT HAVE the global VM lock.
// In particular, looking at the implementation, that API assumes that if a thread is not in a "blocking region" then it
// will have the GVL which is probably true for the situations that API was designed to be called from BUT this assumption
// does not hold true when calling `ruby_thread_has_gvl_p` from a signal handler. (Because the thread may have lost the
// GVL due to a scheduler decision, not because it decided to block.)
// I have also submitted https://bugs.ruby-lang.org/issues/19172 to discuss this with upstream Ruby developers.
//
// Thus we need our own gvl-checking method which actually looks at the gvl structure to determine if it is the owner.
bool is_current_thread_holding_the_gvl(void) {
  current_gvl_owner owner = gvl_owner();
  return owner.valid && pthread_equal(pthread_self(), owner.owner);
}

#ifndef NO_GVL_OWNER // Ruby < 2.6 doesn't have the owner/running field
  // NOTE: Reading the owner in this is a racy read, because we're not grabbing the lock that Ruby uses to protect it.
  //
  // While we could potentially grab this lock, I (@ivoanjo) think we actually don't need it because:
  // * In the case where a thread owns the GVL and calls `gvl_owner`, it will always see the correct value. That's
  //   because every thread sets itself as the owner when it grabs the GVL and unsets itself at the end.
  //   That means that `is_current_thread_holding_the_gvl` is always accurate.
  // * In a case where we observe a different thread, then this may change by the time we do something with this value
  //   anyway. So unless we want to prevent the Ruby scheduler from switching threads, we need to deal with races here.
  current_gvl_owner gvl_owner(void) {
    const rb_thread_t *current_owner =
      #ifndef NO_RB_THREAD_SCHED // Introduced in Ruby 3.2 as a replacement for struct rb_global_vm_lock_struct
        GET_RACTOR()->threads.sched.running;
      #elif HAVE_RUBY_RACTOR_H
        GET_RACTOR()->threads.gvl.owner;
      #else
        GET_VM()->gvl.owner;
      #endif

    if (current_owner == NULL) return (current_gvl_owner) {.valid = false};

    return (current_gvl_owner) {
      .valid = true,
      .owner =
        #ifndef NO_RB_NATIVE_THREAD
          current_owner->nt->thread_id
        #else
          current_owner->thread_id
        #endif
    };
  }
#else
  current_gvl_owner gvl_owner(void) {
    rb_vm_t *vm =
      #ifndef NO_GET_VM
        GET_VM();
      #else
        thread_struct_from_object(rb_thread_current())->vm;
      #endif

    // BIG Issue: Ruby < 2.6 did not have the owner field. The really nice thing about the owner field is that it's
    // "atomic" -- when a thread sets it, it "declares" two things in a single step
    // * Declaration 1: Someone has the GVL
    // * Declaration 2: That someone is the specific thread
    //
    // Observation 1: On older versions of Ruby, this ownership concept is actually split. Specifically, `gvl.acquired`
    // is a boolean that represents declaration 1 above, and `vm->running_thread` (or `ruby_current_thread`/
    // `ruby_current_execution_context_ptr`) represents declaration 2.
    //
    // Observation 2: In addition, when a thread releases the GVL, it only sets `gvl.acquired` back to 0 **BUT CRUCIALLY
    // DOES NOT CHANGE THE OTHER global variables**.
    //
    // Observation 1+2 above lead to the following possible race:
    // * Thread A grabs the GVL (`gvl.acquired == 1`)
    // * Thread A sets `running_thread` (`gvl.acquired == 1` + `running_thread == Thread A`)
    // * Thread A releases the GVL (`gvl.acquired == 0` + `running_thread == Thread A`)
    // * Thread B grabs the GVL (`gvl.acquired == 1` + `running_thread == Thread A`)
    // * Thread A calls gvl_owner. Due to the current state (`gvl.acquired == 1` + `running_thread == Thread A`), this
    //   function returns an incorrect result.
    // * Thread B finally sets `running_thread` (`gvl.acquired == 1` + `running_thread == Thread B`)
    //
    // This is especially problematic because we use `gvl_owner` to implement `is_current_thread_holding_the_gvl` which
    // is called in a signal handler to decide "is it safe for me to call `rb_postponed_job_register_one` or not".
    // (See constraints in `collectors_cpu_and_wall_time_worker.c` comments for why).
    //
    // Thus an incorrect `is_current_thread_holding_the_gvl` result may lead to issues inside `rb_postponed_job_register_one`.
    //
    // For this reason we currently do not enable the new Ruby profiler on Ruby 2.5 and below by default, and we print a
    // warning when customers force-enable it.
    bool gvl_acquired = vm->gvl.acquired != 0;
    rb_thread_t *current_owner = vm->running_thread;

    if (!gvl_acquired || current_owner == NULL) return (current_gvl_owner) {.valid = false};

    return (current_gvl_owner) {.valid = true, .owner = current_owner->thread_id};
  }
#endif // NO_GVL_OWNER

// Taken from upstream vm_core.h at commit d9cf0388599a3234b9f3c06ddd006cd59a58ab8b (November 2022, Ruby 3.2 trunk)
// Copyright (C) 2004-2007 Koichi Sasada
// to support tid_for (see below)
// Modifications: None
#if defined(__linux__) || defined(__FreeBSD__)
# define RB_THREAD_T_HAS_NATIVE_ID
#endif

uint64_t native_thread_id_for(VALUE thread) {
  // The tid is only available on Ruby >= 3.1 + Linux (and FreeBSD). It's the same as `gettid()` aka the task id as seen in /proc
  #if !defined(NO_THREAD_TID) && defined(RB_THREAD_T_HAS_NATIVE_ID)
    #ifndef NO_RB_NATIVE_THREAD
      return thread_struct_from_object(thread)->nt->tid;
    #else
      return thread_struct_from_object(thread)->tid;
    #endif
  #else
    rb_nativethread_id_t pthread_id = pthread_id_for(thread);

    #ifdef __APPLE__
      uint64_t result;
      // On macOS, this gives us the same identifier that shows up in activity monitor
      int error = pthread_threadid_np(pthread_id, &result);
      if (error) rb_syserr_fail(error, "Unexpected failure in pthread_threadid_np");
      return result;
    #else
      // Fallback, when we have nothing better (e.g. on Ruby < 3.1 on Linux)
      // @ivoanjo: In the future we may want to explore some potential hacks to get the actual tid on linux
      // (e.g. https://stackoverflow.com/questions/558469/how-do-i-get-a-thread-id-from-an-arbitrary-pthread-t )
      return (uint64_t) pthread_id;
    #endif
  #endif
}

// Returns the stack depth by using the same approach as rb_profile_frames and backtrace_each: get the positions
// of the end and current frame pointers and subtracting them.
ptrdiff_t stack_depth_for(VALUE thread) {
  #ifndef USE_THREAD_INSTEAD_OF_EXECUTION_CONTEXT // Modern Rubies
    const rb_execution_context_t *ec = thread_struct_from_object(thread)->ec;
  #else // Ruby < 2.5
    const rb_thread_t *ec = thread_struct_from_object(thread);
  #endif

  const rb_control_frame_t *cfp = ec->cfp, *end_cfp = RUBY_VM_END_CONTROL_FRAME(ec);

  if (end_cfp == NULL) return 0;

  // Skip dummy frame, as seen in `backtrace_each` (`vm_backtrace.c`) and our custom rb_profile_frames
  // ( https://github.com/ruby/ruby/blob/4bd38e8120f2fdfdd47a34211720e048502377f1/vm_backtrace.c#L890-L914 )
  end_cfp = RUBY_VM_NEXT_CONTROL_FRAME(end_cfp);

  return end_cfp <= cfp ? 0 : end_cfp - cfp - 1;
}

// This was renamed in Ruby 3.2
#if !defined(ccan_list_for_each) && defined(list_for_each)
  #define ccan_list_for_each list_for_each
#endif

// Tries to match rb_thread_list() but that method isn't accessible to extensions
void ddtrace_thread_list(VALUE result_array) {
  rb_thread_t *thread = NULL;

  // Ruby 3 Safety: Our implementation is inspired by `rb_ractor_thread_list` BUT that method wraps the operations below
  // with `RACTOR_LOCK` and `RACTOR_UNLOCK`.
  //
  // This initially made me believe that one MUST grab the ractor lock (which is different from the ractor-scoped Global
  // VM Lock) in able to iterate the `threads.set`. This turned out not to be the case: upon further study of the VM
  // codebase in 3.2-master, 3.1 and 3.0, there's quite a few places where `threads.set` is accessed without grabbing
  // the ractor lock: `ractor_mark` (ractor.c), `thgroup_list` (thread.c), `rb_check_deadlock` (thread.c), etc.
  //
  // I suspect the design in `rb_ractor_thread_list` may be done that way to perhaps in the future expose it to be
  // called from a different Ractor, but I'm not sure...
  #ifdef HAVE_RUBY_RACTOR_H
    rb_ractor_t *current_ractor = GET_RACTOR();
    ccan_list_for_each(&current_ractor->threads.set, thread, lt_node) {
  #else
    rb_vm_t *vm =
      #ifndef NO_GET_VM
        GET_VM();
      #else
        thread_struct_from_object(rb_thread_current())->vm;
      #endif
    list_for_each(&vm->living_threads, thread, vmlt_node) {
  #endif
      switch (thread->status) {
        case THREAD_RUNNABLE:
        case THREAD_STOPPED:
        case THREAD_STOPPED_FOREVER:
          rb_ary_push(result_array, thread->self);
        default:
          break;
      }
    }
}

bool is_thread_alive(VALUE thread) {
  return thread_struct_from_object(thread)->status != THREAD_KILLED;
}

VALUE thread_name_for(VALUE thread) {
  return thread_struct_from_object(thread)->name;
}

// -----------------------------------------------------------------------------
// The sources below are modified versions of code extracted from the Ruby project.
// Each function is annotated with its origin, why we imported it, and the changes made.
//
// The Ruby project copyright and license follow:
// -----------------------------------------------------------------------------
// Copyright (C) 1993-2013 Yukihiro Matsumoto. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.

// Taken from upstream vm_core.h at commit 5f10bd634fb6ae8f74a4ea730176233b0ca96954 (March 2022, Ruby 3.2 trunk)
// Copyright (C) 2004-2007 Koichi Sasada
// to support our custom rb_profile_frames (see below)
// Modifications: None
#define ISEQ_BODY(iseq) ((iseq)->body)

// Taken from upstream vm_backtrace.c at commit 5f10bd634fb6ae8f74a4ea730176233b0ca96954 (March 2022, Ruby 3.2 trunk)
// Copyright (C) 1993-2012 Yukihiro Matsumoto
// to support our custom rb_profile_frames (see below)
// Modifications: None
//
// `node_id` gets used depending on Ruby VM compilation settings (USE_ISEQ_NODE_ID being defined).
// To avoid getting false "unused argument" warnings in setups where it's not used, we need to do this weird dance
// with diagnostic stuff. See https://nelkinda.com/blog/suppress-warnings-in-gcc-and-clang/#d11e364 for details.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
inline static int
calc_pos(const rb_iseq_t *iseq, const VALUE *pc, int *lineno, int *node_id)
{
    VM_ASSERT(iseq);
    VM_ASSERT(ISEQ_BODY(iseq));
    VM_ASSERT(ISEQ_BODY(iseq)->iseq_encoded);
    VM_ASSERT(ISEQ_BODY(iseq)->iseq_size);
    if (! pc) {
        if (ISEQ_BODY(iseq)->type == ISEQ_TYPE_TOP) {
            VM_ASSERT(! ISEQ_BODY(iseq)->local_table);
            VM_ASSERT(! ISEQ_BODY(iseq)->local_table_size);
            return 0;
        }
        if (lineno) *lineno = FIX2INT(ISEQ_BODY(iseq)->location.first_lineno);
#ifdef USE_ISEQ_NODE_ID
        if (node_id) *node_id = -1;
#endif
        return 1;
    }
    else {
        ptrdiff_t n = pc - ISEQ_BODY(iseq)->iseq_encoded;
        VM_ASSERT(n <= ISEQ_BODY(iseq)->iseq_size);
        VM_ASSERT(n >= 0);
        ASSUME(n >= 0);
        size_t pos = n; /* no overflow */
        if (LIKELY(pos)) {
            /* use pos-1 because PC points next instruction at the beginning of instruction */
            pos--;
        }
#if VMDEBUG && defined(HAVE_BUILTIN___BUILTIN_TRAP)
        else {
            /* SDR() is not possible; that causes infinite loop. */
            rb_print_backtrace();
            __builtin_trap();
        }
#endif
        if (lineno) *lineno = rb_iseq_line_no(iseq, pos);
#ifdef USE_ISEQ_NODE_ID
        if (node_id) *node_id = rb_iseq_node_id(iseq, pos);
#endif
        return 1;
    }
}
#pragma GCC diagnostic pop

// Taken from upstream vm_backtrace.c at commit 5f10bd634fb6ae8f74a4ea730176233b0ca96954 (March 2022, Ruby 3.2 trunk)
// Copyright (C) 1993-2012 Yukihiro Matsumoto
// to support our custom rb_profile_frames (see below)
// Modifications: None
inline static int
calc_lineno(const rb_iseq_t *iseq, const VALUE *pc)
{
    int lineno;
    if (calc_pos(iseq, pc, &lineno, NULL)) return lineno;
    return 0;
}

// Taken from upstream vm_backtrace.c at commit 5f10bd634fb6ae8f74a4ea730176233b0ca96954 (March 2022, Ruby 3.2 trunk)
// Copyright (C) 1993-2012 Yukihiro Matsumoto
// Modifications:
// * Renamed rb_profile_frames => ddtrace_rb_profile_frames
// * Add thread argument
// * Add is_ruby_frame argument
// * Removed `if (lines)` tests -- require/assume that like `buff`, `lines` is always specified
// * Support Ruby < 2.5 by using rb_thread_t instead of rb_execution_context_t (which did not exist and was just
//   part of rb_thread_t)
// * Support Ruby < 2.4 by using `RUBY_VM_NORMAL_ISEQ_P(cfp->iseq)` instead of `VM_FRAME_RUBYFRAME_P(cfp)`.
//   Given that the Ruby 2.3 version of `rb_profile_frames` did not support native methods and thus did not need this
//   check, how did I figure out what to replace it with? I did it by looking at other places in the VM code where the
//   code looks exactly the same but Ruby 2.4 uses `VM_FRAME_RUBYFRAME_P` whereas Ruby 2.3 used `RUBY_VM_NORMAL_ISEQ_P`.
//   Examples of these are `errinfo_place` in `eval.c`, `rb_vm_get_ruby_level_next_cfp` (among others) in `vm.c`, etc.
// * Skip dummy frame that shows up in main thread
// * Add `end_cfp == NULL` and `end_cfp <= cfp` safety checks. These are used in a bunch of places in
//   `vm_backtrace.c` (`backtrace_each`, `backtrace_size`, `rb_ec_partial_backtrace_object`) but are conspicuously
//   absent from `rb_profile_frames`. Oversight?
// * Skip frames where `cfp->iseq && !cfp->pc`. These seem to be internal and are skipped by `backtrace_each` in
//   `vm_backtrace.c`.
// * Check thread status and do not sample if thread has been killed.
// * Match Ruby reference stack trace APIs that use the iseq instead of the callable method entry to get information
//   for iseqs created from calls to `eval` and `instance_eval`. This makes it so that `rb_profile_frame_path` on
//   the `VALUE` returned by rb_profile_frames returns `(eval)` instead of the path of the file where the `eval`
//   was called from.
// * Imported fix from https://github.com/ruby/ruby/pull/7116 to avoid sampling threads that are still being created
//
// What is rb_profile_frames?
// `rb_profile_frames` is a Ruby VM debug API added for use by profilers for sampling the stack trace of a Ruby thread.
// Its main other user is the stackprof profiler: https://github.com/tmm1/stackprof .
//
// Why do we need a custom version of rb_profile_frames?
//
// There are a few reasons:
// 1. To backport improved behavior to older Rubies. Prior to Ruby 3.0 (https://github.com/ruby/ruby/pull/3299),
//    rb_profile_frames skipped CFUNC frames, aka frames that are implemented with native code, and thus the resulting
//    stacks were quite incomplete as a big part of the Ruby standard library is implemented with native code.
//
// 2. To extend this function to work with any thread. The upstream rb_profile_frames function only targets the current
//    thread, and to support wall-clock profiling we require sampling other threads. This is only safe because of the
//    Global VM Lock. (We don't yet support sampling Ractors beyond the main one; we'll need to find a way to do it
//    safely first.)
//
// 3. To get more information out of the Ruby VM. The Ruby VM has a lot more information than is exposed through
//    rb_profile_frames, and by making our own copy of this function we can extract more of this information.
//    See for backtracie gem (https://github.com/ivoanjo/backtracie) for an exploration of what can potentially be done.
//
// 4. Because we haven't yet submitted patches to upstream Ruby. As with any changes on the `private_vm_api_access.c`,
//    our medium/long-term plan is to contribute upstream changes and make it so that we don't need any of this
//    on modern Rubies.
//
// 5. To make rb_profile_frames behave more like the Ruby-level reference stack trace APIs (`Thread#backtrace_locations`
//    and friends). We've found quite a few situations where the data from rb_profile_frames and the reference APIs
//    disagree, and quite a few of them seem oversights/bugs (speculation from my part) rather than deliberate
//    decisions.
int ddtrace_rb_profile_frames(VALUE thread, int start, int limit, VALUE *buff, int *lines, bool* is_ruby_frame)
{
    int i;
    // Modified from upstream: Instead of using `GET_EC` to collect info from the current thread,
    // support sampling any thread (including the current) passed as an argument
    rb_thread_t *th = thread_struct_from_object(thread);
#ifndef USE_THREAD_INSTEAD_OF_EXECUTION_CONTEXT // Modern Rubies
    const rb_execution_context_t *ec = th->ec;
#else // Ruby < 2.5
    const rb_thread_t *ec = th;
#endif
    const rb_control_frame_t *cfp = ec->cfp, *end_cfp = RUBY_VM_END_CONTROL_FRAME(ec);