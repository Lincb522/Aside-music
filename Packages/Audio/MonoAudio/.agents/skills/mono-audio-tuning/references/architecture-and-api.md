# Architecture and public API

## Product boundaries

| Product | Owns | Does not own |
| --- | --- | --- |
| `MonoAudioCore` | Versioned tuning models, feature snapshots, execution protocols, deterministic validation and headroom | Model inference, networking, playback, UI, persistence |
| `MonoAudioAgent` | Provider coordination, stale-request rejection, route-baseline restoration, local validation | DSP execution or final safety policy in a provider |
| `MonoAudioStreaming` | Stream endpoint and request models, transport events, lifecycle actor | Decoder, network stack, system audio session, UI |
| `MonoAudioFFmpeg` | Filtergraph compilation, probe/render, stream capability parsing, relay argv and execution | iOS process execution or portable stream state |
| `mono-audio` | JSON-facing validation, inspection, render, capability and relay commands | Application playback state |
| `MonoAudioFFmpegSwiftSDK` | iOS plan executor and `StreamPlayer` transport adapter | Command-line FFmpeg |

## Stable public contracts

### Tuning

- `MonoAudioPlan` is the versioned, Codable plan.
- `MonoAudioPlanValidator` returns a `ValidationReport` and the recommended preamp.
- `MonoAudioFeatureSource` captures measurements.
- `MonoAudioOutputRouteProvider` supplies output identity and device baseline.
- `MonoAudioPlanExecutor` applies or resets validated state.
- `MonoAudioAgentProvider` generates a proposed plan.
- `MonoAudioAgent` restores the request baseline, checks the requested graphic mode, validates locally, and discards stale generations.

### Streaming

- `MonoAudioStreamEndpoint` describes URL, delivery protocol, and format.
- `MonoAudioStreamSource` adds identity and request options.
- `MonoAudioStreamingTransport` provides `events`, `open`, `play`, `pause`, and `stop`.
- `MonoAudioStreamingSession` owns state transitions and fans out portable events.

### FFmpeg

- `FFmpegFilterGraphCompiler` compiles only valid plans.
- `FFmpegCommandLine` probes, renders, inspects one executable's streaming capabilities, and runs a relay on macOS or Linux.
- `FFmpegStreamingCommandBuilder` produces an executable and argument array without network work.
- `FFmpegStreamingCapabilities` captures protocols, demuxers, muxers, and audio encoders observed from one executable.

### iOS bridge

- `FFmpegSwiftSDKPlanExecutor` conforms to `MonoAudioPlanExecutor` and applies validated plan fields on the main actor.
- `FFmpegSwiftSDKStreamingTransport` conforms to `MonoAudioStreamingTransport`, retains a delegate proxy, prepares with `autoPlay: false`, and translates SDK state to portable events.
- The transport rejects request fields that the current `StreamPlayer` API cannot apply.

## Extension rules

### Add a platform executor

1. Depend on `MonoAudioCore`.
2. Conform to `MonoAudioPlanExecutor`.
3. Re-run `MonoAudioPlanValidator` at the execution boundary.
4. Map every supported stage in contract order.
5. Make reset deterministic and safe.
6. Document any stage that cannot be represented and fail explicitly when silent degradation would be unsafe.

### Add a streaming transport

1. Depend on `MonoAudioStreaming`.
2. Return `events()` immediately without opening the network.
3. Validate the source before connection work.
4. Keep network, playlist, decode, and retry work off realtime callbacks.
5. Implement lifecycle transitions compatible with `MonoAudioStreamingSession`.
6. Translate recoverability and end-of-stream distinctly.
7. Add a fake-transport state test plus a bounded runtime integration test.

### Change the wire contract

Update together:

- `Sources/MonoAudioCore`
- `Schemas/mono-audio-plan.schema.json`
- Codable fixtures in `Examples`
- focused tests for decode, validation, and execution
- FFmpeg compiler and platform executors when a DSP field changes

Increment `schemaVersion` only for an incompatible wire-format change.
