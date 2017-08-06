# -*- mode: cmake -*-
set (CMAKE_VERBOSE_MAKEFILE $ENV{CMAKE_VERBOSE_MAKEFILE})
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  if (DEFINED ENV{INSTALL_PREFIX})
    set (CMAKE_INSTALL_PREFIX $ENV{INSTALL_PREFIX})
  else ()
    set (CMAKE_INSTALL_PREFIX /usr/local)
  endif ()
endif ()

set (lib-files)
foreach (lib ${libs})
  set (found-lib-file NOTFOUND) # lib-NOTFOUND
  find_library (found-lib-file ${lib} PATHS ${lib-dirs})
  if (NOT found-lib-file)
    message (FATAL_ERROR "error: target: ${target}: find_library(): ${lib}")
  endif ()
  #message ( "info: target: ${target}: find_library(): ${lib} => ${found-lib-file}")
  list (APPEND lib-files ${found-lib-file})
endforeach ()

set (target-lib-files)
foreach (lib ${target-libs})
  set (target-lib-file ${root-source-dir}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}${lib}${CMAKE_SHARED_LIBRARY_SUFFIX})
  list (APPEND target-lib-files ${target-lib-file})
endforeach ()

macro (install_symlink file symlink)
  install (CODE "execute_process (COMMAND ${CMAKE_COMMAND} -E create_symlink ${file} ${symlink})")
  install (CODE "message (\"-- Installing symlink: ${symlink} -> ${file}\")")
endmacro ()

if (NOT is-lib)
  set (is-lib 0)
endif ()

set (CMAKE_PREFIX_PATH  ${root-source-dir})
#set (CMAKE_LIBRARY_PATH ${root-source-dir}/lib)
set (cxx-standard 17)
set (CMAKE_COMPILER_IS_GNUCXX TRUE)
find_program (cxx-compiler clang++)
set (CMAKE_CXX_COMPILER ${cxx-compiler})

if (${is-lib})
  add_library (${target} SHARED ${srcs})
  set_target_properties (${target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${root-source-dir}/lib)
  install (TARGETS ${target} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib)
else ()
  add_executable (${target} ${srcs})
  set_target_properties (${target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${root-source-dir}/bin)
  install (TARGETS ${target} DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
endif ()

install (FILES ${install-include-files} DESTINATION ${CMAKE_INSTALL_PREFIX}/include)
set (additional-make-clean-files
  ${build-dir}
)
set_directory_properties (PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${additional-make-clean-files}")
set_source_files_properties (${srcs} PROPERTIES LANGUAGE CXX CXX_STANDARD ${cxx-standard})
set_target_properties (${target} PROPERTIES LANGUAGE CXX CXX_STANDARD ${cxx-standard})
set_target_properties (${target} PROPERTIES CXX_VISIBILITY_PRESET hidden)
#set (CMAKE_CXX_VISIBILITY_PRESET hidden)
target_compile_definitions (${target} PRIVATE ${macros})
target_include_directories (${target} PRIVATE ${include-dirs})
target_compile_options (${target} PRIVATE
  ${compiler-opts}
)
string (CONCAT link-flags
  " ${linker-opts}"
)
set_target_properties (${target} PROPERTIES LINK_FLAGS ${link-flags})
list (LENGTH lib-files len)
if (${len})
  target_link_libraries (${target} ${lib-files})
endif ()
list (LENGTH target-lib-files len)
if (${len})
  target_link_libraries (${target} ${target-lib-files})
  add_dependencies (     ${target} ${target-libs})
endif ()
