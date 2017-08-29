# -*- mode: cmake -*-
set (CMAKE_VERBOSE_MAKEFILE $ENV{CMAKE_VERBOSE_MAKEFILE})

function (opts_str values output-var)
  string (REPLACE ";" " " str "${values}")
  set (${output-var} "${str}" PARENT_SCOPE)
endfunction()

function (install_symlink file symlink)
  install (CODE "execute_process (COMMAND ${CMAKE_COMMAND} -E create_symlink ${file} ${symlink})")
  install (CODE "message (\"-- Installing symlink: ${symlink} -> ${file}\")")
endfunction ()

function (find_lib_files lib-dirs libs lib-files-var)
  foreach (lib ${libs})
    set (found-lib-file NOTFOUND) # found-lib-file-NOTFOUND
    find_library (found-lib-file ${lib} PATHS ${lib-dirs})
    if (NOT found-lib-file)
      message (FATAL_ERROR "error: target: ${target}: find_library(): ${lib}")
    endif ()
    #message ( "info: target: ${target}: find_library(): ${lib} => ${found-lib-file}")
    list (APPEND files ${found-lib-file})
  endforeach ()
  set (${lib-files-var} "${files}" PARENT_SCOPE)
endfunction ()

function (find_target_lib_files target-libs target-lib-files-var)
  foreach (lib ${target-libs})
    set (target-lib-file ${dakota-lang-source-dir}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}${lib}${CMAKE_SHARED_LIBRARY_SUFFIX})
    list (APPEND files ${target-lib-file})
  endforeach ()
  set (${target-lib-files-var} "${files}" PARENT_SCOPE)
endfunction ()

if (NOT target-type)
  set (target-type executable)
endif ()

if ("${target-type}" STREQUAL "shared-library")
  add_library (${target} SHARED ${srcs})
  set_target_properties (${target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${dakota-lang-source-dir}/lib)
  install (TARGETS ${target} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib)
  set (target-output-file ${CMAKE_SHARED_LIBRARY_PREFIX}${target}${CMAKE_SHARED_LIBRARY_SUFFIX})
elseif ("${target-type}" STREQUAL "executable")
  add_executable (${target} ${srcs})
  set_target_properties (${target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${dakota-lang-source-dir}/bin)
  install (TARGETS ${target} DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
  set (target-output-file ${target}${CMAKE_EXECUTABLE_SUFFIX})
else ()
  message (FATAL_ERROR "error: target-type must be shared-library or executable.")
endif ()

find_lib_files ("${lib-dirs}" "${libs}" lib-files)
find_target_lib_files ("${target-libs}" target-lib-files)

set (compiler-opts @${dakota-lang-source-dir}/lib/dakota/compiler.opts)
set (linker-opts   @${dakota-lang-source-dir}/lib/dakota/linker.opts)
target_compile_options (${target} PRIVATE ${compiler-opts})
set (link-options ${linker-opts})
set (CMAKE_PREFIX_PATH  ${dakota-lang-source-dir})
#set (CMAKE_LIBRARY_PATH ${dakota-lang-source-dir}/lib)
set (cxx-standard 17)
set (CMAKE_COMPILER_IS_GNUCXX TRUE)

set (cxx-compiler NOTFOUND) # cxx-compiler-NOTFOUND
find_program (cxx-compiler clang++${CMAKE_EXECUTABLE_SUFFIX})
if (NOT cxx-compiler)
  message (FATAL_ERROR "error: program: clang++: find_library(): ${cxx-compiler}")
endif ()

set (CMAKE_CXX_COMPILER ${cxx-compiler})
set (dakota NOTFOUND) # dakota-NOTFOUND
find_program (dakota dakota${CMAKE_EXECUTABLE_SUFFIX} PATHS ${bin-dirs})
if (NOT dakota)
  message (FATAL_ERROR "error: program: dakota: find_library(): ${dakota}")
endif ()

set (CMAKE_CXX_COMPILER ${dakota})
set (parts ${build-dir}/parts.yaml)
execute_process (
  COMMAND ${dakota-lang-source-dir}/bin/dakota-parts ${parts}
    source-dir:         ${dakota-lang-source-dir}
    project-source-dir: ${PROJECT_SOURCE_DIR}
    build-dir:          ${build-dir}
    lib-files:          ${target-lib-files} ${lib-files}
    srcs:               ${srcs})
execute_process (
  COMMAND ${dakota} --target-src --parts ${parts} --path-only
  OUTPUT_VARIABLE target-src
  OUTPUT_STRIP_TRAILING_WHITESPACE)
target_sources (${target} PRIVATE ${target-src})
set (target-hdr ${target}.target-hdr)
# phony target 'target-hdr'
add_custom_target (
  ${target-hdr}
  DEPENDS ${parts} ${target-libs} dakota-catalog${CMAKE_EXECUTABLE_SUFFIX}
  COMMAND ${dakota} --target-hdr --parts ${parts}
  VERBATIM)
# generate target-src
add_custom_command (
  OUTPUT ${target-src}
  DEPENDS ${parts} ${target-libs} dakota-catalog${CMAKE_EXECUTABLE_SUFFIX}
  COMMAND ${dakota} --target-src --parts ${parts}
  VERBATIM)
add_dependencies (${target} ${target-hdr})
target_compile_options (${target} PRIVATE
  --parts ${parts} --cxx ${cxx-compiler})
list (APPEND link-options
  --parts ${parts} --cxx ${cxx-compiler})

set (compile-defns DKT_TARGET_FILE="${target-output-file}" DKT_TARGET_TYPE="${target-type}")
set_source_files_properties (${target-src} PROPERTIES COMPILE_DEFINITIONS "${compile-defns}")

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
opts_str ("${link-options}" link-options-str)
set_target_properties (${target} PROPERTIES LINK_FLAGS "${link-options-str}")
list (LENGTH lib-files len)
if (${len})
  target_link_libraries (${target} ${lib-files})
endif ()
list (LENGTH target-lib-files len)
if (${len})
  target_link_libraries (${target} ${target-lib-files})
  add_dependencies (     ${target} ${target-libs})
endif ()
