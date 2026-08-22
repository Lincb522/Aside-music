# Verification record

Verified on 2026-08-22 with Apple Swift 6.3, Xcode 26.4 SDKs, and FFmpeg 8.0.1.

## Portable package

```bash
cd Packages/Audio/MonoAudio
swift test -j 2 -Xswiftc -warnings-as-errors
```

Result: build succeeded; 17 Swift Testing tests passed. The suite covers plan
validation, Agent baseline ownership, streaming endpoint validation and session
transitions, deterministic FFmpeg relay argv, runtime capability parsing, remote
URL handling, and filter/copy conflicts.

## iOS FFmpegSwiftSDK integration

```bash
cd Packages/Audio/MonoAudio/Integrations/FFmpegSwiftSDK
xcodebuild \
  -scheme MonoAudioFFmpegSwiftSDK \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/xcode-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result: `** BUILD SUCCEEDED **` for arm64 and x86_64 iOS Simulator. The target
contains both `FFmpegSwiftSDKPlanExecutor` and
`FFmpegSwiftSDKStreamingTransport`; its dependency graph does not include the
command-line `MonoAudioFFmpeg` or `MonoAudioCLI` targets.

## Stock FFmpeg end-to-end render

```bash
cd Packages/Audio/MonoAudio
mkdir -p .build/verification
ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i 'sine=frequency=440:duration=1:sample_rate=48000' \
  -c:a flac .build/verification/input.flac
.build/debug/mono-audio render \
  Examples/neutral-plan.json \
  .build/verification/input.flac \
  .build/verification/output.flac \
  --overwrite
```

Result: FFmpeg return code `0`; output is one-second, 48 kHz mono FLAC.

```text
input  SHA-256 4f91129ec41b77e09140f480074dfa051bd65ca32d0de2f9010bac2dfb3ea104
output SHA-256 4f4b78508f2a635687052ef967d63b410cb48e11c91c39f2c8cf62d856ef1cdb
```

The compiled neutral filtergraph was:

```text
volume=volume=-0.5dB:precision=float,alimiter=limit=0.891251:attack=5:release=50:level=false:latency=true
```

## Local HLS relay

```bash
cd Packages/Audio/MonoAudio
MONO_AUDIO_SMOKE_PORT=18766 ./Examples/Streaming/local-hls-smoke.sh
```

The script generated a four-second AAC/HLS fixture, served it on `127.0.0.1`,
applied `Examples/neutral-plan.json`, relayed two seconds to HTTP MPEG-TS, and
inspected the result with `ffprobe`. It also asserted that the executed argv
contained `-af` and the final `alimiter`. It did not contact a public endpoint.

Result: return code `0`; audio codec `aac`; smoke test passed.

```text
relayed MPEG-TS SHA-256 9c264a62f3bb3666bc4e548bbe3d382eb4bc172e101a93378dbd8d5096c70d2a
```

## Brand assets

```bash
cd Packages/Audio/MonoAudio
xmllint --noout assets/*.svg
file assets/*.png
```

Result: all five SVG files parsed successfully. Raster exports are transparent
RGBA PNGs; marks are 1024 x 1024 and lockups are 1720 x 320. The source SVGs
have no external font, gradient, or filter dependency.

## Project Agent Skill

```bash
cd Packages/Audio/MonoAudio
python3 \
  "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py" \
  .agents/skills/mono-audio-tuning
bash .agents/skills/mono-audio-tuning/scripts/verify.sh
MONO_AUDIO_SMOKE_PORT=18767 \
  bash .agents/skills/mono-audio-tuning/scripts/verify.sh --hls-smoke
```

Result: skill-creator validation returned `0`; every checked-in relative
Markdown link and both self-contained SVG metadata assets resolved. The default
verifier passed plan validation, deterministic filtergraph compilation, relay
argv generation, and local FFmpeg capability inspection. The optional
loopback-only HLS run passed all five checks and reproduced the MPEG-TS checksum
recorded above. Evidence is written under `.build/skill-verification*`.
