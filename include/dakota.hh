// -*- mode: C++; c-basic-offset: 2; tab-width: 2; indent-tabs-mode: nil -*-

// Copyright (C) 2007, 2008, 2009 Robert Nielsen <robert@dakota.org>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

# if !defined dkt_dakota_hh
# define      dkt_dakota_hh

# include <cstddef>
# include <cstdlib>
# include <cstdio>
# include <cstdarg> // va-list
# include <cstdint>
# include <cstring> // memcpy()
# include <new> // std::bad-alloc

# include <syslog.h>
# include <cxxabi.h>

# define cast(t) (t)
# define ssizeof(t) (cast(ssize_t)sizeof(t))

# define DKT_MEM_MGMT_MALLOC 0
# define DKT_MEM_MGMT_NEW    1
# define DKT_MEM_MGMT        DKT_MEM_MGMT_MALLOC

namespace dkt {
# if defined __GNUG__
  inline FUNC demangle(str_t mangled_name) -> str_t {
    int status = -1;
    str_t name = abi::__cxa_demangle(mangled_name, 0, 0, &status); // must be free()d
    if (0 == status)
      return name;
    else
      return nullptr;
  }
# else // does nothing if not gcc/clang (g++/clang++)
  inline FUNC demangle(str_t mangled_name) -> str_t {
    return name;
  }
# endif

  inline FUNC dealloc(void* ptr) -> void {
# if (DKT_MEM_MGMT == DKT_MEM_MGMT_NEW)
    operator delete(ptr);
# elif (DKT_MEM_MGMT == DKT_MEM_MGMT_MALLOC)
    free(ptr);
# else
    # error DK_MEM_MGMT
# endif
  }
  inline FUNC alloc(ssize_t size) -> void* {
    void* buf;
# if (DKT_MEM_MGMT == DKT_MEM_MGMT_NEW)
    buf = operator new(size);
# elif (DKT_MEM_MGMT == DKT_MEM_MGMT_MALLOC)
    buf = malloc(cast(size_t)size);

    if (nullptr == buf)
      throw std::bad_alloc();
# else
    # error DK_MEM_MGMT
# endif
    return buf;
  }
  inline FUNC alloc(ssize_t size, void* ptr) -> void* {
    void* buf;
# if (DKT_MEM_MGMT == DKT_MEM_MGMT_NEW)
    buf = dkt::alloc(size);
    memcpy(buf, ptr, size);
    dkt::dealloc(ptr);
# elif (DKT_MEM_MGMT == DKT_MEM_MGMT_MALLOC)
    buf = realloc(ptr, cast(size_t)size);

    if (nullptr == buf)
      throw std::bad_alloc();
# else
    # error DK_MEM_MGMT
# endif
    return buf;
  }
}
# if defined DEBUG
  # define DEBUG_STMT(stmt) stmt
  # define INTERNED_DEMANGLED_TYPEID_NAME(t) dk_intern_free(dkt::demangle(typeid(t).name()))
# else
  # define DEBUG_STMT(stmt)
  # define INTERNED_DEMANGLED_TYPEID_NAME(t) nullptr
# endif

// gcc has bug in code generation so the assembler omit the quotes
# if defined __clang__
  # define read_only  gnu::section("__DKT_READ_ONLY, __dkt_read_only")
# elif defined __GNUG__
  # define read_only  gnu::section("\"__DKT_READ_ONLY, __dkt_read_only\"")
# else
  # error "Neither __clang__ nor __GNUG__ is defined."
#endif

# define format_va_printf(n) gnu::format(__printf__, n, 0)
# define format_va_scanf(n)  gnu::format(__scanf__,  n, 0)
# define format_printf(n)    gnu::format(__printf__, n, n + 1)
# define format_scanf(n)     gnu::format(__scanf__,  n, n + 1)
# define sentinel            gnu::sentinel
# define unused              gnu::unused

# define THREAD_LOCAL __thread // bummer that clang does not support thread-local on darwin

# define unbox_attrs gnu::pure,gnu::hot,gnu::nothrow

# if defined DEBUG
  # define debug_export export
  # define debug_import import
# else
  # define debug_export
  # define debug_import
# endif

# define countof(array) (sizeof((array))/sizeof((array)[0]))
# define scountof(array) cast(ssize_t)countof(array)

namespace va {
  [[format_va_printf(1)]] static inline FUNC non_exit_fail_with_msg(const char8_t* format, va_list_t args) -> int {
    if (1) {
      va_list syslog_args;
      va_copy(syslog_args, args);
      vsyslog(LOG_ERR, format, syslog_args);
    }
    vfprintf(stderr, format, args);
    return EXIT_FAILURE;
  }
}
[[format_printf(1)]] static inline FUNC non_exit_fail_with_msg(const char8_t* format, ...) -> int {
  va_list_t args;
  va_start(args, format);
  int val = va::non_exit_fail_with_msg(format, args);
  va_end(args);
  return val;
}
namespace va {
  [[noreturn]] [[format_va_printf(1)]] static inline FUNC exit_fail_with_msg(const char8_t* format, va_list_t args) -> void {
    exit(va::non_exit_fail_with_msg(format, args));
  }
}
[[noreturn]] [[format_printf(1)]] static inline FUNC exit_fail_with_msg(const char8_t* format, ...) -> void {
  va_list_t args;
  va_start(args, format);
  va::exit_fail_with_msg(format, args);
  va_end(args);
}
// template <typename T, size-t N>
// constexpr size-t dk-countof(T(&)[N]) {
//   return N;
// }
# if !defined USE
  # define    USE(v) cast(void)v
# endif

# if 1
# define klass_of(object)   (object)->klass
# define superklass_of(kls) klass::unbox(kls).superklass
# define name_of(kls)       klass::unbox(kls).name
# else
inline FUNC klass_of(object_t instance) -> object_t {
  return instance->klass;
}
inline FUNC superklass_of(object_t kls) -> object_t {
  return klass::unbox(kls).superklass;
}
inline FUNC name_of(object_t kls) -> object_t {
  return klass::unbox(kls).name;
}
# endif

inline FUNC dkt_normalize_compare_result(intmax_t n) -> int_t { return (n < 0) ? -1 : (n > 0) ? 1 : 0; }
// file scope
# define DKT_SELECTOR_PTR(name, args)         (cast(dkt_selector_func_t) (cast(FUNC (*)args ->       selector_t* ) __selector::name))()
# define SELECTOR(name, args)                *(cast(dkt_selector_func_t) (cast(FUNC (*)args ->       selector_t* ) __selector::name))()
# define SIGNATURE(name, args)                (cast(dkt_signature_func_t)(cast(FUNC (*)args -> const signature_t*) __signature::name))()

// klass/trait scope
# define SLOTS_METHOD_SIGNATURE(name, args)   (cast(dkt_signature_func_t)(cast(FUNC (*)args -> const signature_t*) __slots_method_signature::name))()
# define KW_ARGS_METHOD_SIGNATURE(name, args) (cast(dkt_signature_func_t)(cast(FUNC (*)args -> const signature_t*) __kw_args_method_signature::name))()

# define unless(e) if (0 == (e))
# define until(e)  while (0 == (e))

# define intstr(c1, c2, c3, c4) \
   ((((cast(int64_t)cast(char8_t) c1) << 24) & 0xff000000) | \
    (((cast(int64_t)cast(char8_t) c2) << 16) & 0x00ff0000) | \
    (((cast(int64_t)cast(char8_t) c3) <<  8) & 0x0000ff00) | \
    (((cast(int64_t)cast(char8_t) c4) <<  0) & 0x000000ff))

# if !defined NUL
  # define    NUL cast(char8_t)0
# endif

# if defined DEBUG && defined DK_ENABLE_TRACE_MACROS
  # define DKT_VA_TRACE_BEFORE(signature, method, object, args)               dkt_va_trace_before(signature, method, object, args)
  # define DKT_VA_TRACE_AFTER( signature, method, object, /* result, */ args) dkt_va_trace_after( signature, method, object, args)
  # define DKT_TRACE_BEFORE(signature, method, object, ...)                   dkt_trace_before(   signature, method, object, __VA_ARGS__)
  # define DKT_TRACE_AFTER( signature, method, object, /* result, */ ...)     dkt_trace_after(    signature, method, object, __VA_ARGS__)
  # define DKT_TRACE(statement) statement
# else
  # define DKT_VA_TRACE_BEFORE(signature, method, object, args)
  # define DKT_VA_TRACE_AFTER( signature, method, object, /* result, */ args)
  # define DKT_TRACE_BEFORE(signature, method, object, ...)
  # define DKT_TRACE_AFTER( signature, method, object, /* result, */ ...)
  # define DKT_TRACE(statement)
# endif

# if defined DKT_USE_MAKE_MACRO
  # if defined DEBUG
    # define make(kls, ...) dk::init(dk::alloc(kls, __FILE__, __LINE__), __VA_ARGS__)
  # else
    # define make(kls, ...) dk::init(dk::alloc(kls), __VA_ARGS__)
  # endif
# endif

# define PRIxPTR_WIDTH cast(int_t)(2 * sizeof(uintptr_t))

extern object_t null       [[export]] [[read_only]];
extern object_t std_input  [[export]] [[read_only]];
extern object_t std_output [[export]] [[read_only]];
extern object_t std_error  [[export]] [[read_only]];

using compare_t =            FUNC (*)(object_t, object_t) -> int_t; // comparitor
using dkt_signature_func_t = FUNC (*)() -> const signature_t*;
using dkt_selector_func_t =  FUNC (*)() -> selector_t*;

namespace hash { using slots_t = uintptr_t; } using hash_t = hash::slots_t;

constexpr FUNC dk_hash(str_t str) -> hash_t { // Daniel J. Bernstein
  return !*str ? cast(hash_t)5381 : cast(hash_t)(*str) ^ (cast(hash_t)33 * dk_hash(str + 1));
}
constexpr FUNC dk_hash_switch(str_t str) -> hash_t { return dk_hash(str); }

constexpr FUNC dk_hash_switch( intptr_t val) -> intptr_t  { return val; }
constexpr FUNC dk_hash_switch(uintptr_t val) -> uintptr_t { return val; }

[[export]] FUNC dk_intern(str_t) -> symbol_t;
[[export]] FUNC dk_intern_free(str_t) -> symbol_t;
[[export]] FUNC dk_klass_for_name(symbol_t) -> object_t;

[[export]] FUNC map(object_t, method_t) -> object_t;
[[export]] FUNC map(object_t[], method_t) -> object_t;

[[export]] FUNC dkt_register_info(named_info_t*) -> void;
[[export]] FUNC dkt_deregister_info(named_info_t*) -> void;

// [[so-export]]              FUNC dk-va-add-all(object-t self, va-list-t) -> object-t;
// [[so-export]] [[sentinel]] FUNC dk-add-all(object-t self, ...) -> object-t;

[[export]] FUNC dk_register_klass(named_info_t* klass_info) -> object_t;
[[export]] FUNC dk_init_runtime() -> void;
[[export]] FUNC dk_make_simple_klass(symbol_t name, symbol_t superklass_name, symbol_t klass_name) -> object_t;

[[export]] FUNC dkt_capture_current_exception(object_t arg) -> object_t;
[[export]] FUNC dkt_capture_current_exception(str_t arg, str_t src_file, int_t src_line) -> str_t;

[[export]] FUNC dk_va_make_named_info_slots(symbol_t name, va_list_t args) -> named_info_t*;
[[export]] FUNC dk_va_make_named_info(      symbol_t name, va_list_t args) -> object_t;

[[export]] [[sentinel]] FUNC dk_make_named_info_slots(symbol_t name, ...) -> named_info_t*;
[[export]] [[sentinel]] FUNC dk_make_named_info(      symbol_t name, ...) -> object_t;

[[debug_export]] FUNC dkt_dump(object_t object) -> object_t;
[[debug_export]] FUNC dkt_dump_named_info(named_info_t* info) -> named_info_t*;

//#define DKT-NULL-METHOD nullptr
# define DKT_NULL_METHOD cast(method_t)dkt_null_method

[[export]] [[noreturn]] FUNC dkt_null_method(object_t object, ...) -> void;
[[export]] [[noreturn]] FUNC dkt_throw_no_such_method_exception(object_t object, const signature_t* signature) -> void;
[[export]] [[noreturn]] FUNC dkt_throw_no_such_method_exception(super_t context, const signature_t* signature) -> void;

[[debug_export]] FUNC dkt_va_trace_before(const signature_t* signature, method_t method, object_t object,  va_list_t args) -> int_t;
[[debug_export]] FUNC dkt_va_trace_before(const signature_t* signature, method_t method, super_t  context, va_list_t args) -> int_t;
[[debug_export]] FUNC dkt_va_trace_after( const signature_t* signature, method_t method, object_t object,  va_list_t args) -> int_t;
[[debug_export]] FUNC dkt_va_trace_after( const signature_t* signature, method_t method, super_t  context, va_list_t args) -> int_t;

[[debug_export]] FUNC dkt_trace_before(const signature_t* signature, method_t method, super_t  context, ...) -> int_t;
[[debug_export]] FUNC dkt_trace_before(const signature_t* signature, method_t method, object_t object,  ...) -> int_t;
[[debug_export]] FUNC dkt_trace_after( const signature_t* signature, method_t method, super_t  context, ...) -> int_t;
[[debug_export]] FUNC dkt_trace_after( const signature_t* signature, method_t method, object_t object,  ...) -> int_t;

[[debug_export]] FUNC dkt_get_klass_chain(object_t klass, char8_t* buf, int64_t buf_len) -> char8_t*;

[[debug_export]] FUNC dkt_dump_methods(object_t) -> int64_t;
[[debug_export]] FUNC dkt_dump_methods(klass::slots_t*) -> int64_t;

[[debug_export]] FUNC dkt_unbox_check(object_t object, object_t kls) -> void;

# endif // dkt-dakota-hh
