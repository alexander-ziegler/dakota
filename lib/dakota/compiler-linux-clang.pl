{
  'CXX' => [ 'clang++' ],
  'CXX_COMPILE_FLAGS' =>     [ '--compile', '-emit-llvm' ],
  'CXX_COMPILE_PIC_FLAGS' => [ '--compile', '-emit-llvm', '-fPIC' ], # clang does not understand --PIC
  'CXX_WARNINGS_FLAGS' =>    [
      '-Wno-c++98-compat-pedantic',
      '-Wno-c++98-compat',
      '-Wno-cast-align',
      '-Wno-deprecated',
      '-Wno-disabled-macro-expansion',
      '-Wno-exit-time-destructors',
      '-Wno-four-char-constants',
      '-Wno-global-constructors',
      '-Wno-multichar',
      '-Wno-old-style-cast',
      '-Wno-padded',
      ],
  'O_EXT' =>  [ 'bc' ],
}
