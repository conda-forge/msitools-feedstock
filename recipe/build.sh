#!/bin/bash

set -euxo pipefail

if [[ "${build_platform}" != "${target_platform}" ]]; then
  # Generation of introspection isn't currently working in cross-compilation mode.
  export MESON_ARGS="${MESON_ARGS:-} -Dintrospection=false"
fi
meson ${MESON_ARGS:-} --buildtype=release --prefix="$PREFIX" --backend=ninja -Dlibdir=lib ..
ninja
ninja install
