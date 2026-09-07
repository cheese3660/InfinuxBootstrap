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
LOG_DIR=$(pwd)/logs
SEED_SYSROOT="$WORK_DIR/sysroot"
TARGET="x86_64-linux-musl"

START_STEP="${1:-setup}"

mkdir -p $LOG_DIR

clean() {
    make clean || true
}

pass2() {
    [ -v PASS2_SETUP ] && return
    export PATH="$CROSS_DIR/bin:$CROSS_DIR/$TARGET/bin:$PATH"
    export CC="$TARGET-gcc"
    export CXX="$TARGET-g++"
    export AR="$TARGET-ar"
    export RANLIB="$TARGET-ranlib"
    export LD="$TARGET-ld"
    export PASS2_SETUP="done"
}

echo "=> Starting build pipeline at step: ${START_STEP}"
case "$START_STEP" in
    "setup")
        echo "=> [setup] fetching dependencies and cleaning"
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

        ;&

    "musl-cross")
        echo "=> [1/7] Building musl-cross..."

        {
            cd "$WORK_DIR/musl-src"
            rm -f config.mak && make clean

            ./configure --prefix="$CROSS_DIR/$TARGET" --libdir="$CROSS_DIR/$TARGET/lib" --disable-shared
            make -j"$(nproc)" && make install

            mkdir -p "$CROSS_DIR/$TARGET/usr"
            ln -sf "../include" "$CROSS_DIR/$TARGET/usr/include"
            ln -sf "../lib" "$CROSS_DIR/$TARGET/usr/lib"
        } &> "$LOG_DIR/musl-cross.log"
        
        if [ $? -eq 0 ]; then
            echo "=> [1/7] musl-cross built successfully."
        else
            echo "=> ERROR: [1/7] musl-cross build failed!"
            echo "=> Last 20 lines of $LOG_DIR/musl-cross.log:"
            tail -n 20 "$LOG_DIR/musl-cross.log"
            exit 1
        fi

        ;&

    "binutils-cross")
        echo "=> [2/7] Building binutils-cross..."

        {
            mkdir -p "$WORK_DIR/binutils-cross" && cd "$WORK_DIR/binutils-cross"
            
            clean

            ../binutils-src/configure \
                --prefix="$CROSS_DIR" \
                --target="$TARGET" \
                --with-sysroot="$CROSS_DIR/$TARGET" \
                --disable-nls \
                --disable-werror

            make -j"$(nproc)" && make install
        } &> "$LOG_DIR/binutils-cross.log"
        
        if [ $? -eq 0 ]; then
            echo "=> [2/7] binutils-cross built successfully."
        else
            echo "=> ERROR: [2/7] binutils-cross build failed!"
            echo "=> Last 20 lines of $LOG_DIR/binutils-cross.log:"
            tail -n 20 "$LOG_DIR/binutils-cross.log"
            exit 1
        fi

        ;&

    "gcc-cross")
        echo "=> [3/7] Building gcc-cross..."

        {
            mkdir -p "$WORK_DIR/gcc-cross" && cd "$WORK_DIR/gcc-cross"

            clean

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
        } &> "$LOG_DIR/gcc-cross.log"
        
        if [ $? -eq 0 ]; then
            echo "=> [3/7] gcc-cross built successfully."
        else
            echo "=> ERROR: [3/7] gcc-cross build failed!"
            echo "=> Last 20 lines of $LOG_DIR/gcc-cross.log:"
            tail -n 20 "$LOG_DIR/gcc-cross.log"
            exit 1
        fi

        ;&
    
    "musl-target")
        echo "=> [4/7] Building musl-target..."

        pass2

        {
            cd "$WORK_DIR/musl-src"
            
            rm -f config.mak && make clean
            ./configure --prefix="$SEED_SYSROOT" --libdir="$SEED_SYSROOT/lib" --disable-shared --enable-static
            make -j"$(nproc)" && make install

        } &> "$LOG_DIR/musl-target.log"

        if [ $? -eq 0 ]; then
            echo "=> [4/7] musl-target built successfully."
        else
            echo "=> ERROR: [4/7] musl-target build failed!"
            echo "=> Last 20 lines of $LOG_DIR/musl-target.log:"
            tail -n 20 "$LOG_DIR/musl-target.log"
            exit 1
        fi

        ;&

    "binutils-target")
        echo "=> [5/7] Building binutils-target"

        pass2
        {
            mkdir -p "$WORK_DIR/binutils-target" && cd "$WORK_DIR/binutils-target"

            clean

            ../binutils-src/configure \
                --host="$TARGET" \
                --target="$TARGET" \
                --prefix="" \
                --bindir="/bin" \
                --libdir="/lib" \
                --enable-targets=x86_64-linux-musl,i686-linux-musl \
                --disable-nls \
                --disable-werror \
                --disable-shared \
                --enable-static \
                LDFLAGS="-static"
            
            make -j"$(nproc)" \
                CC="$TARGET-gcc -B$CROSS_DIR/bin -B$CROSS_DIR/$TARGET/bin" \
                AR="$TARGET-ar" \
                RANLIB="$TARGET-ranlib" \
                LDFLAGS="-static" \
                EXTRA_CFLAGS="-static"

            make install DESTDIR="$SEED_SYSROOT"
        } &> "$LOG_DIR/binutils-target.log" 
        if [ $? -eq 0 ]; then
            echo "=> [5/7] binutils-target built successfully."
        else
            echo "=> ERROR: [5/7] binutils-target build failed!"
            echo "=> Last 20 lines of $LOG_DIR/binutils-target.log:"
            tail -n 20 "$LOG_DIR/binutils-target.log"
            exit 1
        fi
        ;&

    "gcc-target")
        echo "=> [6/7] Building gcc-target"
        
        pass2
        {
            mkdir -p "$WORK_DIR/gcc-target" && cd "$WORK_DIR/gcc-target"

            clean

            CFLAGS="-Wno-format-security -Wno-error=format-security" \
            CXXFLAGS="-Wno-format-security -Wno-error=format-security" \
            ../gcc-src/configure \
                --host="$TARGET" \
                --target="$TARGET" \
                --prefix="" \
                --exec-prefix="" \
                --bindir="/bin" \
                --libdir="/lib" \
                --libexecdir="/libexec" \
                --with-native-system-header-dir="$SEED_SYSROOT/include" \
                --with-gxx-include-dir="/include/c++" \
                --disable-bootstrap \
                --disable-multilib \
                --disable-shared \
                --enable-static \
                --disable-nls \
                --disable-libsanitizer \
                --enable-languages=c,c++ \
                --disable-fixincludes \
                LDFLAGS="-static"

            make -j"$(nproc)" \
                CC="$TARGET-gcc -B$CROSS_DIR/bin -B$CROSS_DIR/$TARGET/bin" \
                AR="$TARGET-ar" \
                RANLIB="$TARGET-ranlib" \
                LDFLAGS="-static" \
                EXTRA_CFLAGS="-static"
            
            make install DESTDIR="$SEED_SYSROOT"

            ln -sf gcc "$SEED_SYSROOT/bin/cc"
        } &> "$LOG_DIR/gcc-target.log"
        
        if [ $? -eq 0 ]; then
            echo "=> [6/7] gcc-target built successfully."
        else
            echo "=> ERROR: [6/7] gcc-target build failed!"
            echo "=> Last 20 lines of $LOG_DIR/gcc-target.log:"
            tail -n 20 "$LOG_DIR/gcc-target.log"
            exit 1
        fi

        ;&

    "busybox-target")
        echo "=> [7/7] Building busybox-target"
        
        pass2

        cd "$WORK_DIR/busybox-src"
        {
            clean
            
            make allnoconfig

            enable_opt() {
                local opt="$1"
                if grep -q "^# $opt is not set" .config; then
                    sed -i "s/^# $opt is not set/$opt=y/" .config
                elif ! grep -q "^$opt=y" .config; then
                    echo "$opt=y" >> .config
                fi
            }

            # Enable static binary output
            enable_opt "CONFIG_STATIC"
            enable_opt "CONFIG_STATIC_LIBGCC"

            # Shell
            enable_opt "CONFIG_SHELL_ASH"
            enable_opt "CONFIG_ASH"
            enable_opt "CONFIG_SH_IS_ASH"
            enable_opt "CONFIG_BASH_IS_NONE"

            # Core POSIX Utilities
            enable_opt "CONFIG_CAT"
            enable_opt "CONFIG_CHMOD"
            enable_opt "CONFIG_CP"
            enable_opt "CONFIG_DD"
            enable_opt "CONFIG_ECHO"
            enable_opt "CONFIG_ENV"
            enable_opt "CONFIG_INSTALL"
            enable_opt "CONFIG_LN"
            enable_opt "CONFIG_LS"
            enable_opt "CONFIG_MKDIR"
            enable_opt "CONFIG_MV"
            enable_opt "CONFIG_RM"
            enable_opt "CONFIG_TOUCH"
            enable_opt "CONFIG_TEST"
            enable_opt "CONFIG_TRUE"
            enable_opt "CONFIG_FALSE"
            enable_opt "CONFIG_UNAME"
            enable_opt "CONFIG_WC"
            enable_opt "CONFIG_XARGS"

            # Text Manipulation & Editing
            enable_opt "CONFIG_AWK"
            enable_opt "CONFIG_CUT"
            enable_opt "CONFIG_GREP"
            enable_opt "CONFIG_EGREP"
            enable_opt "CONFIG_FGREP"
            enable_opt "CONFIG_HEAD"
            enable_opt "CONFIG_SED"
            enable_opt "CONFIG_SORT"
            enable_opt "CONFIG_TAIL"
            enable_opt "CONFIG_TR"
            enable_opt "CONFIG_UNIQ"

            # Archiving & Compression
            enable_opt "CONFIG_TAR"
            enable_opt "CONFIG_GZIP"
            enable_opt "CONFIG_GUNZIP"
            enable_opt "CONFIG_BZIP2"
            enable_opt "CONFIG_BUNZIP2"
            enable_opt "CONFIG_XZ"
            enable_opt "CONFIG_UNXZ"
            enable_opt "CONFIG_PATCH"

            # Resolve dependencies strictly without interactive prompts
            make prepare

            # { yes "" || true; } | make oldconfig
            
            make -j"$(nproc)" \
                CC="$TARGET-gcc -B$CROSS_DIR/bin -B$CROSS_DIR/$TARGET/bin" \
                AR="$TARGET-ar" \
                RANLIB="$TARGET-ranlib" \
                LDFLAGS="-static" \
                EXTRA_CFLAGS="-static"

            make install CONFIG_PREFIX="$SEED_SYSROOT"
        } &> "$LOG_DIR/busybox-target.log"
        if [ $? -eq 0 ]; then
            echo "=> [7/7] busybox-target built successfully."
        else
            echo "=> ERROR: [7/7] busybox-target build failed!"
            echo "=> Last 20 lines of $LOG_DIR/busybox-target.log:"
            tail -n 20 "$LOG_DIR/busybox-target.log"
            exit 1
        fi
        ;&

    "package")
        echo "=> [package] packaging"

        pass2

        cd "$SEED_SYSROOT"

        ln -sf busybox bin/sh
        ln -sf busybox bin/bash

        # Strip target binaries using our cross-strip tool to save ~150MB+ space
        "$TARGET-strip" --strip-unneeded bin/* 2>/dev/null || true
        "$TARGET-strip" --strip-unneeded libexec/gcc/$TARGET/*/* 2>/dev/null || true


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
esac
