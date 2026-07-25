# 语音识别歌词功能

## 概述

FFmpegSwiftSDK 集成了基于 WhisperKit 的语音识别引擎，可以自动将音频转换为带时间戳的歌词。

## 功能特性

- ✅ 支持本地文件和网络流
- ✅ 自动语言检测（支持中文、英文、日文等多种语言）
- ✅ 逐字时间戳（精确到每个字/词）
- ✅ 导出为增强 LRC 格式
- ✅ 直接集成到 LyricSyncer 进行同步播放
- ✅ 进度回调支持

## 使用方法

### 1. 基础使用

```swift
import FFmpegSwiftSDK

let recognizer = LyricRecognizer()

// 准备模型（首次会自动下载，约 75MB）
try await recognizer.prepare()

// 识别歌词
let result = try await recognizer.recognize(url: "https://example.com/song.mp3")

// 查看结果
print("识别到 \(result.segments.count) 行歌词")
print("语言: \(result.language ?? "未知")")
print("耗时: \(result.processingTime)秒")
```

### 2. 配置识别参数

```swift
var config = LyricRecognizerConfig()

// 指定语言（nil = 自动检测）
config.language = "zh"  // 中文
// config.language = "en"  // 英文
// config.language = "ja"  // 日文

// 指定模型（nil = 自动选择推荐模型）
config.modelName = "base"  // 可选: tiny, base, small, medium, large-v3

// 进度回调
config.onProgress = { progress in
    print("进度: \(Int(progress * 100))%")
}

let result = try await recognizer.recognize(url: url, config: config)
```

### 3. 应用到歌词同步

```swift
// 转换为 LyricLine 数组
let lines = result.toLyricLines()

// 加载到 LyricSyncer
player.lyricSyncer.load(lines: lines)

// 开始播放，歌词会自动同步
player.play(url: url)
```

### 4. 导出为 LRC 文件

```swift
// 导出为增强 LRC 格式（带逐字时间戳）
let lrc = result.toEnhancedLRC()

// 保存到文件
try lrc.write(to: URL(fileURLWithPath: "lyrics.lrc"), atomically: true, encoding: .utf8)
```

### 5. 查看逐字数据

```swift
for segment in result.segments {
    print("[\(segment.startTime)] \(segment.text)")
    
    // 逐字时间戳
    for word in segment.words {
        print("  \(word.text): \(word.startTime) - \(word.endTime)")
    }
}
```

## 示例项目集成

在 FFmpegDemo 示例项目中，语音识别功能已集成到歌词面板：

### 首次使用

1. 打开歌词面板
2. 点击"下载模型"按钮（首次使用）
3. 等待模型下载完成（显示进度提示）
4. 模型下载后会显示"识别引擎已就绪"

### 识别歌词

1. 输入音频 URL（本地文件或网络流）
2. 点击"语音识别"按钮
3. 等待识别完成（显示进度条）
4. 查看识别结果预览
5. 点击"应用歌词"加载到播放器
6. 点击"导出 LRC"复制到剪贴板

### 模型管理

- 模型首次下载后会缓存，后续使用无需重新下载
- 模型文件存储在：`~/Library/Caches/huggingface/`
- 应用关闭后模型会自动释放，下次启动需重新加载（但不需要重新下载）

## 模型选择

WhisperKit 支持多种模型，按大小和精度排序：

| 模型 | 大小 | 速度 | 精度 | 推荐场景 |
|------|------|------|------|----------|
| tiny | ~40MB | 最快 | 较低 | 快速预览、实时字幕 |
| base | ~75MB | 快 | 中等 | 一般歌词识别 |
| small | ~250MB | 中等 | 良好 | 高质量歌词（推荐） |
| medium | ~770MB | 慢 | 很好 | 专业级识别 |
| large-v3 | ~1.5GB | 最慢 | 最佳 | 最高精度要求 |

默认情况下，SDK 会根据设备性能自动选择推荐模型。

## 性能优化

### 1. 模型缓存

模型首次下载后会缓存到：
```
~/Library/Caches/huggingface/
```

后续使用无需重新下载。

### 2. 内存管理

识别完成后可以清理模型：

```swift
recognizer.cleanup()
```

### 3. 分段识别

对于长音频，可以分段识别以减少内存占用：

```swift
// 识别前 30 秒
let samples = try decodeAudioSegment(url: url, duration: 30)
let result = try await recognizer.recognize(samples: samples, config: config)
```

## 错误处理

```swift
do {
    let result = try await recognizer.recognize(url: url)
} catch LyricRecognizerError.backendNotReady {
    print("模型未加载，请先调用 prepare()")
} catch LyricRecognizerError.cannotOpenInput {
    print("无法打开音频文件")
} catch LyricRecognizerError.noAudioStream {
    print("文件中没有音频流")
} catch {
    print("识别失败: \(error)")
}
```

## 支持的音频格式

通过 FFmpeg 解码，支持所有常见格式：

- MP3, AAC, FLAC, WAV, OGG
- M4A, WMA, OPUS, APE
- 网络流（HTTP/HTTPS）
- 本地文件

## 注意事项

1. **首次使用**：首次调用会下载模型文件（几十 MB 到 1.5GB），需要网络连接
2. **网络环境**：模型从 Hugging Face 下载，国内网络可能较慢或超时，建议使用稳定网络环境
3. **内存占用**：large 模型需要较大内存，建议在 iPhone 12 及以上设备使用
4. **识别精度**：背景音乐较强的歌曲可能影响识别精度
5. **语言检测**：自动检测可能不准确，建议手动指定语言
6. **时间戳精度**：逐字时间戳精度约 ±0.1 秒

## 常见问题

### 代码签名警告（NOT_CODESIGNED）

在开发环境中可能看到类似警告：
```
container_query_get_single_result: error = 2→(98) NOT_CODESIGNED
```

这是因为：
1. 示例项目为了简化配置禁用了代码签名
2. WhisperKit 尝试访问共享容器时会产生此警告
3. **不影响核心功能**，模型会下载到应用沙盒目录

如需消除警告，在 `Example/project.yml` 中启用代码签名：
```yaml
settings:
  base:
    CODE_SIGN_IDENTITY: "Apple Development"
    CODE_SIGNING_REQUIRED: "YES"
    CODE_SIGNING_ALLOWED: "YES"
    DEVELOPMENT_TEAM: "YOUR_TEAM_ID"  # 填入你的开发团队 ID
```

### 模型下载超时

如果遇到 "请求超时" 或 "downloadError" 错误：

1. **检查网络连接**：确保设备连接到稳定的网络
2. **使用 WiFi**：避免使用移动数据，模型文件较大
3. **重试下载**：点击"下载模型"按钮重试
4. **手动下载**（高级）：
   ```bash
   # 在 Mac 上预先下载模型到缓存目录
   # 模型会缓存到: ~/Library/Caches/huggingface/
   # 然后通过 Xcode 部署到模拟器/设备
   ```

### 识别失败

如果识别过程中出错：

1. **检查音频格式**：确保音频文件可以正常播放
2. **检查 URL**：确认 URL 可访问（本地文件或网络流）
3. **查看错误信息**：根据具体错误提示排查问题
4. **尝试其他模型**：如果 base 模型失败，可以尝试 tiny 模型

### 识别精度不理想

1. **指定语言**：手动设置 `config.language` 而不是自动检测
2. **使用更大模型**：从 tiny → base → small → medium 逐步尝试
3. **音频质量**：使用高质量音频源，避免背景噪音过大
4. **调整音频**：可以先用 AudioEffects 降噪、增强人声后再识别

## 最佳实践

1. **预加载模型**：在应用启动时调用 `prepare()` 预加载模型
2. **指定语言**：已知语言时手动指定，提高识别速度和精度
3. **选择合适模型**：根据设备性能和精度要求选择模型
4. **显示进度**：使用进度回调提供用户反馈
5. **错误处理**：妥善处理网络错误和识别失败

## 示例代码

完整示例请参考：
- `Example/FFmpegDemo/Sources/PlayerViewModel.swift` - ViewModel 集成
- `Example/FFmpegDemo/Sources/ContentView.swift` - UI 集成
- `test_lyric_recognition.swift` - 命令行测试

## 技术细节

### 音频预处理

识别前会自动将音频转换为 Whisper 要求的格式：
- 采样率：16kHz
- 声道：单声道
- 格式：Float32 PCM

### 识别流程

1. FFmpeg 解码音频 → 16kHz 单声道 PCM
2. WhisperKit 语音识别 → 文本 + 时间戳
3. 转换为 RecognizedLyric 数据模型
4. 可选：转换为 LyricLine 或导出 LRC

## 相关文档

- [WhisperKit 官方文档](https://github.com/argmaxinc/WhisperKit)
- [LyricSyncer 使用指南](./LYRIC_SYNC.md)
- [FFmpeg 音频功能](./FFMPEG_AUDIO_FEATURES.md)
