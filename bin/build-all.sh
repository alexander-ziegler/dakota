#!/bin/bash
set -o errexit -o nounset -o pipefail
binary_dir=$(cat cmake-binary-dir.txt)
jobs=$(getconf _NPROCESSORS_ONLN)
make --directory $binary_dir              init
make --directory $binary_dir --jobs $jobs all
