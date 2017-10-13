# -*- mode: cmake -*-
set (macros
)
set (bin-dirs
  ${source_dir}/bin
)
set (include-dirs
  .
  ${source_dir}/include
)
set (lib-dirs
)
set (libs
)
set (target-libs
  dakota-dso
)
set (target dakota-core)
set (target-type shared-library)
set (srcs
  bit-vector.dk
  boole.dk
  char.dk
  collection.dk
  compare.dk
  const-info.dk
  core.dk
  counted-set.dk
  dakota-core.dk
  deque.dk
  item-already-present-exception.dk
  enum-info.dk
  exception.dk
  hash.dk
  illegal-klass-exception.dk
  input-stream.dk
  int.dk
  iterator.dk
  keyword-exception.dk
  keyword.dk
  klass.dk
  method-alias.dk
  method.dk
  missing-keyword-exception.dk
  named-enum-info.dk
  named-info.dk
  no-such-keyword-exception.dk
  no-such-method-exception.dk
  no-such-slot-exception.dk
  number.dk
  object-input-stream.dk
  object-output-stream.dk
  object.dk
  output-stream.dk
  pair.dk
  property.dk
  ptr.dk
  result.dk
  selector-node.dk
  selector.dk
  sequence.dk
  set-of-pairs.dk
  set.dk
  signal-exception.dk
  signature.dk
  singleton-klass.dk
  size.dk
  sorted-counted-set.dk
  sorted-set-core.dk
  sorted-set.dk
  sorted-table.dk
  stack.dk
  std-compare.dk
  str.dk
  str128.dk
  str256.dk
  str32.dk
  str512.dk
  str64.dk
  stream.dk
  string.dk
  super.dk
  symbol.dk
  system-exception.dk
  table.dk
  trace.dk
  unbox-illegal-klass-exception.dk
  vector.dk
)
