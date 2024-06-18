#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == osx-* ]]; then
  export CFLAGS="${CFLAGS} -Wno-incompatible-function-pointer-types"
fi

meson_config_args=(
    --buildtype=release
    --backend=ninja
    -Dlibdir=lib
)

# necessary to ensure the gobject-introspection-1.0 pkg-config file gets found
# meson needs this to determine where the g-ir-scanner script is located
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$BUILD_PREFIX/lib/pkgconfig
export PKG_CONFIG=$BUILD_PREFIX/bin/pkg-config

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  unset _CONDA_PYTHON_SYSCONFIGDATA_NAME
  (
    mkdir -p native-build

    export CC=$CC_FOR_BUILD
    if [[ "${target_platform}" == osx-* ]]; then
      export OBJC=$OBJC_FOR_BUILD
    fi
    export AR=($CC_FOR_BUILD -print-prog-name=ar)
    export NM=($CC_FOR_BUILD -print-prog-name=nm)
    export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
    export PKG_CONFIG_PATH=${BUILD_PREFIX}/lib/pkgconfig
    export CFLAGS="-Wno-incompatible-function-pointer-types"

    # Unset them as we're ok with builds that are either slow or non-portable
    unset CPPFLAGS
    export host_alias=$build_alias
    export PKG_CONFIG_PATH=$BUILD_PREFIX/lib/pkgconfig
    export GIO_MODULE_DIR=$BUILD_PREFIX/lib/gio/modules

    meson setup native-build \
        "${meson_config_args[@]}" \
        --buildtype=release \
        --prefix=$BUILD_PREFIX \
        -Dlibdir=lib \
        --wrap-mode=nofallback

    # This script would generate the functions.txt and dump.xml and save them
    # This is loaded in the native build. We assume that the functions exported
    # by glib are the same for the native and cross builds
    export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-save.sh
    ninja -v -C native-build -j ${CPU_COUNT}
    ninja -C native-build install -j ${CPU_COUNT}
  )
  export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-load.sh
fi

if [[ "${build_platform}" != "${target_platform}" ]]; then
  # Generation of introspection isn't currently working in cross-compilation mode.
  export MESON_ARGS="${MESON_ARGS:-} -Dintrospection=false"
else
  export MESON_ARGS="${MESON_ARGS:-} -Dintrospection=true"
fi

meson setup builddir/ \
  ${MESON_ARGS} \
  "${meson_config_args[@]}" \
  --prefix=$PREFIX \
  || { cat builddir/meson-logs/meson-log.txt; exit 1; }

ninja -C builddir/ -j${CPU_COUNT}

if [[ ("${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR:-}" != "") && "${target_platform}" != osx-64  ]]; then
  ninja -C builddir/ -j${CPU_COUNT} test
fi

ninja -C builddir/ install

