#!/usr/bin/env bash
[ -d "$ANDROID_HOME" ] || { echo "Error: ANDROID_HOME not found at: $ANDROID_HOME"; exit 1; }
echo "Android SDK: $ANDROID_HOME"

NDK_VERSION="27.2.12479018"
NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"

[ -d "$NDK_HOME" ] || { echo "Error: NDK version $NDK_VERSION not installed at: $NDK_HOME"; exit 1; }
echo "Android NDK: $NDK_HOME"

HOST="$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m)"
echo "Host system: $HOST"

TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/$HOST"

[ -d "$TOOLCHAIN" ] || { echo "Error: NDK toolchain not installed at: $TOOLCHAIN"; exit 1; }
echo "NDK toolchain: $TOOLCHAIN"

BUILD_DIR="$(pwd)/build"
echo "Build dir: $BUILD_DIR"
rm -r $BUILD_DIR

ABIS=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")
declare -A TARGETS=(
    ["armeabi-v7a"]="armv7a-linux-androideabi"
    ["arm64-v8a"]="aarch64-linux-android"
    ["x86"]="i686-linux-android"
    ["x86_64"]="x86_64-linux-android"
)

# not important since no Android APIs are used
API="21"

# https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md
DEFAULT_CFLAGS="--sysroot=$TOOLCHAIN/sysroot \
-DANDROID \
-fdata-sections \
-ffunction-sections \
-fstack-protector-strong \
-fPIC \
-no-canonical-prefixes \
-D_FORTIFY_SOURCE=2 \
-D__BIONIC_NO_PAGE_SIZE_MACRO \
-Wformat \
-Werror=format-security \
-g \
-DNDEBUG \
-O3 \
-ffast-math \
-funroll-loops \
-DFLOAT_APPROX"

DEFAULT_LDFLAGS="-Wl,--build-id=sha1 \
-Wl,--no-rosegment \
-Wl,--no-undefined \
-Wl,--no-undefined-version \
-Wl,--fatal-warnings \
-Qunused-arguments \
-Wl,--gc-sections"

declare -A ABI_CFLAGS=(
    ["armeabi-v7a"]="-march=armv7-a -mthumb"
    ["arm64-v8a"]=""
    ["x86"]="-mstackrealign"
    ["x86_64"]=""
)

declare -A ABI_LDFLAGS=(
    ["armeabi-v7a"]=""
    ["arm64-v8a"]="-Wl,-z,max-page-size=16384"
    ["x86"]=""
    ["x86_64"]="-Wl,-z,max-page-size=16384"
)

declare -A ABI_CONFIGURE_FLAGS=(
    ["armeabi-v7a"]=""
    ["arm64-v8a"]=""
    ["x86"]="--enable-x86-rtcd"
    ["x86_64"]="--enable-x86-rtcd"
)

for ABI in "${ABIS[@]}"; do
    TARGET="${TARGETS[$ABI]}"
    echo "Building ABI: $ABI -> $TARGET"

    CFLAGS="$DEFAULT_CFLAGS ${ABI_CFLAGS[$ABI]}"
    LDFLAGS="$DEFAULT_LDFLAGS ${ABI_LDFLAGS[$ABI]}"
    CONFIGURE_FLAGS="${ABI_CONFIGURE_FLAGS[$ABI]}"

    set -o xtrace
    make clean

    # https://developer.android.com/ndk/guides/other_build_systems
    ./configure \
        --host="$TARGET" \
        --prefix="$BUILD_DIR" \
        --exec-prefix="$BUILD_DIR/$ABI" \
        --enable-shared=yes \
        --enable-static=no \
        --disable-examples \
        --disable-doc \
        $CONFIGURE_FLAGS \
        CC="$TOOLCHAIN/bin/clang --target=$TARGET$API" \
        CXX="$TOOLCHAIN/bin/clang++ --target=$TARGET$API" \
        AS="$CC" \
        LD="$TOOLCHAIN/bin/ld" \
        AR="$TOOLCHAIN/bin/llvm-ar" \
        RANLIB="$TOOLCHAIN/bin/llvm-ranlib" \
        STRIP="$TOOLCHAIN/bin/llvm-strip" \
        CFLAGS="$CFLAGS" \
        LDFLAGS="$LDFLAGS" || { echo "Error: ./configure failed"; exit 1; }

    make V=1 || { echo "Error: make failed"; exit 1; }
    make install

    set +o xtrace
done
