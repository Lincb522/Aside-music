# Streaming / 流媒体

## 中文

### 模块边界

`MonoAudioStreaming` 只定义流地址、状态机和传输接口。它不依赖 SwiftUI、UIKit、
AVFoundation，也不创建解码器或系统音频会话。

- `MonoAudioStreamEndpoint`：URL、传输协议和格式
- `MonoAudioStreamSource`：输入端点、请求头、超时、重连和 RTSP 选项
- `MonoAudioStreamingTransport`：平台播放器或解码器需要实现的异步接口
- `MonoAudioStreamingSession`：`open / play / pause / stop` 状态机和事件分发
- `FFmpegStreamingCommandBuilder`：生成确定的 FFmpeg `argv`
- `FFmpegCommandLine.relay`：macOS/Linux 上运行前台 FFmpeg 转发任务

协议模型和运行能力是两件事。HTTP(S)、HLS、RTSP、RTMP、SRT 和 Icecast
都能写进公共模型；能否运行由实际 FFmpeg 构建决定。`stream-capabilities`
会读取 protocol、demuxer、muxer 和 audio encoder，而不是根据 URL 猜测。

| 模型 | 常用 URL | FFmpeg 输入检查 | FFmpeg 输出检查 |
| --- | --- | --- | --- |
| HTTP / HTTPS | `http://`, `https://` | `http` / `https` protocol | 对应 protocol + 目标 muxer |
| HLS | HTTP(S) `.m3u8` | HTTP(S) protocol + `hls` demuxer | 目标 protocol + `hls` muxer |
| RTSP | `rtsp://`, `rtsps://` | `rtsp` demuxer | `rtsp` muxer |
| RTMP | `rtmp://`, `rtmps://` | 对应 protocol | 对应 protocol + `flv` muxer |
| SRT | `srt://` | `srt` protocol | `srt` protocol + 通常为 `mpegts` muxer |
| Icecast | 输入常用 HTTP(S)，发布用 `icecast://` | URL 对应 protocol | `icecast` protocol + 音频 muxer |

有些 FFmpeg 构建不带 libsrt；模型仍可表达 SRT 端点，但 capability 校验会返回
`urlProtocol: srt`，转发不会被误报为可用。

### 接入平台播放器

```swift
import MonoAudioStreaming

let source = MonoAudioStreamSource(
    id: "studio-live",
    endpoint: .init(
        url: URL(string: "https://cdn.example.com/live/index.m3u8")!,
        streamProtocol: .hls,
        format: .hls
    )
)

let transport: any MonoAudioStreamingTransport = PlatformStreamTransport()
let session = MonoAudioStreamingSession(transport: transport)

let events = await session.events()
Task {
    for await event in events {
        // 把事件交给应用状态层；不要在音频渲染回调里消费网络事件。
        print(event)
    }
}

try await session.open(source)
try await session.play()
```

`PlatformStreamTransport` 由宿主实现。Apple 平台可以接 AVPlayer 或自有
Core Audio 解码链，Android 可以接 Media3/Oboe，桌面端可以接 FFmpeg、GStreamer
或原生引擎。传输实现必须把连接、清单解析、重连和解码放在异步工作线程；实时
音频回调只接收已经准备好的 PCM 或参数。

### FFmpeg 转发

```swift
import MonoAudioFFmpeg
import MonoAudioStreaming

let destination = MonoAudioStreamEndpoint(
    url: URL(string: "icecast://radio.example.com:8000/live")!,
    streamProtocol: .icecast,
    format: .mp3
)
let relay = FFmpegStreamingRelayConfiguration(
    source: source,
    destination: destination,
    audioCodec: .mp3,
    audioBitrateKilobitsPerSecond: 192
)

let ffmpeg = FFmpegCommandLine()
let capabilities = try ffmpeg.inspectStreamingCapabilities()
let command = try FFmpegStreamingCommandBuilder().buildRelay(
    relay,
    capabilities: capabilities
)
print(command.argv) // [String]，没有 shell 拼接

let result = try await ffmpeg.relay(relay, capabilities: capabilities)
```

`relay` 会在 detached utility task 中启动 FFmpeg，网络与进程等待不会占用调用者
线程。当前 API 的 Swift Task 取消不会主动终止子进程。长期任务应由宿主保存并管理
进程生命周期；命令行前台任务可用 `Ctrl-C` 结束。自动化和测试应设置
`maximumDurationSeconds`，它会生成有限的 `-t` 参数。

不要记录含认证请求头、签名查询参数或 Icecast 密码的完整 `argv`。

### CLI

```bash
swift run mono-audio stream-capabilities
swift run mono-audio relay-argv relay.json --check-capabilities
swift run mono-audio relay relay.json --check-capabilities
```

`relay.json` 使用 `FFmpegStreamingRelayConfiguration` 的 Codable 结构。远程输入
始终使用 URL 的 `absoluteString`，不会被转换成本地文件路径。

有限本地 HLS 端到端检查：

```bash
./Examples/Streaming/local-hls-smoke.sh
```

脚本生成四秒正弦波 HLS，在 `127.0.0.1` 启动临时 HTTP 服务，通过 CLI 应用
`Examples/neutral-plan.json` 并转发两秒 MPEG-TS，最后用 `ffprobe` 和 SHA-256
检查输出。它不会访问公网。

---

## English

### Boundaries

`MonoAudioStreaming` owns stream addresses, lifecycle state, and transport
contracts. It has no SwiftUI, UIKit, AVFoundation, decoder, or system audio
session dependency.

- `MonoAudioStreamEndpoint` carries the URL, delivery protocol, and format.
- `MonoAudioStreamSource` adds headers, timeouts, reconnect policy, and RTSP options.
- `MonoAudioStreamingTransport` is the asynchronous adapter implemented by a host.
- `MonoAudioStreamingSession` owns `open / play / pause / stop` and event fan-out.
- `FFmpegStreamingCommandBuilder` produces deterministic FFmpeg argv arrays.
- `FFmpegCommandLine.relay` runs a foreground relay on macOS or Linux.

The protocol model is not a runtime capability claim. HTTP(S), HLS, RTSP, RTMP,
SRT, and Icecast can all be represented. Availability comes from the selected
FFmpeg binary's protocols, demuxers, muxers, and audio encoders. In particular,
an FFmpeg build without libsrt reports SRT as missing instead of accepting the
configuration on the strength of its URL alone.

### Runtime rules

Implement `MonoAudioStreamingTransport` with the native or third-party playback
engine used by the host. Connection setup, playlist parsing, retries, process
creation, and decoding belong on asynchronous worker threads. A realtime audio
callback may consume prepared PCM or coefficients; it must not perform those
operations itself.

The Swift API example and CLI commands above are identical in either language.
`FFmpegStreamingCommandBuilder` passes every value as a separate argument and
never creates `sh -c` text. `FFmpegCommandLine.relay` uses a detached utility
task, but cancelling that Swift task does not currently terminate the FFmpeg
child process. Use `maximumDurationSeconds` for bounded work, `Ctrl-C` for a
foreground CLI relay, or let the host own an explicitly cancellable process.

Run the local, finite HLS relay check with:

```bash
./Examples/Streaming/local-hls-smoke.sh
```

It generates a four-second HLS fixture, serves it only on `127.0.0.1`, applies
`Examples/neutral-plan.json`, relays two seconds to MPEG-TS, and verifies the
result with `ffprobe` and SHA-256.
