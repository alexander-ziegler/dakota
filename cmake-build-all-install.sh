#!/bin/bash
set -o errexit -o nounset -o pipefail
source common.sh
compiler=$(compiler)
platform=$(platform)
if [[ -z ${INSTALL_PREFIX+x} ]]; then
  INSTALL_PREFIX=/usr/local
fi
if [[ $# == 1 ]]; then
  INSTALL_PREFIX=$1
fi
export INSTALL_PREFIX

build() {
  dir=$1
  cd $dir
  cwd=$(pwd)
  echo cwd=$cwd
  rootdir=..
  $rootdir/bin/build-exhaustive.sh
  $rootdir/bin/build.sh install
  cd ..
}
export PATH=$INSTALL_PREFIX/bin:$PATH
export CMAKE_VERBOSE_MAKEFILE=ON

mkdir -p $INSTALL_PREFIX/{bin,include,lib/dakota}

./bin/build-uninstall.sh $INSTALL_PREFIX

# dakota-dso dakota-catalog dakota-find-library
# dakota-core dakota

build dakota-dso
build dakota-catalog
build dakota-find-library

build dakota-core

pushd $INSTALL_PREFIX/lib/dakota
ln -fs compiler-command-line-$compiler.json compiler-command-line.json
ln -fs platform-$platform.json platform.json
popd

build dakota

glob='/opt/local/bin/dakota* /opt/local/lib/libdakota* /opt/local/include/dakota*'
match=$(echo $glob)
if [[ $INSTALL_PREFIX != "/opt/local" && "$glob" != "$match" ]]; then
  echo $(basename $0): warning: installation also in /opt/local >&2
fi
