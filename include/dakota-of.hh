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

# if !defined dkt_dakota_of_hh
# define      dkt_dakota_of_hh

inline FUNC klass_of(object_t instance) -> object_t {
  return instance->klass;
}
inline FUNC superklass_of(object_t kls) -> object_t {
  return klass::unbox(kls).superklass;
}
inline FUNC name_of(object_t kls) -> symbol_t {
  return klass::unbox(kls).name;
}

// namespace dk {
//   using  size_t =  size::slots_t;
//   using ssize_t = ssize::slots_t;
// }

# endif // dkt-dakota-of-hh