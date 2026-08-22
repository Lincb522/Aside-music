---
name: mono-audio-tuning
description: Audit, implement, and verify MonoAudio tuning plans, device and headphone baselines, Agent providers, EQ and PEQ, compression, stereo width, headroom, limiters, FFmpeg file and streaming paths, MonoAudioStreaming transports, the iOS FFmpegSwiftSDK bridge, and new platform adapters. Use for audio tuning, AI 调音, 均衡器, 耳机校准, OPRA, 10/32-band EQ, clipping safety, HTTP(S), HLS, RTSP, RTMP, SRT, Icecast, FFmpeg CLI capabilities or filtergraphs, realtime audio constraints, and cross-platform playback integration.
---

# MonoAudio Tuning

## Workflow

1. Locate the package root by finding the `Package.swift` whose package name is `MonoAudio`.
2. Read the affected target, its tests, and the relevant reference:
   - Public products or extension boundaries: [architecture-and-api.md](references/architecture-and-api.md)
   - Plan, Agent, DSP, or headroom behavior: [dsp-and-agent-contract.md](references/dsp-and-agent-contract.md)
   - Streaming, FFmpeg, CLI, iOS, or another platform adapter: [streaming-and-platforms.md](references/streaming-and-platforms.md)
   - Test commands: [verification.md](references/verification.md)
3. Edit the target responsible for the behavior and add a focused test.
4. Run the focused test and the package test command. Run FFmpeg, relay, or iOS checks when those files change.

## Target map

| Work | Target | Rule |
| --- | --- | --- |
| Plan schema, EQ/PEQ, headroom, validation | `MonoAudioCore` | Remain deterministic and platform-neutral |
| Provider-generated tuning | `MonoAudioAgent` | Restore `request.deviceBaseline`; reject stale or invalid results |
| Stream endpoint, events, lifecycle | `MonoAudioStreaming` | Do not add a decoder, UI, or system audio session |
| Filtergraph, probe, render, relay | `MonoAudioFFmpeg` | Pass argv without a shell; inspect executable capabilities before relay |
| CLI commands | `MonoAudioCLI` | Keep output machine-readable and errors actionable |
| iOS realtime execution and playback | `Integrations/FFmpegSwiftSDK` | Use the SDK bridge; never start command-line FFmpeg on iOS |
| New runtime | New adapter package or target | Implement public protocols without adding platform code to portable targets |

## DSP and runtime rules

- Keep the processing order: device baseline → broad graphic EQ → selective PEQ → compressor when enabled → stereo width → preamp → final limiter.
- Restore `deviceBaseline` from `MonoAudioTuningRequest`; do not use the provider's value.
- Validate every `MonoAudioPlan` before compilation or application. Use the validator's combined worst-case gain, not the highest graphic band alone, for headroom.
- Prefer a neutral or omitted stage when evidence is weak. Do not claim audible improvement without listening evidence or captured measurements.
- Keep inference, networking, process creation, JSON parsing, allocation-heavy work, and locks outside realtime render callbacks. Smooth live parameter changes in the platform engine.
- `MonoAudioStreamProtocol` does not report executable capabilities. Inspect the selected FFmpeg executable's protocols, demuxers, muxers, and encoders before a checked relay.
- Validate stream endpoints and request options before opening the network. Pass remote URLs with `absoluteString`; never turn them into local file paths.
- Build FFmpeg commands as executable plus argument array. Do not construct `sh -c` strings. Do not log authorization headers, signed queries, or publishing passwords.
- Return an error for unsupported adapter options. Preserve cancellation, delegate ownership, and state transitions.

## Verification

- Run the package test command in [verification.md](references/verification.md).
- Run `scripts/verify.sh`; add `--hls-smoke` after relay changes.
- Report the command, exit status, relevant output, and generated files. State which platform or protocol checks were not run.
