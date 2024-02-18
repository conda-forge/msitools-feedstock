#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == osx-* ]]; then
  export CFLAGS="${CFLAGS} -Wno-incompatible-function-pointer-types"
  # export CXXFLAGS="${CXXFLAGS} -Wno-incompatible-function-pointer-types"
fi

meson setup builddir/ \
  ${MESON_ARGS} \
  --buildtype=release \
  --prefix=$PREFIX \
  || { cat builddir/meson-logs/meson-log.txt; exit 1; }

ninja -C builddir/ -j${CPU_COUNT}

if [[ ("${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "") && "${target_platform}" != osx-64  ]]; then
  ninja -C builddir/ -j${CPU_COUNT} test
fi

ninja -C builddir/ install

