#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build-ffmpeg"
FFMPEG_SRC="$BUILD_DIR/ffmpeg-8.0"
IOS_MIN_VERSION="16.0"

PYTHON_BIN="/usr/bin/python3"
if [ ! -x "$PYTHON_BIN" ]; then
    PYTHON_BIN="$(command -v python3)"
fi
"$PYTHON_BIN" "$SCRIPT_DIR/prepare-audio-vivid.py" "$FFMPEG_SRC"

# Function to build FFmpeg for a specific platform/arch
build_sim() {
    local ARCH=$1
    local PREFIX="$BUILD_DIR/output-iphonesimulator-${ARCH}"

    echo ">>> Building FFmpeg for iphonesimulator ${ARCH}..."

    local SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
    local CC=$(xcrun --sdk iphonesimulator --find clang)

    local EXTRA_CFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} -mios-simulator-version-min=${IOS_MIN_VERSION} -target ${ARCH}-apple-ios${IOS_MIN_VERSION}-simulator"
    local EXTRA_LDFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} -mios-simulator-version-min=${IOS_MIN_VERSION} -target ${ARCH}-apple-ios${IOS_MIN_VERSION}-simulator"

    cd "$FFMPEG_SRC"
    make clean 2>/dev/null || true
    rm -f libavcodec/audio_vivid/*.o

    ./configure \
        --prefix="$PREFIX" \
        --enable-cross-compile \
        --target-os=darwin \
        --arch=${ARCH} \
        --cc="$CC" \
        --sysroot="$SDK_PATH" \
        --extra-cflags="$EXTRA_CFLAGS" \
        --extra-ldflags="$EXTRA_LDFLAGS" \
        --enable-static \
        --disable-shared \
        --disable-programs \
        --disable-doc \
        --disable-debug \
        --disable-autodetect \
        --enable-securetransport \
        --enable-pic \
        --enable-small \
        --enable-swresample \
        --enable-swscale \
        --enable-avfilter \
        --enable-decoder=h264,hevc,av3a,aac,mp3,mp3float,pcm_s16le,pcm_f32le \
        --enable-demuxer=mov,mpegts,flv,hls,rtsp,mp3,aac,pcm_s16le,pcm_f32le \
        --enable-parser=h264,hevc,aac,mpegaudio \
        --enable-protocol=file,http,https,tcp,udp,hls,rtmp \
        --enable-muxer=null \
        --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,aac_adtstoasc \
        --disable-avdevice \
        --disable-network \
        --enable-network \
        --disable-asm

    make -j$(sysctl -n hw.ncpu)
    make install
}

# Build x86_64 simulator (for Intel Macs)
build_sim "x86_64"

# Build arm64 simulator (for Apple Silicon Macs) if not already built
if [ ! -f "$BUILD_DIR/output-iphonesimulator-arm64/lib/libavcodec.a" ]; then
    build_sim "arm64"
fi

echo ">>> Merging simulator architectures with lipo..."

DEVICE_PREFIX="$BUILD_DIR/output-iphoneos-arm64"
SIM_ARM64="$BUILD_DIR/output-iphonesimulator-arm64"
SIM_X86="$BUILD_DIR/output-iphonesimulator-x86_64"
SIM_FAT="$BUILD_DIR/output-iphonesimulator-fat"

rm -rf "$SIM_FAT"
mkdir -p "$SIM_FAT/lib"
# Use headers from arm64 (they're identical across archs)
cp -R "$SIM_ARM64/include" "$SIM_FAT/include"

for LIB in libavformat libavcodec libavutil libswresample libswscale libavfilter; do
    echo "  lipo merging ${LIB}..."
    lipo -create \
        "$SIM_ARM64/lib/${LIB}.a" \
        "$SIM_X86/lib/${LIB}.a" \
        -output "$SIM_FAT/lib/${LIB}.a"
done

echo ">>> Merging all static libraries per platform..."

# Device: merge all libs into one
libtool -static -o "${DEVICE_PREFIX}/lib/libFFmpegAll.a" \
    "${DEVICE_PREFIX}/lib/libavformat.a" \
    "${DEVICE_PREFIX}/lib/libavcodec.a" \
    "${DEVICE_PREFIX}/lib/libavutil.a" \
    "${DEVICE_PREFIX}/lib/libswresample.a" \
    "${DEVICE_PREFIX}/lib/libswscale.a" \
    "${DEVICE_PREFIX}/lib/libavfilter.a"

# Simulator (fat arm64+x86_64): merge all libs into one
libtool -static -o "${SIM_FAT}/lib/libFFmpegAll.a" \
    "${SIM_FAT}/lib/libavformat.a" \
    "${SIM_FAT}/lib/libavcodec.a" \
    "${SIM_FAT}/lib/libavutil.a" \
    "${SIM_FAT}/lib/libswresample.a" \
    "${SIM_FAT}/lib/libswscale.a" \
    "${SIM_FAT}/lib/libavfilter.a"

echo ">>> Creating FFmpegLibs.xcframework..."

rm -rf "$PROJECT_DIR/Frameworks"
mkdir -p "$PROJECT_DIR/Frameworks"

xcodebuild -create-xcframework \
    -library "$DEVICE_PREFIX/lib/libFFmpegAll.a" \
    -headers "$DEVICE_PREFIX/include" \
    -library "$SIM_FAT/lib/libFFmpegAll.a" \
    -headers "$SIM_FAT/include" \
    -output "$PROJECT_DIR/Frameworks/FFmpegLibs.xcframework"

echo "=== Done! ==="
ls -la "$PROJECT_DIR/Frameworks/"
