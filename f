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
  dakota-make.pl --var=current_source_dir=/Users/robert/dakota/$tgt \
                 --var=source_dir=/Users/robert/dakota \
                 --var=build_dir=/Users/robert/dakota/zzz/build \
                 --target /Users/robert/dakota/lib/lib$tgt.dylib
                 #--parts /Users/robert/dakota/$tgt/parts.txt
  echo "include $tgt/build.mk" >> build.mk
done
for tgt in ${exe_targets[@]}; do
  dakota-make.pl --var=current_source_dir=/Users/robert/dakota/$tgt \
                 --var=source_dir=/Users/robert/dakota \
                 --var=build_dir=/Users/robert/dakota/zzz/build \
                 --target /Users/robert/dakota/bin/$tgt
                 #--parts /Users/robert/dakota/$tgt/parts.txt
  echo "include $tgt/build.mk" >> build.mk
done
jobs=$(getconf _NPROCESSORS_ONLN)
jobs=$(( jobs + 2 ))
rm -rf zzz
SECONDS=0
make $@ -j $jobs -f build.mk libdakota
duration=$SECONDS
echo "duration: $(($duration / 60))m$(($duration % 60))s"
make $@ -j $jobs -f build.mk exe-core exe
set -o xtrace
bin/exe-core
bin/exe
