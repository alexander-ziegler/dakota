#!/bin/bash
set -o errexit -o nounset -o pipefail

make -f broken.mk
