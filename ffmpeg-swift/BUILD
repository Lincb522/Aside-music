# Building FFmpeg for iOS

This document describes how to cross-compile FFmpeg 7.1 for iOS and create the `FFmpegLibs.xcframework` used by FFmpegSwiftSDK.

## Prerequisites

- macOS with Xcode 15+ and Command Line Tools installed
- FFmpeg 7.1 source code

## Download FFmpeg Source

```bash
mkdir -p build-ffmpeg && cd build-ffmpeg
curl -L https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz | tar xJ
cd ..
```

This places the source at `build-ffmpeg/ffmpeg-7.1/`.

## Build (One Command)

```bash
bash scripts/rebuild-all.sh
```

This script:
1. Cross-compiles FFmpeg for 3 targets:
   - `iphoneos arm64` (device)
   - `iphonesimulator arm64` (Apple Silicon Mac simulator)
   - `iphonesimulator x86_64` (Intel Mac simulator)
2. Merges simulator slices into a fat binary via `lipo`
3. Merges all 5 FFmpeg static libs into a single `libFFmpegAll.a` per platform via `libtool`
4. Creates `Frameworks/FFmpegLibs.xcframework` via `xcodebuild -create-xcframework`
5. Removes platform-specific headers (D3D, VAAPI, Vulkan, etc.)
6. Regenerates the Example Xcode project

## Build Configuration

The build enables:

### Audio Decoders (~30)
AAC, MP3, FLAC, Vorbis, Opus, ALAC, PCM (S16/S24/S32/F32/F64, LE/BE), μ-law, A-law, WavPack, APE, TAK, DSD, WMA (v1/v2/lossless/pro), AMR (NB/WB), AC3, EAC3, DTS, ATRAC (1/3/3+), Cook, MPC, TTA, ADPCM

### Video Decoders
H.264, HEVC (H.265)

### Demuxers
MOV/MP4, MPEG-TS, FLV, HLS, RTSP, MP3, AAC, FLAC, OGG, WAV, APE, TAK, WavPack, TTA, DSF, DFF, ASF, Matroska/WebM, AIFF, CAF, AMR, AC3, EAC3, DTS, and more

### Protocols
file, http, https, tcp, udp, hls, rtmp

### Build Flags
- Static libraries only (`--enable-static --disable-shared`)
- No programs/docs (`--disable-programs --disable-doc`)
- Size-optimized (`--enable-small`)
- PIC enabled for framework embedding
- ASM disabled for cross-compilation compatibility
- Minimum iOS deployment target: 16.0

## Output Structure

```
Frameworks/FFmpegLibs.xcframework/
├── Info.plist
├── ios-arm64/
│   ├── Headers/
│   │   ├── libavcodec/
│   │   ├── libavfilter/
│   │   ├── libavformat/
│   │   ├── libavutil/
│   │   └── libswresample/
│   └── libFFmpegAll.a
└── ios-arm64_x86_64-simulator/
    ├── Headers/
    │   └── (same structure)
    └── libFFmpegAll.a          # fat binary: arm64 + x86_64
```

## Individual Build Scripts

| Script | Purpose |
|--------|---------|
| `scripts/rebuild-all.sh` | Full build: all architectures + xcframework |
| `scripts/build-ffmpeg-ios.sh` | Build single architecture |
| `scripts/rebuild-sim-and-xcframework.sh` | Rebuild simulator + xcframework only |
| `scripts/build-ipa.sh` | Package unsigned IPA for sideloading |

## Troubleshooting

### "No such module 'CFFmpeg'" in Xcode
Clean the build folder (Cmd+Shift+K) and rebuild. The SPM package needs to resolve the xcframework first.

### Header errors (d3d11va.h, dxva2.h, etc.)
Run `scripts/rebuild-all.sh` — it automatically removes platform-specific headers that don't exist on iOS/macOS.

### Linker errors on simulator
Make sure the xcframework contains the fat simulator binary with both arm64 and x86_64. Verify with:
```bash
lipo -info Frameworks/FFmpegLibs.xcframework/ios-arm64_x86_64-simulator/libFFmpegAll.a
```
