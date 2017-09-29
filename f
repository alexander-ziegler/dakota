#!/bin/bash
set -o errexit -o nounset -o pipefail

so_targets=(
  dakota-core
  dakota
)
exe_targets=(
  exe-core
  exe
)

cat /dev/null > build.mk

for tgt in ${so_targets[@]}; do
  dakota-make.pl --var=root_source_dir=/Users/robert/dakota \
                 --var=source_dir=/Users/robert/dakota/$tgt \
                 --var=build_dir=/Users/robert/dakota/zzz/build/$tgt \
                 --target /Users/robert/dakota/lib/lib$tgt.dylib
                 #--parts /Users/robert/dakota/$tgt/parts.txt
  echo "include $tgt/build.mk" >> build.mk
done
for tgt in ${exe_targets[@]}; do
  dakota-make.pl --var=root_source_dir=/Users/robert/dakota \
                 --var=source_dir=/Users/robert/dakota/$tgt \
                 --var=build_dir=/Users/robert/dakota/zzz/build/$tgt \
                 --target /Users/robert/dakota/bin/$tgt
                 #--parts /Users/robert/dakota/$tgt/parts.txt
  echo "include $tgt/build.mk" >> build.mk
done
rm -rf zzz
SECONDS=0
make $@ -j 10 -f build.mk
duration=$SECONDS
echo "duration: $(($duration / 60))m$(($duration % 60))s"
