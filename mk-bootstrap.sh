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
MUSL_SIGNATURE="e9db8b70b0cba3db43b27e84ccd8a0c0958b40029a1c36c9f13817b93787b4d6"

# Download https://ftp.gnu.org/gnu/binutils/binutils-{ver}.tar.gz to ./src-tar/binutils-{ver}.tar.gz
BINUTILS_VERSION="2.47"
BINUTILS_SIGNATURE="e9db8b70b0cba3db43b27e84ccd8a0c0958b40029a1c36c9f13817b93787b4d6"

# Download https://ftp.gnu.org/gnu/gcc/gcc-{ver}/gcc-{ver}.tar.gz to ./tars/gcc-{ver}.tar.gz
GCC_VERSION="16.2.0"
GCC_SIGNATURE="071d00a097579e5ef7ce97fc4a9e58e73fd3503c0a013c765c970370a5a53b9b"

# Download https://ftp.gnu.org/gnu/gmp/gmp-{ver}.tar.gz to ./tars/gcc-{ver}.tar.gz
GMP_VERSION="6.3.0"
GMP_SIGNATURE="e56fd59d76810932a0555aa15a14b61c16bed66110d3c75cc2ac49ddaa9ab24c"

# Download https://ftp.gnu.org/gnu/mpfr/mpfr-{ver}.tar.gz to ./tars/mpfr-{ver}.tar.gz
MPFR_VERSION="4.2.2"
MPFR_SIGNATURE="826cbb24610bd193f36fde172233fb8c009f3f5c2ad99f644d0dea2e16a20e42"

# Download https://ftp.gnu.org/gnu/mpc/mpc-{ver}.tar.xz to ./tars/mpc-{ver}.tar.xz
MPC_VERSION="1.4.1"
MPC_SIGNATURE="826cbb24610bd193f36fde172233fb8c009f3f5c2ad99f644d0dea2e16a20e42"

# Download https://github.com/vda-linux/busybox_mirror/archive/refs/tags/{ver}.tar.gz to ./src-tar/musl-{ver}.tar.gz
BUSYBOX_VERSION="1_36_1"
BUSYBOX_SIGNATURE="d4955247949cfe8eaa5e2d677fd25efdc22d537830a9db8316940f0860517d06"

DOWNLOAD_CACHE=$(pwd)/.tars
WORK_DIR=$(pwd)/.build
CROSS_DIR=$(pwd)/cross-toolchain
OUT_DIR=$(pwd)/dist
LOG_DIR=$(pwd)/logs
SEED_SYSROOT="$WORK_DIR/sysroot"
TARGET="x86_64-linux-musl"

START_STEP="${1:-setup}"
FORMAT="${2:-xz}"

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

run_step() {
    local step_name="$1"
    local log_file="$LOG_DIR/${step_name}.log"
    shift 1
    echo "=> Building ${step_name}..."

    set +e
    (
        set -e
        "$@"
    ) &> "$log_file"
    local status=$?
    set -e

    if [ $status -eq 0 ]; then
        echo "=> ${step_name} built successfully."
    else
        echo "=> ERROR: ${step_name} build failed!"
        echo "=> Last 20 lines of ${log_file}:"
        tail -n 20 "$log_file"
        exit 1
    fi
}

build_musl_cross()
{
    cd "$WORK_DIR/musl-src"
    rm -f config.mak && make clean

    ./configure --prefix="$CROSS_DIR/$TARGET" --libdir="$CROSS_DIR/$TARGET/lib" --disable-shared
    make -j"$(nproc)" && make install

    mkdir -p "$CROSS_DIR/$TARGET/usr"
    ln -sf "../include" "$CROSS_DIR/$TARGET/usr/include"
    ln -sf "../lib" "$CROSS_DIR/$TARGET/usr/lib"
}

build_binutils_cross()
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
}

build_gcc_cross()
{

    mkdir -p "$WORK_DIR/gcc-cross" && cd "$WORK_DIR/gcc-cross"

    clean
    
    export PATH="$CROSS_DIR/bin:$CROSS_DIR/$TARGET/bin:$PATH"

    CFLAGS="-O2 -Wno-format-security -Wno-error=format-security" \
    CXXFLAGS="-O2 -Wno-format-security -Wno-error=format-security" \
    ../gcc-src/configure \
        --prefix="$CROSS_DIR" \
        --target="$TARGET" \
        --with-sysroot="$CROSS_DIR/$TARGET" \
        --with-ld="$CROSS_DIR/bin/$TARGET-ld" \
        --with-as="$CROSS_DIR/bin/$TARGET-as" \
        --disable-bootstrap \
        --disable-multilib \
        --disable-shared \
        --disable-nls \
        --disable-libsanitizer \
        --disable-werror \
        --enable-languages=c,c++

    make -j"$(nproc)" && make install
}

build_musl_target()
{
    pass2

    cd "$WORK_DIR/musl-src"
    
    rm -f config.mak && make clean
    ./configure --prefix="$SEED_SYSROOT" --libdir="$SEED_SYSROOT/lib" --disable-shared --enable-static
    make -j"$(nproc)" && make install

    
    cp -a "$SEED_SYSROOT/include/"* "$CROSS_DIR/$TARGET/include/"
    cp -a "$SEED_SYSROOT/lib/"* "$CROSS_DIR/$TARGET/lib/"

    for lib in libm libpthread librt libdl libcrypt libresolv libutil; do
        ln -sf libc.a "$SEED_SYSROOT/lib/${lib}.a" 2>/dev/null || true
        ln -sf libc.a "$CROSS_DIR/$TARGET/lib/${lib}.a" 2>/dev/null || true
    done
}

build_binutils_target()
{
    pass2

    mkdir -p "$WORK_DIR/binutils-target" && cd "$WORK_DIR/binutils-target"

    clean

    export EXTRA_SIZE_CFLAGS="-Os -fdata-sections -ffunction-sections -fno-unwind-tables -fno-asynchronous-unwind-tables"
    export EXTRA_SIZE_LDFLAGS="-Wl,--gc-sections"
    ../binutils-src/configure \
        --host="$TARGET" \
        --target="$TARGET" \
        --prefix="" \
        --bindir="/bin" \
        --libdir="/lib" \
        --enable-targets=x86_64-linux-musl,i686-linux-musl \
        --disable-gprof \
        --disable-readline \
        --disable-sim \
        --disable-nls \
        --disable-nls \
        --disable-werror \
        --disable-shared \
        --enable-static \
        --disable-gdb \
        LDFLAGS="-static"
    
    make -j"$(nproc)" \
        CC="$TARGET-gcc -B$CROSS_DIR/bin -B$CROSS_DIR/$TARGET/bin" \
        AR="$TARGET-ar" \
        RANLIB="$TARGET-ranlib" \
        LDFLAGS="-static" \
        EXTRA_CFLAGS="-static"

    make install DESTDIR="$SEED_SYSROOT"
}

build_gcc_target()
{
    pass2

    mkdir -p "$WORK_DIR/gcc-target" && cd "$WORK_DIR/gcc-target"

    clean

    export EXTRA_SIZE_CFLAGS="-Os -fdata-sections -ffunction-sections -fno-unwind-tables -fno-asynchronous-unwind-tables"
    export EXTRA_SIZE_LDFLAGS="-Wl,--gc-sections"
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
        --with-build-sysroot="$SEED_SYSROOT" \
        --with-native-system-header-dir="/include" \
        --with-gxx-include-dir="/include/c++" \
        --disable-bootstrap \
        --disable-multilib \
        --disable-shared \
        --enable-static \
        --disable-nls \
        --disable-libsanitizer \
        --enable-languages=c,c++ \
        --disable-fixincludes \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libvtv \
        --disable-plugin \
        --disable-lto \
        --disable-decimal-float \
        LDFLAGS="-static"

    make -j"$(nproc)" \
        CC="$TARGET-gcc -B$CROSS_DIR/bin -B$CROSS_DIR/$TARGET/bin" \
        AR="$TARGET-ar" \
        RANLIB="$TARGET-ranlib" \
        EXTRA_CFLAGS="-static"
    
    make install DESTDIR="$SEED_SYSROOT"

    ln -sf gcc "$SEED_SYSROOT/bin/cc"
}

build_busybox_target()
{
    pass2

    cd "$WORK_DIR/busybox-src"

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

    # Shell math support ($(()))
    enable_opt "CONFIG_FEATURE_SH_MATH"
    enable_opt "CONFIG_FEATURE_SH_MATH_64"

    # Core configurations
    enable_opt "CONFIG_LONG_OPTS"
    enable_opt "CONFIG_SHOW_USAGE"

    # Core POSIX Utilities
    enable_opt "CONFIG_BASENAME"
    enable_opt "CONFIG_CAT"
    enable_opt "CONFIG_CHMOD"
    enable_opt "CONFIG_COMM"
    enable_opt "CONFIG_CP"
    enable_opt "CONFIG_DATE"
    enable_opt "CONFIG_DD"
    enable_opt "CONFIG_DF"
    enable_opt "CONFIG_DIRNAME"
    enable_opt "CONFIG_DU"
    enable_opt "CONFIG_ECHO"
    enable_opt "CONFIG_ENV"
    enable_opt "CONFIG_EXPR"
    enable_opt "CONFIG_EXPR_MATH_SUPPORT_64"
    enable_opt "CONFIG_ID"
    enable_opt "CONFIG_INSTALL"
    enable_opt "CONFIG_LN"
    enable_opt "CONFIG_LS"
    enable_opt "CONFIG_MKDIR"
    enable_opt "CONFIG_MV"
    enable_opt "CONFIG_NL"
    enable_opt "CONFIG_NPROC"
    enable_opt "CONFIG_OD"
    enable_opt "CONFIG_PASTE"
    enable_opt "CONFIG_PRINTENV"
    enable_opt "CONFIG_PRINTF"
    enable_opt "CONFIG_PWD"
    enable_opt "CONFIG_READLINK"
    enable_opt "CONFIG_REALPATH"
    enable_opt "CONFIG_RM"
    enable_opt "CONFIG_SEQ"
    enable_opt "CONFIG_SLEEP"
    enable_opt "CONFIG_SPLIT"
    enable_opt "CONFIG_STAT"
    enable_opt "CONFIG_TAC"
    enable_opt "CONFIG_TEE"
    enable_opt "CONFIG_TEST"
    enable_opt "CONFIG_TEST1"
    enable_opt "CONFIG_TEST2"
    enable_opt "CONFIG_TOUCH"
    enable_opt "CONFIG_TRUNCATE"
    enable_opt "CONFIG_TRUE"
    enable_opt "CONFIG_FALSE"
    enable_opt "CONFIG_UNAME"
    enable_opt "CONFIG_WHOAMI"
    enable_opt "CONFIG_YES"
    enable_opt "CONFIG_WC"
    enable_opt "CONFIG_XARGS"

    # Text Manipulation & Editing
    enable_opt "CONFIG_AWK"
    enable_opt "CONFIG_CMP"
    enable_opt "CONFIG_CUT"
    enable_opt "CONFIG_DIFF"
    enable_opt "CONFIG_FIND"
    enable_opt "CONFIG_GREP"
    enable_opt "CONFIG_EGREP"
    enable_opt "CONFIG_FGREP"
    enable_opt "CONFIG_HEAD"
    enable_opt "CONFIG_SED"
    enable_opt "CONFIG_SORT"
    enable_opt "CONFIG_STRINGS"
    enable_opt "CONFIG_TAIL"
    enable_opt "CONFIG_TR"
    enable_opt "CONFIG_UNIQ"

    # LS Features
    enable_opt "CONFIG_FEATURE_LS_FILETYPES"
    enable_opt "CONFIG_FEATURE_LS_FOLLOWLINKS"
    enable_opt "CONFIG_FEATURE_LS_RECURSIVE"
    enable_opt "CONFIG_FEATURE_LS_SORTFILES"
    enable_opt "CONFIG_FEATURE_LS_TIMESTAMPS"
    enable_opt "CONFIG_FEATURE_LS_USERNAME"
    enable_opt "CONFIG_FEATURE_LS_COLOR"

    # Core Utility Features
    enable_opt "CONFIG_FEATURE_DD_SIGNAL_HANDLING"
    enable_opt "CONFIG_FEATURE_DD_IBS_OBS"
    enable_opt "CONFIG_FEATURE_DD_STATUS"
    enable_opt "CONFIG_FEATURE_FANCY_ECHO"
    enable_opt "CONFIG_FEATURE_PRESERVE_HARDLINKS"
    enable_opt "CONFIG_FEATURE_VERBOSE"
    enable_opt "CONFIG_FEATURE_HUMAN_READABLE"
    enable_opt "CONFIG_FEATURE_TEST_64"
    enable_opt "CONFIG_FEATURE_WC_LARGE"
    enable_opt "CONFIG_FEATURE_DATE_ISOFMT"
    enable_opt "CONFIG_FEATURE_DF_FANCY"
    enable_opt "CONFIG_FEATURE_SKIP_ROOTFS"
    enable_opt "CONFIG_FEATURE_DU_DEFAULT_BLOCKSIZE_1K"
    enable_opt "CONFIG_FEATURE_READLINK_FOLLOW"
    enable_opt "CONFIG_FEATURE_FANCY_SLEEP"
    enable_opt "CONFIG_FEATURE_SPLIT_FANCY"
    enable_opt "CONFIG_FEATURE_STAT_FORMAT"
    enable_opt "CONFIG_FEATURE_STAT_FILESYSTEM"
    enable_opt "CONFIG_FEATURE_TEE_USE_BLOCK_IO"
    enable_opt "CONFIG_FEATURE_TOUCH_SUSV3"
    enable_opt "CONFIG_FEATURE_CATN"
    enable_opt "CONFIG_FEATURE_CATV"
    enable_opt "CONFIG_FEATURE_NON_POSIX_CP"
    enable_opt "CONFIG_FEATURE_VERBOSE_CP_MESSAGE"
    enable_opt "CONFIG_FEATURE_CP_LONG_OPTIONS"
    enable_opt "CONFIG_FEATURE_INSTALL_LONG_OPTIONS"

    # XARGS Features
    enable_opt "CONFIG_FEATURE_XARGS_SUPPORT_CONFIRMATION"
    enable_opt "CONFIG_FEATURE_XARGS_SUPPORT_QUOTES"
    enable_opt "CONFIG_FEATURE_XARGS_SUPPORT_TERMOPT"
    enable_opt "CONFIG_FEATURE_XARGS_SUPPORT_ZERO_TERM"
    enable_opt "CONFIG_FEATURE_XARGS_SUPPORT_REPL_STR"
    enable_opt "CONFIG_FEATURE_XARGS_SUPPORT_PARALLEL"
    enable_opt "CONFIG_FEATURE_XARGS_SUPPORT_ARGS_FILE"

    # Text Processing Features
    enable_opt "CONFIG_FEATURE_GREP_CONTEXT"
    enable_opt "CONFIG_FEATURE_FANCY_HEAD"
    enable_opt "CONFIG_FEATURE_FANCY_TAIL"
    enable_opt "CONFIG_FEATURE_SORT_BIG"
    enable_opt "CONFIG_FEATURE_TR_CLASSES"
    enable_opt "CONFIG_FEATURE_TR_EQUIV"
    enable_opt "CONFIG_FEATURE_CUT_REGEX"
    enable_opt "CONFIG_FEATURE_AWK_GNU_EXTENSIONS"
    enable_opt "CONFIG_FEATURE_DIFF_LONG_OPTIONS"
    enable_opt "CONFIG_FEATURE_SORT_OPTIMIZE_MEMORY"

    # FIND Features
    enable_opt "CONFIG_FEATURE_FIND_TYPE"
    enable_opt "CONFIG_FEATURE_FIND_PERM"
    enable_opt "CONFIG_FEATURE_FIND_MTIME"
    enable_opt "CONFIG_FEATURE_FIND_ATIME"
    enable_opt "CONFIG_FEATURE_FIND_CTIME"
    enable_opt "CONFIG_FEATURE_FIND_MMIN"
    enable_opt "CONFIG_FEATURE_FIND_AMIN"
    enable_opt "CONFIG_FEATURE_FIND_CMIN"
    enable_opt "CONFIG_FEATURE_FIND_EXEC"
    enable_opt "CONFIG_FEATURE_FIND_EXEC_PLUS"
    enable_opt "CONFIG_FEATURE_FIND_MAXDEPTH"
    enable_opt "CONFIG_FEATURE_FIND_PRINT0"
    enable_opt "CONFIG_FEATURE_FIND_DEPTH"
    enable_opt "CONFIG_FEATURE_FIND_SIZE"
    enable_opt "CONFIG_FEATURE_FIND_NOT"
    enable_opt "CONFIG_FEATURE_FIND_PAREN"
    enable_opt "CONFIG_FEATURE_FIND_NEWER"
    enable_opt "CONFIG_FEATURE_FIND_EXECUTABLE"
    enable_opt "CONFIG_FEATURE_FIND_XDEV"
    enable_opt "CONFIG_FEATURE_FIND_INUM"
    enable_opt "CONFIG_FEATURE_FIND_SAMEFILE"
    enable_opt "CONFIG_FEATURE_FIND_USER"
    enable_opt "CONFIG_FEATURE_FIND_GROUP"
    enable_opt "CONFIG_FEATURE_FIND_PRUNE"
    enable_opt "CONFIG_FEATURE_FIND_QUIT"
    enable_opt "CONFIG_FEATURE_FIND_DELETE"
    enable_opt "CONFIG_FEATURE_FIND_EMPTY"
    enable_opt "CONFIG_FEATURE_FIND_PATH"
    enable_opt "CONFIG_FEATURE_FIND_REGEX"
    enable_opt "CONFIG_FEATURE_FIND_LINKS"

    # System & Networking
    enable_opt "CONFIG_GETOPT"
    enable_opt "CONFIG_FEATURE_GETOPT_LONG"
    enable_opt "CONFIG_GROUPS"
    enable_opt "CONFIG_HOSTNAME"
    enable_opt "CONFIG_KILL"

    # Archiving & Compression
    enable_opt "CONFIG_TAR"
    enable_opt "CONFIG_GZIP"
    enable_opt "CONFIG_GUNZIP"
    enable_opt "CONFIG_BZIP2"
    enable_opt "CONFIG_BUNZIP2"
    enable_opt "CONFIG_XZ"
    enable_opt "CONFIG_UNXZ"
    enable_opt "CONFIG_PATCH"

    # TAR Features
    enable_opt "CONFIG_FEATURE_TAR_CREATE"
    enable_opt "CONFIG_FEATURE_TAR_FROM"
    enable_opt "CONFIG_FEATURE_TAR_AUTODETECT"
    enable_opt "CONFIG_FEATURE_TAR_LONG_OPTIONS"
    enable_opt "CONFIG_FEATURE_TAR_GNU_EXTENSIONS"
    enable_opt "CONFIG_FEATURE_TAR_OLDGNU_COMPATIBILITY"
    enable_opt "CONFIG_FEATURE_TAR_UNAME_GNAME"
    enable_opt "CONFIG_FEATURE_TAR_NOPRESERVE_TIME"
    enable_opt "CONFIG_FEATURE_TAR_TO_COMMAND"
    enable_opt "CONFIG_FEATURE_SEAMLESS_XZ"
    enable_opt "CONFIG_FEATURE_SEAMLESS_GZ"
    enable_opt "CONFIG_FEATURE_SEAMLESS_BZ2"
    enable_opt "CONFIG_FEATURE_SEAMLESS_LZMA"
    enable_opt "CONFIG_FEATURE_SEAMLESS_Z"
    
    # Enable native size optimization toggles
    enable_opt "CONFIG_OPTIMIZE_FOR_SIZE"
    enable_opt "CONFIG_GC_SECTIONS"

    SIZE_CFLAGS="-Os -fdata-sections -ffunction-sections -fno-unwind-tables -fno-asynchronous-unwind-tables"
    sed -i "s|CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS=\"-static -I$SEED_SYSROOT/include $SIZE_CFLAGS\"|" .config
    sed -i "s|CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS=\"-static -L$SEED_SYSROOT/lib -B$CROSS_DIR/bin\"|" .config


    make prepare
    
    [ -f "$SEED_SYSROOT/lib/libm.a" ] || ln -sf libc.a "$SEED_SYSROOT/lib/libm.a"
    [ -f "$CROSS_DIR/$TARGET/lib/libm.a" ] || ln -sf libc.a "$CROSS_DIR/$TARGET/lib/libm.a"

    make -j"$(nproc)" \
        CC="$TARGET-gcc -B$CROSS_DIR/bin -B$CROSS_DIR/$TARGET/bin" \
        AR="$TARGET-ar" \
        RANLIB="$TARGET-ranlib" \
        CONFIG_EXTRA_CFLAGS="-static -I$SEED_SYSROOT/include -I$CROSS_DIR/$TARGET/include" \
        CONFIG_EXTRA_LDFLAGS="-static -L$SEED_SYSROOT/lib -L$CROSS_DIR/$TARGET/lib -B$CROSS_DIR/bin -B$CROSS_DIR/$TARGET/bin"

    make install CONFIG_PREFIX="$SEED_SYSROOT"
}

echo "=> Starting build pipeline at step: ${START_STEP}"
case "$START_STEP" in
    "setup")
        echo "=> [setup] fetching dependencies and cleaning"
        rm -rf $WORK_DIR $OUT_DIR $CROSS_DIR
        mkdir -p "$DOWNLOAD_CACHE" "$WORK_DIR" "$OUT_DIR" "$SEED_SYSROOT/bin" "$SEED_SYSROOT/usr/include"

        fetch()
        {
            local url = "$1"
            local output = "$2"
            local signature = "$3"
            if [[ ! -f "$output" ]]; then
                echo "Fetching $output from $url"
                curl -fsSL "$url" -o "$output"
                local test_signature = "$(sha256sum "$output" | cut -wf1)"
                if [ ! "$test_signature" -eq "$signature" ]; then
                    rm $output
                    echo "Signature fail"
                    echo "Got: $test_signature"
                    echo "Expected: $signature"
                    exit 1
                fi 
            fi
        }

        fetch "https://github.com/kraj/musl/archive/refs/tags/v$MUSL_VERSION.tar.gz" "$DOWNLOAD_CACHE/musl-$MUSL_VERSION.tar.gz" "$MUSL_SIGNATURE"
        fetch "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz" "$DOWNLOAD_CACHE/binutils-$BINUTILS_VERSION.tar.gz" "$BINUTILS_SIGNATURE"
        fetch "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz" "$DOWNLOAD_CACHE/gcc-$GCC_VERSION.tar.gz" "$GCC_SIGNATURE"
        fetch "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.gz" "$DOWNLOAD_CACHE/gmp-$GMP_VERSION.tar.gz" "$GMP_SIGNATURE"
        fetch "https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_VERSION.tar.gz" "$DOWNLOAD_CACHE/mpfr-$MPFR_VERSION.tar.gz" "$MPFR_SIGNATURE"
        fetch "https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VERSION.tar.xz" "$DOWNLOAD_CACHE/mpc-$MPC_VERSION.tar.xz" "$MPC_SIGNATURE"
        fetch "https://github.com/vda-linux/busybox_mirror/archive/refs/tags/$BUSYBOX_VERSION.tar.gz" "$DOWNLOAD_CACHE/busybox-$BUSYBOX_VERSION.tar.gz" "$BUSYBOX_SIGNATURE"

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
        run_step "musl-cross" build_musl_cross
        ;&

    "binutils-cross")
        run_step "binutils-cross" build_binutils_cross
        ;&

    "gcc-cross")
        run_step "gcc-cross" build_gcc_cross
        ;&
    
    "musl-target")
        run_step "musl-target" build_musl_target
        ;&

    "binutils-target")
        run_step "binutils-target" build_binutils_target
        ;&

    "gcc-target")
        run_step "gcc-target" build_gcc_target
        ;&

    "busybox-target")
        run_step "busybox-target" build_busybox_target
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

        # Fix broken symlinks due to our merging
        for link in bin/*; do
            if [ -L "$link" ] && [ ! -e "$link" ]; then
                ln -sf busybox "$link";
            fi
        done

        rm -f linuxrc
        rm -rf share

        case "$FORMAT" in
            "xz")
                tar -I 'xz -9e --threads=0' -cf "$OUT_DIR/bootstrap.tar.xz" -C "$SEED_SYSROOT" .
                echo "== Done: output is at $OUT_DIR/bootstrap.tar.xz ==="
                ;;
            "gz")
                tar --owner=0 --group=0 -czf "$OUT_DIR/bootstrap.tar.gz" -C "$SEED_SYSROOT" .
                echo "== Done: output is at $OUT_DIR/bootstrap.tar.gz ==="
                ;;
        esac
esac
