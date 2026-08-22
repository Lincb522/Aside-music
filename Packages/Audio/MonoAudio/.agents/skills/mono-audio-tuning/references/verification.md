# Verification

Run commands from the directory containing the MonoAudio `Package.swift`.

## Always

```bash
swift test -j 2 -Xswiftc -warnings-as-errors
git diff --check -- .
```

Report the number of tests from actual output. Do not reuse an earlier count after adding or removing tests.

## Plans and Agent behavior

Cover at least the changed boundary:

1. valid neutral 10-band and 32-band plans,
2. exact band count and adjacent-jump failures,
3. conservative combined headroom,
4. route baseline restoration,
5. requested-mode mismatch,
6. stale provider result rejection,
7. Codable/schema fixture compatibility when the wire contract changes.

For an audible-quality claim, add captured measurements or name the exact listening setup. Unit tests prove contract behavior, not sound quality.

## FFmpeg file path

```bash
swift run mono-audio validate Examples/neutral-plan.json
swift run mono-audio filtergraph Examples/neutral-plan.json
```

For a render change, generate or use a bounded fixture, render it, and inspect the result with `ffprobe`. Record the FFmpeg return code, duration, sample rate, channel count, codec, and a checksum when reproducibility matters.

## Streaming

```bash
swift run mono-audio stream-capabilities
swift run mono-audio relay-argv Examples/http-hls-relay.json --check-capabilities
./Examples/Streaming/local-hls-smoke.sh
```

The local smoke script is the preferred end-to-end check because it serves a finite HLS fixture on `127.0.0.1`, applies a plan, relays a bounded segment, and checks the output. Do not turn a successful local HLS run into a claim that RTSP, RTMP, SRT, Icecast, or public-network reachability was tested.

## iOS bridge

```bash
cd Integrations/FFmpegSwiftSDK
xcodebuild \
  -scheme MonoAudioFFmpegSwiftSDK \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/xcode-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Confirm that the integration graph contains `MonoAudioCore`, `MonoAudioStreaming`, and `FFmpegSwiftSDK`, but not `MonoAudioFFmpeg` or `MonoAudioCLI`.

## Skill package

From the skill directory, run:

```bash
./scripts/verify.sh
./scripts/verify.sh --hls-smoke  # only when the FFmpeg relay path changed
```

Also validate the skill with the installed skill-creator `quick_validate.py` when available. Check every relative Markdown link and reject private absolute paths.

## Record

- command and working directory,
- return code,
- relevant output,
- produced artifact path and checksum when applicable,
- checks not run.
