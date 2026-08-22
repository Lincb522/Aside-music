# Streaming, FFmpeg and platform adapters

## Portable streaming contract

The model can represent HTTP, HTTPS, HLS, RTSP, RTMP, SRT and Icecast. Representation is not runtime availability.

| Protocol | Allowed schemes | Compatible explicit formats |
| --- | --- | --- |
| HTTP | `http` | Any declared stream format |
| HTTPS | `https` | Any declared stream format |
| HLS | `http`, `https` | `automatic`, `hls` |
| RTSP | `rtsp`, `rtsps` | `automatic`, `rtsp` |
| RTMP | `rtmp`, `rtmps` | `automatic`, `flv` |
| SRT | `srt` | `automatic`, `mpegTS` |
| Icecast | `http`, `https`, `icecast` | `automatic`, `mp3`, `aac`, `ogg`, `opus` |

Every endpoint requires a scheme and host. Every source requires a non-empty ID. Header names must be HTTP tokens; header values and user agents must not contain CR or LF. RTSP transport options belong only on RTSP sources.

`MonoAudioStreamingSession` owns the portable lifecycle. Open only from `idle`, `stopped`, or `failed`; play from `ready` or `paused`; pause from `playing` or `buffering`. Let `stop()` cancel the active generation so late transport events cannot mutate a later session.

## FFmpeg relay path

Before claiming a checked relay works:

1. Run `mono-audio stream-capabilities` against the exact executable.
2. Confirm input and output URL protocols.
3. Confirm the input demuxer when the format requires one.
4. Confirm the destination muxer.
5. Confirm the selected encoder unless using stream copy.
6. Build with `relay-argv ... --check-capabilities` before opening a remote endpoint.

SRT commonly depends on an FFmpeg build configured with libsrt. Missing SRT is a capability result, not a reason to remove SRT from the portable model.

Preserve these command rules:

- Use one array element per argument; never run through a shell.
- Use `URL.absoluteString` for remote endpoints and file paths only for file URLs.
- Keep credentials out of logs. Treat headers, query signatures, and Icecast publishing URLs as sensitive.
- Reject filtering with `streamCopy`.
- Keep bitrate, sample rate, channel count, and maximum duration within builder bounds.
- Use `maximumDurationSeconds` for bounded automation. Current Swift task cancellation does not terminate the FFmpeg child process.
- Run command-line FFmpeg only on macOS or Linux.

### CLI surface

```bash
swift run mono-audio validate Examples/neutral-plan.json
swift run mono-audio filtergraph Examples/neutral-plan.json
swift run mono-audio probe <input-or-url>
swift run mono-audio render <plan.json> <input> <output> --overwrite
swift run mono-audio stream-capabilities
swift run mono-audio relay-argv <relay.json> --check-capabilities
swift run mono-audio relay <relay.json> --check-capabilities
```

Use `relay-argv` for passive inspection. Use `relay` only after the destination and bounded side effects are understood.

## iOS FFmpegSwiftSDK bridge

Use `FFmpegSwiftSDKPlanExecutor` for realtime plan application and `FFmpegSwiftSDKStreamingTransport` for `StreamPlayer` lifecycle adaptation.

- Keep SDK mutation on the main actor.
- Validate before applying EQ, PEQ, compressor, width, preamp, and limiter state.
- Preserve the existing `StreamPlayer` delegate through the retained proxy.
- Prepare with `autoPlay: false`; let the portable session call `play()`.
- Map end-of-stream separately from failures and mark failure recoverability deliberately.
- Reject non-default headers, user agent, timeout, reconnect, or RTSP preferences until `StreamPlayer` can actually apply them.
- Never spawn the command-line runner on iOS.

## Other platforms

Keep the portable types unchanged when adding a runtime:

- Apple native playback: AVFoundation/Core Audio adapter
- Android: Media3 playback plus a dedicated DSP executor; use Oboe only when the audio architecture requires it
- Linux/Windows desktop: FFmpeg, GStreamer, or a native engine behind the transport and executor protocols
- Browser: a transport around fetch/media APIs and an AudioWorklet-safe executor boundary

Platform names are adapter choices, not support claims. Add a build test and a bounded playback or relay fixture before marking one available.
