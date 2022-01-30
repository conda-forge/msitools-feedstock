#!/bin/bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./build-aux

./configure --prefix=$PREFIX
make -j${CPU_COUNT}
if [[ $target_platform != osx-64 ]]; then
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
  make check -j${CPU_COUNT}
fi
fi
make install
