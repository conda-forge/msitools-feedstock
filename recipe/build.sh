#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == osx-* ]]; then
  export CFLAGS="${CFLAGS} -Wno-incompatible-function-pointer-types"
fi
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  rm ${PREFIX}/bin/glib-mkenums
  ln -sf ${BUILD_PREFIX}/bin/glib-mkenums ${PREFIX}/bin/glib-mkenums
fi

# We will always need introspection to build the wixl command.
meson_config_args=(
    --backend=ninja
    -Dbuildtype=release
    -Dlibdir=lib
    -Dintrospection=true
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
        -Dbuildtype=release \
        -Dlibdir=lib \
        --prefix=$BUILD_PREFIX \
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

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" && "${target_platform}" == linux-* ]]; then
    # Is there a better way to use ldd during cross compilation?
    # gobject-introspection either suggests passing an ldd wrapper, or ensuring
    # that the native ldd can be used. We choose the second strategy.
    # https://github.com/conda-forge/ctng-compilers-feedstock/issues/110
    cp ${CONDA_BUILD_SYSROOT}/usr/bin/ldd ${BUILD_PREFIX}/bin/ldd

    # On ppc64le it is specified as two things, so we have to argument both
    sed -i "/^RTLDLIST/s,/lib/,${CONDA_BUILD_SYSROOT}/lib/," ${BUILD_PREFIX}/bin/ldd
    sed -i "/^RTLDLIST/s,/lib64/,${CONDA_BUILD_SYSROOT}/lib64/," ${BUILD_PREFIX}/bin/ldd
fi

meson setup builddir/ \
  ${MESON_ARGS} \
  "${meson_config_args[@]}" \
  --prefix=$PREFIX \
  || { cat builddir/meson-logs/meson-log.txt; exit 1; }

ninja -v -C builddir/ -j${CPU_COUNT}
ninja -C builddir/ install

if [[ ("${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR:-}" != "") && "${target_platform}" != osx-64  ]]; then
  ninja -C builddir/ -j${CPU_COUNT} test
fi

