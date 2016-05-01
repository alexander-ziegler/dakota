// -*- mode: Dakota; c-basic-offset: 2; tab-width: 2; indent-tabs-mode: nil -*-

// Copyright (C) 2007 - 2015 Robert Nielsen <robert@dakota.org>
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

# if !defined dakota-safe-str-kt
# define      dakota-safe-str-kt

# include <cstdlib>
# include <cstring>

inline func safe-strcmp(str-t s1, str-t s2) -> int-t {
  int-t value = 0;

  if (nullptr == s1 || nullptr == s2) {
    if (nullptr == s1 && nullptr == s2)
      value = 0;
    else if (nullptr == s1)
      value = -1;
    else if (nullptr == s2)
      value = 1;
  } else {
    value = strcmp(s1, s2);
  }
  return value;
}
inline func safe-strptrcmp(const str-t* sp1, const str-t* sp2) -> int-t {
  str-t s1;
  if (nullptr == sp1)
    s1 = nullptr;
  else
    s1 = *sp1;
  str-t s2;
  if (nullptr == sp2)
    s2 = nullptr;
  else
    s2 = *sp2;
  return safe-strcmp(s1, s2);
}
inline func safe-strncmp(str-t s1, str-t s2, size-t n) -> int-t {
  int-t value = 0;

  if (nullptr == s1 || nullptr == s2) {
    if (nullptr == s1 && nullptr == s2)
      value = 0;
    else if (nullptr == s1)
      value = -1;
    else if (nullptr == s2)
      value = 1;
  } else {
    value = strncmp(s1, s2, n);
  }
  return value;
}
inline func safe-strlen(str-t str) -> size-t {
  size-t len;

  if (nullptr == str)
    len = 0;
  else
    len = strlen(str);
  return len;
}

# endif