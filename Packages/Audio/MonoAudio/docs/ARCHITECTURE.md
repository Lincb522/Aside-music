# Architecture

## Boundaries

`MonoAudioCore` defines the versioned plan types, public protocols, validator,
and headroom calculation. It has no playback, networking, persistence, UI, or
device-database implementation.

`MonoAudioAgent` accepts a provider-generated plan, restores the route-owned
device baseline, rejects stale generation results, and runs the local validator.
The provider cannot directly apply DSP state.

`MonoAudioStreaming` defines stream endpoints, requests, lifecycle state, events,
and the transport protocol. The module has no decoder, UI, system audio session,
or platform playback framework.

`MonoAudioFFmpeg` converts a valid plan to stock FFmpeg filters. Its
command-line runner is compiled for macOS and Linux and handles file jobs,
capability checks, and stream relays.

`Integrations/FFmpegSwiftSDK` contains the iOS plan executor and streaming
transport. It maps plan fields to the realtime engine and adapts `StreamPlayer`
to `MonoAudioStreamingSession`. Neither adapter starts a command-line process.

## Tuning stages

When inputs conflict, use runtime measurements and output-route state before
metadata or model output. OPRA or another measured profile supplies
`deviceBaseline`. Graphic EQ handles broad tonal changes, PEQ handles selective
correction, the compressor handles dynamics, and preamp plus limiter handle
headroom and peak limiting.

## Realtime rules

- Never perform inference, JSON parsing, allocation-heavy work, file I/O, or
  FFmpeg process creation in a render callback.
- Precompile coefficients and smooth live parameter changes in platform DSP.
- Invalidate results when asset, stream variant, output route, or band mode
  changes.
- Recalculate headroom after combining the device baseline with the track plan.
- Keep reconnect, authentication refresh, adaptive bitrate, and cache policy in
  the host transport rather than the DSP plan.

## Compatibility

`schemaVersion` changes only for breaking wire-format changes. New platforms
should consume `Schemas/mono-audio-plan.schema.json` and reproduce the validator
fixtures before applying plans to audio.
