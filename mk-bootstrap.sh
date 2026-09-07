#!/usr/bin/env bash

############## INFINUX BOOTSTRAP SCRIPT ################
# This script builds the very simple bootstrap toolchain
# needed to build the rest of `calculus`'s packages
# 
# This includes
# - A statically linked `musl`
# - A statically linked `busybox`
# - And A statically linked GCC based on that musl version
#
# It will fetch stuff from the internet (but cache them otherwise if already fetched
########################################################

set -euo pipefail

# Download https://github.com/kraj/musl/archive/refs/tags/v{ver}.tar.gz to ./src-tar/musl-{ver}.tar.gz
MUSL_VERSION="1.2.6"

# Download https://ftp.gnu.org/gnu/binutils/binutils-{ver}.tar.gz to ./src-tar/binutils-{ver}.tar.gz
BINUTILS_VERSION="2.47"

# Download https://ftp.gnu.org/gnu/gcc/gcc-{ver}/gcc-{ver}.tar.gz to ./tars/gcc-{ver}.tar.gz
GCC_VERSION="16.2.0"

# Download https://ftp.gnu.org/gnu/gmp/gmp-{ver}.tar.gz to ./tars/gcc-{ver}.tar.gz
GMP_VERSION="6.3.0"

# Download https://ftp.gnu.org/gnu/mpfr/mpfr-{ver}.tar.gz to ./tars/mpfr-{ver}.tar.gz
MPFR_VERSION="4.2.2"

# Download https://ftp.gnu.org/gnu/mpc/mpc-{ver}.tar.xz to ./tars/mpc-{ver}.tar.xz
MPC_VERSION="1.4.1"

# Download https://github.com/vda-linux/busybox_mirror/archive/refs/tags/{ver}.tar.gz to ./src-tar/musl-{ver}.tar.gz
BUSYBOX_VERSION="1_36_1"

DOWNLOAD_CACHE=$(pwd)/.tars
WORK_DIR=$(pwd)/.build
CROSS_DIR=$(pwd)/cross-toolchain
OUT_DIR=$(pwd)/dist
SEED_SYSROOT="$WORK_DIR/sysroot"
TARGET="x86_64-linux-musl"

rm -rf $WORK_DIR $OUT_DIR $CROSS_DIR
mkdir -p "$DOWNLOAD_CACHE" "$WORK_DIR" "$OUT_DIR" "$SEED_SYSROOT/bin" "$SEED_SYSROOT/usr/include"

if [[ ! -f "$DOWNLOAD_CACHE/musl-$MUSL_VERSION.tar.gz" ]]; then
    echo "Fetching musl from" "https://github.com/kraj/musl/archive/refs/tags/v$MUSL_VERSION.tar.gz"
    curl -sSL "https://github.com/kraj/musl/archive/refs/tags/v$MUSL_VERSION.tar.gz" -o "$DOWNLOAD_CACHE/musl-$MUSL_VERSION.tar.gz"
fi

if [[ ! -f "$DOWNLOAD_CACHE/binutils-$BINUTILS_VERSION.tar.gz" ]]; then
    echo "Fetching binutils from" "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz"
    curl -sSL "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz" -o "$DOWNLOAD_CACHE/binutils-$BINUTILS_VERSION.tar.gz"
fi

if [[ ! -f "$DOWNLOAD_CACHE/gcc-$GCC_VERSION.tar.gz" ]]; then
    echo "Fetching gcc from" "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz"
    curl -sSL "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz" -o "$DOWNLOAD_CACHE/gcc-$GCC_VERSION.tar.gz"
fi

if [[ ! -f "$DOWNLOAD_CACHE/gmp-$GMP_VERSION.tar.gz" ]]; then
    echo "Fetching gmp from" "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.gz"
    curl -sSL "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.gz" -o "$DOWNLOAD_CACHE/gmp-$GMP_VERSION.tar.gz"
fi

if [[ ! -f "$DOWNLOAD_CACHE/mpfr-$MPFR_VERSION.tar.gz" ]]; then
    echo "Fetching mpfr from" "https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_VERSION.tar.gz"
    curl -sSL "https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_VERSION.tar.gz" -o "$DOWNLOAD_CACHE/mpfr-$MPFR_VERSION.tar.gz"
fi

if [[ ! -f "$DOWNLOAD_CACHE/mpc-$MPC_VERSION.tar.xz" ]]; then
    echo "Fetching mpc from" "https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VERSION.tar.xz"
    curl -sSL "https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VERSION.tar.xz" -o "$DOWNLOAD_CACHE/mpc-$MPC_VERSION.tar.xz"
fi

if [[ ! -f "$DOWNLOAD_CACHE/busybox-$BUSYBOX_VERSION.tar.gz" ]]; then
    echo "Fetching busybox from" "https://github.com/vda-linux/busybox_mirror/archive/refs/tags/$BUSYBOX_VERSION.tar.gz"
    curl -ssL "https://github.com/vda-linux/busybox_mirror/archive/refs/tags/$BUSYBOX_VERSION.tar.gz" -o "$DOWNLOAD_CACHE/busybox-$BUSYBOX_VERSION.tar.gz"
fi

echo "All dependencies downloaded"


echo "Extracting $DOWNLOAD_CACHE/musl-$MUSL_VERSION.tar.gz"
tar -xf "$DOWNLOAD_CACHE/musl-$MUSL_VERSION.tar.gz" -C "$WORK_DIR" &&  mv "$WORK_DIR/musl"* "$WORK_DIR/musl-src"

echo "Extracting $DOWNLOAD_CACHE/binutils-$BINUTILS_VERSION.tar.gz"
tar -xf "$DOWNLOAD_CACHE/binutils-$BINUTILS_VERSION.tar.gz" -C "$WORK_DIR" && mv "$WORK_DIR/binutils"* "$WORK_DIR/binutils-src"

echo "Extracting $DOWNLOAD_CACHE/gcc-$GCC_VERSION.tar.gz"
tar -xf "$DOWNLOAD_CACHE/gcc-$GCC_VERSION.tar.gz" -C "$WORK_DIR" &&  mv "$WORK_DIR/gcc"* "$WORK_DIR/gcc-src"

echo "Extracting $DOWNLOAD_CACHE/busybox-$BUSYBOX_VERSION.tar.gz"
tar -xf "$DOWNLOAD_CACHE/busybox-$BUSYBOX_VERSION.tar.gz" -C "$WORK_DIR" && mv "$WORK_DIR/busybox"* "$WORK_DIR/busybox-src"


echo "Extracting $DOWNLOAD_CACHE/gmp-$GMP_VERSION.tar.gz"
tar -xf "$DOWNLOAD_CACHE/gmp-$GMP_VERSION.tar.gz" -C "$WORK_DIR" && mv "$WORK_DIR/gmp"* "$WORK_DIR/gcc-src/gmp"

echo "Extracting $DOWNLOAD_CACHE/mpfr-$MPFR_VERSION.tar.gz"
tar -xf "$DOWNLOAD_CACHE/mpfr-$MPFR_VERSION.tar.gz" -C "$WORK_DIR" && mv "$WORK_DIR/mpfr"* "$WORK_DIR/gcc-src/mpfr"

echo "Extracting $DOWNLOAD_CACHE/mpc-$MPC_VERSION.tar.xz"
tar -xf "$DOWNLOAD_CACHE/mpc-$MPC_VERSION.tar.xz" -C "$WORK_DIR" && mv "$WORK_DIR/mpc"* "$WORK_DIR/gcc-src/mpc"

echo "=== Pass 1: Building Cross Toolchain ==="

echo "=> musl"
cd "$WORK_DIR/musl-src"
./configure --prefix="$CROSS_DIR/$TARGET" --disable-shared
make -j"$(nproc)" && make install

mkdir -p "$CROSS_DIR/$TARGET/usr"
ln -sf "../include" "$CROSS_DIR/$TARGET/usr/include"
ln -sf "../lib" "$CROSS_DIR/$TARGET/usr/lib"

echo "=> binutils"
mkdir -p "$WORK_DIR/binutils-cross" && cd "$WORK_DIR/binutils-cross"
../binutils-src/configure \
    --prefix="$CROSS_DIR" \
    --target="$TARGET" \
    --with-sysroot="$CROSS_DIR/$TARGET" \
    --disable-nls \
    --disable-werror

make -j"$(nproc)" && make install

echo "=> gcc"
mkdir -p "$WORK_DIR/gcc-cross" && cd "$WORK_DIR/gcc-cross"

CFLAGS="-Wno-format-security -Wno-error=format-security" \
CXXFLAGS="-Wno-format-security -Wno-error=format-security" \
../gcc-src/configure \
    --prefix="$CROSS_DIR" \
    --target="$TARGET" \
    --with-sysroot="$CROSS_DIR/$TARGET" \
    --disable-bootstrap \
    --disable-multilib \
    --disable-shared \
    --disable-nls \
    --disable-libsanitizer \
    --disable-werror \
    --enable-languages=c,c++

make -j"$(nproc)" && make install

echo "=== Pass 2: Building Target Toolchain ==="

export PATH="$CROSS_DIR/bin:$PATH"
export CC="$TARGET-gcc"
export CXX="$TARGET-g++"
export AR="$TARGET-ar"
export RANLIB="$TARGET-ranlib"

echo "=> musl"

cd "$WORK_DIR/musl-src"
make clean
./configure --prefix="$SEED_SYSROOT" --disable-shared --enable-static
make -j"$(nproc)" && make install

echo "=> binutils"

mkdir -p "$WORK_DIR/binutils-target" && cd "$WORK_DIR/binutils-target"
../binutils-src/configure \
    --host="$TARGET" \
    --target="$TARGET" \
    --enable-targets=x86_64-linux-musl,i686-linux-musl \
    --prefix="" \
    --disable-nls \
    --disable-shared \
    --enable-static \
    LDFLAGS="-static"
make -j"$(nproc)" && make install DESTDIR="$SEED_SYSROOT"

echo "=> gcc"

mkdir -p "$WORK_DIR/gcc-target" && cd "$WORK_DIR/gcc-target"

CFLAGS="-Wno-format-security -Wno-error=format-security" \
CXXFLAGS="-Wno-format-security -Wno-error=format-security" \
../gcc-src/configure \
    --host="$TARGET" \
    --target="$TARGET" \
    --prefix="" \
    --with-native-system-header-dir="/include" \
    --disable-bootstrap \
    --enable-multilib \
    --disable-shared \
    --enable-static \
    --disable-nls \
    --disable-libsanitizer \
    --enable-languages=c,c++ \
    LDFLAGS="-static"

make -j"$(nproc)" && make install DESTDIR="$SEED_SYSROOT"

ln -sf gcc "$SEED_SYSROOT/bin/cc"

echo "=> busybox"

cd "$WORK_DIR/busybox-src"
make defconfig

sed -i 's/.*CONFIG_STATIC.*/CONFIG_STATIC=y/' .config
sed -i 's/.*CONFIG_STATIC_LIBGCC.*/CONFIG_STATIC_LIBGCC=y/' .config

sed -i 's/.*CONFIG_TC.*/CONFIG_TC=n/' .config
sed -i 's/.*CONFIG_FEATURE_TC_INGRESS.*/CONFIG_FEATURE_TC_INGRESS=n/' .config

sed -i 's/.*CONFIG_NETSTAT.*/CONFIG_NETSTAT=n/' .config
sed -i 's/.*CONFIG_FEATURE_IPV6.*/CONFIG_FEATURE_IPV6=n/' .config
sed -i 's/.*CONFIG_NETWORKING.*/CONFIG_NETWORKING=n/' .config
sed -i 's/.*CONFIG_CONSOLEUTILS.*/CONFIG_CONSOLEUTILS=n/' .config

sed -i 's/.*CONFIG_MODUTILS.*/CONFIG_MODUTILS=n/' .config
sed -i 's/.*CONFIG_INIT.*/CONFIG_INIT=n/' .config
sed -i 's/.*CONFIG_LOGINUTILS.*/CONFIG_LOGINUTILS=n/' .config
sed -i 's/.*CONFIG_SELINUX.*/CONFIG_SELINUX=n/' .config
sed -i 's/.*CONFIG_HDPARM.*/CONFIG_HDPARM=n/' .config
sed -i 's/.*CONFIG_DEVMEM.*/CONFIG_DEVMEM=n/' .config

make olddefconfig

make -j"$(nproc)" \
    CC="$TARGET-gcc" \
    AR="$TARGET-ar" \
    RANLIB="$TARGET-ranlib" \
    LDFLAGS="-static" \
    EXTRA_CFLAGS="-static"

make install CONFIG_PREFIX="$SEED_SYSROOT"

echo "=== Phase 3: Packaging ==="

cd "$SEED_SYSROOT"

echo "=> Busybox symlinks"

ln -sf busybox bin/sh
ln -sf busybox bin/bash

echo "=> Strip debug symbols"
# Strip target binaries using our cross-strip tool to save ~150MB+ space
"$TARGET-strip" --strip-unneeded bin/* 2>/dev/null || true
"$TARGET-strip" --strip-unneeded libexec/gcc/$TARGET/*/* 2>/dev/null || true

echo "=> Create store manifest and directory structure"

mkdir -p lib include

if [ -d "usr/lib32" ]; then
    mkdir -p lib32
    cp -rn usr/lib32/* lib32/ 2>/dev/null || true
    rm -rf usr/lib32
fi

if [ -d "usr/lib/32" ]; then
    mkdir -p lib/32
    cp -rn usr/lib/32/* lib/32/ 2>/dev/null || true
    rm -rf usr/lib/32
fi

[ -d "usr/include" ] && cp -rn usr/include/* include/ 2>/dev/null || true
[ -d "usr/lib" ]     && cp -rn usr/lib/* lib/ 2>/dev/null || true
[ -d "usr/bin" ]     && cp -rn usr/bin/* bin/ 2>/dev/null || true
[ -d "usr/sbin" ]    && cp -rn usr/sbin/* bin/ 2>/dev/null || true
[ -d "sbin" ]        && cp -rn sbin/* bin/ 2>/dev/null || true

# 2. Wipe the old directories completely
rm -rf sbin usr

# 3. Recreate /usr as a clean directory
mkdir -p usr

# 4. Create relative symlinks safely
ln -sf bin sbin
ln -sf ../bin usr/bin
ln -sf ../bin usr/sbin
ln -sf ../include usr/include
ln -sf ../lib usr/lib


if [ -d "x86_64-linux-musl" ]; then
    [ -d "x86_64-linux-musl/include" ] && cp -rn x86_64-linux-musl/include/* include/ 2>/dev/null || true
    [ -d "x86_64-linux-musl/lib" ] && cp -rn x86_64-linux-musl/lib/* lib/ 2>/dev/null || true
    rm -rf x86_64-linux-musl
fi

if [ -d "lib32" ]; then
    ln -sf ../lib32 usr/lib32
elif [ -d "lib/32" ]; then
    mkdir -p usr/lib
    ln -sf ../../lib/32 usr/lib/32
fi

rm -f linuxrc
rm -rf share


tar --owner=0 --group=0 -czf "$OUT_DIR/bootstrap.tar.gz" -C "$SEED_SYSROOT" .

echo "== Done: output is at $OUT_DIR/bootstrap.tar.gz ==="