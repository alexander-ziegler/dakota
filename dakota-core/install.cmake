set (install-lib-dakota-files
  ${CMAKE_SOURCE_DIR}/lib/dakota/base.cmake
  ${CMAKE_SOURCE_DIR}/lib/dakota/compiler-clang.opts
  ${CMAKE_SOURCE_DIR}/lib/dakota/compiler-gcc.opts
  ${CMAKE_SOURCE_DIR}/lib/dakota/extra.json
  ${CMAKE_SOURCE_DIR}/lib/dakota/lang-user-data.json
  ${CMAKE_SOURCE_DIR}/lib/dakota/platform-darwin.json
  ${CMAKE_SOURCE_DIR}/lib/dakota/platform-linux.json
  ${CMAKE_SOURCE_DIR}/lib/dakota/used.json
  ${CMAKE_SOURCE_DIR}/lib/dakota/dakota.pm
  ${CMAKE_SOURCE_DIR}/lib/dakota/generate.pm
  ${CMAKE_SOURCE_DIR}/lib/dakota/parse.pm
  ${CMAKE_SOURCE_DIR}/lib/dakota/rewrite.pm
  ${CMAKE_SOURCE_DIR}/lib/dakota/sst.pm
  ${CMAKE_SOURCE_DIR}/lib/dakota/util.pm
)
set (install-include-files
  ${CMAKE_SOURCE_DIR}/include/dakota-finally.h
  ${CMAKE_SOURCE_DIR}/include/dakota-log.h
  ${CMAKE_SOURCE_DIR}/include/dakota-object-defn.inc
  ${CMAKE_SOURCE_DIR}/include/dakota-object.inc
  ${CMAKE_SOURCE_DIR}/include/dakota-of.inc
  ${CMAKE_SOURCE_DIR}/include/dakota-os.h
  ${CMAKE_SOURCE_DIR}/include/dakota-other.inc
  ${CMAKE_SOURCE_DIR}/include/dakota-weak-object-defn.inc
  ${CMAKE_SOURCE_DIR}/include/dakota-weak-object.inc
  ${CMAKE_SOURCE_DIR}/include/dakota.h
)
set (install-bin-files
  ${CMAKE_SOURCE_DIR}/bin/dakota
  ${CMAKE_SOURCE_DIR}/bin/dakota-parts
  ${CMAKE_SOURCE_DIR}/bin/dakota-fixup-stderr
)
install (
  FILES ${install-lib-dakota-files}
  DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/dakota
)
install (
  FILES ${install-include-files}
  DESTINATION ${CMAKE_INSTALL_PREFIX}/include
)
install (
  PROGRAMS ${install-bin-files}
  DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
)
