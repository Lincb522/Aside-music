#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build-ffmpeg"
FFMPEG_SRC="$BUILD_DIR/ffmpeg-8.0"
IOS_MIN_VERSION="16.0"

# All common audio decoders
DECODERS="h264,hevc,av3a,aac,aac_latm,mp3,mp3float,flac,vorbis,opus,alac,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s24be,pcm_s32le,pcm_s32be,pcm_f32le,pcm_f32be,pcm_f64le,pcm_mulaw,pcm_alaw,wavpack,ape,tak,dsd_lsbf,dsd_msbf,dsd_lsbf_planar,dsd_msbf_planar,wmav1,wmav2,wmalossless,wmapro,amrnb,amrwb,ac3,eac3,dca,atrac1,atrac3,atrac3p,cook,ra_144,ra_288,mpc7,mpc8,tta,musepack7,musepack8,adpcm_ima_wav,adpcm_ms"

# All common audio demuxers
DEMUXERS="mov,mpegts,flv,hls,rtsp,mp3,aac,flac,ogg,wav,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s24be,pcm_s32le,pcm_f32le,pcm_f32be,pcm_f64le,pcm_mulaw,pcm_alaw,ape,tak,wv,tta,dsf,dff,asf,asf_o,xwma,rm,mpc,mpc8,matroska,webm_dash_manifest,w64,aiff,caf,amr,ac3,eac3,dts,dtshd,spdif,iff"

# Parsers
PARSERS="h264,hevc,aac,aac_latm,mpegaudio,flac,vorbis,opus,ac3,dca"

# Common configure flags
COMMON_FLAGS="--enable-static \
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
    --enable-decoder=$DECODERS \
    --enable-demuxer=$DEMUXERS \
    --enable-parser=$PARSERS \
    --enable-protocol=file,http,https,tcp,udp,hls,rtmp \
    --enable-muxer=null \
    --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,aac_adtstoasc \
    --disable-avdevice \
    --enable-network \
    --disable-asm"

PYTHON_BIN="/usr/bin/python3"
if [ ! -x "$PYTHON_BIN" ]; then
    PYTHON_BIN="$(command -v python3)"
fi
"$PYTHON_BIN" "$SCRIPT_DIR/prepare-audio-vivid.py" "$FFMPEG_SRC"

build_ffmpeg() {
    local PLATFORM=$1
    local ARCH=$2
    local PREFIX="$BUILD_DIR/output-${PLATFORM}-${ARCH}"

    echo ""
    echo ">>> Building FFmpeg for ${PLATFORM} ${ARCH}..."

    local SDK_PATH=$(xcrun --sdk ${PLATFORM} --show-sdk-path)
    local CC=$(xcrun --sdk ${PLATFORM} --find clang)

    local EXTRA_CFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH}"
    local EXTRA_LDFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH}"

    if [ "$PLATFORM" = "iphoneos" ]; then
        EXTRA_CFLAGS="$EXTRA_CFLAGS -mios-version-min=${IOS_MIN_VERSION}"
        EXTRA_LDFLAGS="$EXTRA_LDFLAGS -mios-version-min=${IOS_MIN_VERSION}"
    else
        EXTRA_CFLAGS="$EXTRA_CFLAGS -mios-simulator-version-min=${IOS_MIN_VERSION} -target ${ARCH}-apple-ios${IOS_MIN_VERSION}-simulator"
        EXTRA_LDFLAGS="$EXTRA_LDFLAGS -mios-simulator-version-min=${IOS_MIN_VERSION} -target ${ARCH}-apple-ios${IOS_MIN_VERSION}-simulator"
    fi

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
        $COMMON_FLAGS

    make -j$(sysctl -n hw.ncpu)
    make install
}

# Build all 3 targets
build_ffmpeg "iphoneos" "arm64"
build_ffmpeg "iphonesimulator" "arm64"
build_ffmpeg "iphonesimulator" "x86_64"

echo ""
echo ">>> Merging simulator architectures with lipo..."

DEVICE_PREFIX="$BUILD_DIR/output-iphoneos-arm64"
SIM_ARM64="$BUILD_DIR/output-iphonesimulator-arm64"
SIM_X86="$BUILD_DIR/output-iphonesimulator-x86_64"
SIM_FAT="$BUILD_DIR/output-iphonesimulator-fat"

rm -rf "$SIM_FAT"
mkdir -p "$SIM_FAT/lib"
cp -R "$SIM_ARM64/include" "$SIM_FAT/include"

for LIB in libavformat libavcodec libavutil libswresample libswscale libavfilter; do
    echo "  lipo merging ${LIB}..."
    lipo -create \
        "$SIM_ARM64/lib/${LIB}.a" \
        "$SIM_X86/lib/${LIB}.a" \
        -output "$SIM_FAT/lib/${LIB}.a"
done

echo ">>> Merging all static libraries per platform..."

libtool -static -o "${DEVICE_PREFIX}/lib/libFFmpegAll.a" \
    "${DEVICE_PREFIX}/lib/libavformat.a" \
    "${DEVICE_PREFIX}/lib/libavcodec.a" \
    "${DEVICE_PREFIX}/lib/libavutil.a" \
    "${DEVICE_PREFIX}/lib/libswresample.a" \
    "${DEVICE_PREFIX}/lib/libswscale.a" \
    "${DEVICE_PREFIX}/lib/libavfilter.a"

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

echo ""
echo ">>> Removing platform-specific headers..."

REMOVE_HEADERS=(
    "libavcodec/d3d11va.h"
    "libavcodec/dxva2.h"
    "libavcodec/qsv.h"
    "libavcodec/vdpau.h"
    "libavcodec/mediacodec.h"
    "libavcodec/jni.h"
    "libavcodec/smpte_436m.h"
    "libavutil/hwcontext_cuda.h"
    "libavutil/hwcontext_d3d11va.h"
    "libavutil/hwcontext_d3d12va.h"
    "libavutil/hwcontext_drm.h"
    "libavutil/hwcontext_dxva2.h"
    "libavutil/hwcontext_mediacodec.h"
    "libavutil/hwcontext_opencl.h"
    "libavutil/hwcontext_qsv.h"
    "libavutil/hwcontext_vaapi.h"
    "libavutil/hwcontext_vdpau.h"
    "libavutil/hwcontext_vulkan.h"
    "libavutil/hwcontext_amf.h"
    "libavutil/hwcontext_oh.h"
)

# Clean from CFFmpeg headers
for h in "${REMOVE_HEADERS[@]}"; do
    rm -f "$PROJECT_DIR/Sources/CFFmpeg/include/$h"
done

# Clean from xcframework
for variant in "$PROJECT_DIR/Frameworks/FFmpegLibs.xcframework"/*/Headers; do
    for h in "${REMOVE_HEADERS[@]}"; do
        rm -f "$variant/$h"
    done
done

echo ">>> Regenerating Xcode project..."
xcodegen generate --spec "$PROJECT_DIR/Example/project.yml" --project "$PROJECT_DIR/Example/" 2>&1

echo ""
echo "=== All done! Clean Build Folder in Xcode then rebuild ==="
