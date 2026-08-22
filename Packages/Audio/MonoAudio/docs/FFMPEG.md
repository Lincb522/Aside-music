# FFmpeg integration

## Portable CLI path

The compiler emits filters in this order:

1. `equalizer` filters for device baseline
2. `equalizer`, `bass`, or `treble` filters for track EQ and PEQ
3. `acompressor` when explicitly enabled
4. `extrastereo` for bounded stereo width
5. `volume` for preamp/headroom
6. `alimiter` as the final filter

The compiler uses only numeric plan fields, a POSIX locale, and no shell
interpolation. `FFmpegCommandLine` launches `/usr/bin/env` with an argv array.

## Streaming path

`FFmpegStreamingCommandBuilder` accepts a typed source, destination, codec, and
optional tuning plan. It emits one argument per value and passes remote URLs as
`absoluteString`; no endpoint or filter expression is evaluated by a shell.

Before a relay, `inspectStreamingCapabilities()` reads the selected executable's
protocols, demuxers, muxers, and audio encoders. The command builder can reject
missing capabilities before opening either endpoint. This check does not test
remote reachability or filter availability.

`FFmpegCommandLine.relay` waits for the child process on a detached utility task.
It currently has no programmatic terminate handle, so automated checks should
set `maximumDurationSeconds`; a foreground CLI relay can be stopped with
`Ctrl-C`. See `STREAMING.md` and `Examples/Streaming/local-hls-smoke.sh`.

## iOS package

`Integrations/FFmpegSwiftSDK` maps the portable plan to `FFmpegSwiftSDK` APIs:

- `AudioEqualizer.setGraphicMode`
- `AudioEqualizer.setCalibrationGains`
- `AudioEqualizer.setParametricBands`
- `AudioEffects.setCompressorParams`
- `AudioEffects.setStereoWidth`
- `AudioRepairEngine.configureOutputSafety`

The same integration package provides `FFmpegSwiftSDKStreamingTransport` for
`MonoAudioStreamingSession`. It prepares `StreamPlayer` with `autoPlay: false`,
maps EOF/errors/format changes to portable events, and explicitly rejects request
options that the current SDK cannot apply.

On iOS, `FFmpegSwiftSDK` handles decoding, format compatibility, measurement,
and realtime filters. The host application manages the AVFoundation/Core Audio
session and route. Do not start a command-line FFmpeg process on iOS.

## Distribution

The MonoAudio source license does not relicense FFmpeg. Determine distribution
obligations from the exact FFmpeg configure flags and linked libraries in each
published binary.
