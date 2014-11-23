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

#if !defined __dakota_h__
#define      __dakota_h__

#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>

#include <stdarg.h> // va_list
#define __STDC_LIMIT_MACROS
#include <stdint.h>

#define DKT_WORKAROUND 1

#if defined WIN32
#  define format_va_printf(fmtarg)
#  define format_va_scanf(fmtarg)
#  define format_printf(fmtarg)
#  define format_scanf(fmtarg)
#  define flatten
#  define pure
#  define sentinel
#  define unused
#  define import   __declspec(dllimport)
#  define export   __declspec(dllexport)
#  define noexport
#else
#  define format_va_printf(fmtarg) __attribute__((__format__(__printf__, fmtarg, 0)))
#  define format_va_scanf(fmtarg)  __attribute__((__format__(__scanf__,  fmtarg, 0)))
#  define format_printf(fmtarg)    __attribute__((__format__(__printf__, fmtarg, fmtarg + 1)))
#  define format_scanf(fmtarg)     __attribute__((__format__(__scanf__,  fmtarg, fmtarg + 1)))
#  define flatten  __attribute__((__flatten__))
#  define pure     __attribute__((__pure__))
#  define sentinel __attribute__((__sentinel__))
#  define unused   __attribute__((__unused__))
#  define import
#  define export   __attribute__((__visibility__("default")))
#  define noexport __attribute__((__visibility__("hidden")))
#endif

#if !defined DK_VISIBILITY
#if 0
#  define DK_VISIBILITY export
#else
#  define DK_VISIBILITY noexport
#endif
#endif

#define THROW  throw
#define STATIC static

//#define DUMP_MEM_FOOTPRINT

#if !defined USE
#define      USE(v) (void)v
#endif // USE

//static_cast<double>(4)
//       cast(double)(4)
//       cast(double)4
#define cast(t) (t)
#define DK_ARRAY_LENGTH(array) (cast(uint32_t)(sizeof((array))/sizeof((array)[0])))

#define dkt_klass(object)   (object)->klass
#define dkt_superklass(kls) klass::unbox(kls)->superklass
#define dkt_name(kls)       klass::unbox(kls)->name

#define normalize_compare_result(n) ((n) < 0) ? -1 : ((n) > 0) ? 1 : 0
#define else_if   else if
#define unless(e) if (0 == (e))
#define until(e)  while (0 == (e))
#define raw_signature(name,args) (cast(dkt_signature_function_t)(cast(const signature_t* (*)args) __raw_signature::name))()
#define signature(name, args)    (cast(dkt_signature_function_t)(cast(const signature_t* (*)args) __signature::name))()
#define ka_signature(name, args) (cast(dkt_signature_function_t)(cast(const signature_t* (*)args) __ka_signature::name))()
#define selector(name, args)    *(cast(dkt_selector_function_t) (cast(selector_t*        (*)args) __selector::name))()

#define intstr(c1, c2, c3, c4) \
   ((((cast(int32_t)cast(char8_t) c1) << 24) & 0xff000000) | \
    (((cast(int32_t)cast(char8_t) c2) << 16) & 0x00ff0000) | \
    (((cast(int32_t)cast(char8_t) c3) <<  8) & 0x0000ff00) | \
    (((cast(int32_t)cast(char8_t) c4) <<  0) & 0x000000ff))

// boole-t is promoted to int-t when used in va_arg() macro
#define DK_VA_ARG_BOOLE_T int_t

#if !defined NUL
#define      NUL cast(char)0
#endif // NUL

typedef int int_t;
typedef unsigned int uint_t;
typedef va_list va_list_t;

#define compile_assert(v) typedef int_t compile_assert_failed[(v) ? 1 : -1]

#if defined DEBUG
#  define DK_TRACE(statement) statement
#  define DK_TRACE_BEFORE(signature, method, ...) dk_trace_before(signature, method, __VA_ARGS__)
#  define DK_TRACE_AFTER( signature, method, ...) dk_trace_after( signature, method, __VA_ARGS__)
#else
#  define DK_TRACE(statement)
#  define DK_TRACE_BEFORE(signature, method, ...)
#  define DK_TRACE_AFTER( signature, method, ...)
#endif

#if defined DEBUG
#  define DK_VA_TRACE_BEFORE_INIT(kls, args) dk_va_trace_before_init(kls, args)
#  define DK_VA_TRACE_AFTER_INIT( kls, args) dk_va_trace_after_init(kls, args)
#else
#  define DK_VA_TRACE_BEFORE_INIT(kls, args)
#  define DK_VA_TRACE_AFTER_INIT( kls, args)
#endif

#if defined DK_USE_MAKE_MACRO
#  if DEBUG
#    define make(kls, ...) dk::init(dk::alloc(kls, __FILE__, __LINE__), __VA_ARGS__)
#  else
#    define make(kls, ...) dk::init(dk::alloc(kls), __VA_ARGS__)
#  endif
#endif

#define PRIxPTR_WIDTH cast(int_t)(2 * sizeof(uintptr_t))

import void dk_init_runtime();

#endif // __dakota_h__
