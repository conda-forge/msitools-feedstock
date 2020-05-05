#!/bin/bash

./configure --prefix=$PREFIX
make -j${CPU_COUNT}
if [[ $target_platform != osx-64 ]]; then
  make check -j${CPU_COUNT}
fi
make install
