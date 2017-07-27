# -*- mode: cmake -*-
set (root-dir ${CMAKE_SOURCE_DIR}/..)
set (CMAKE_VERBOSE_MAKEFILE $ENV{CMAKE_VERBOSE_MAKEFILE})
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  if (DEFINED ENV{INSTALL_PREFIX})
    set (CMAKE_INSTALL_PREFIX $ENV{INSTALL_PREFIX})
  else ()
    set (CMAKE_INSTALL_PREFIX /usr/local)
  endif ()
endif()

set (SOURCE_DIR     ${CMAKE_SOURCE_DIR})
set (BINARY_DIR     ${CMAKE_BINARY_DIR})
set (INSTALL_PREFIX ${CMAKE_INSTALL_PREFIX})

include (${CMAKE_SOURCE_DIR}/dakota.cmake)
include (${root-dir}/warn.cmake)

set (project ${target})
project (${project} LANGUAGES CXX)
set (cxx-standard 17)
set (CMAKE_COMPILER_IS_GNUCXX TRUE)

set (CMAKE_CXX_COMPILER clang++) # must follow: project (<> LANGUAGES CXX)
set_directory_properties (PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${builddir})
set_source_files_properties (${srcs} PROPERTIES LANGUAGE CXX CXX_STANDARD ${cxx-standard})
set (CMAKE_LIBRARY_PATH ${CMAKE_INSTALL_PREFIX}/lib)
set (found-libs)
foreach (lib ${libs})
  set (lib-path lib-path-NOTFOUND)
  find_library (lib-path ${lib})
  list (APPEND found-libs ${lib-path})
endforeach (lib)

if (${is-lib})
  add_library (${target} SHARED ${srcs})
  set (targets-install-dir ${CMAKE_INSTALL_PREFIX}/lib)
else ()
  add_executable (${target} ${srcs})
  set (targets-install-dir ${CMAKE_INSTALL_PREFIX}/bin)
endif ()

set (sanitize-opts -fsanitize=address)
include_directories (${include-dirs})
install (TARGETS ${target} DESTINATION ${targets-install-dir})
install (FILES ${install-include-files} DESTINATION ${CMAKE_INSTALL_PREFIX}/include)
target_compile_definitions (${target} PRIVATE ${macros})
target_compile_options (${target} PRIVATE
  ${sanitize-opts}
  @${CMAKE_SOURCE_DIR}/${warn-opts-file}
)
set_target_properties (${target} PROPERTIES LANGUAGE CXX CXX_STANDARD ${cxx-standard})
target_link_libraries (${target} ${found-libs} ${sanitize-opts})
