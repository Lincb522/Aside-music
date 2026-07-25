# FFmpeg 音频功能完整列表

本文档列出了 FFmpegSwiftSDK 提供的所有音频功能。

---

## 📊 功能总览

| 分类 | 数量 |
|------|------|
| 基础播放控制 | 6 |
| 音量与动态处理 | 6 |
| 速度与音调 | 2 |
| 均衡器与频率 | 6 |
| 空间效果 | 6 |
| 时间效果 | 3 |
| 特殊效果 | 10 |
| 音频分析 | 8 |
| 歌曲识别 | 4 |
| 文件处理 | 6 |
| 歌词同步 | 4 |
| 可视化 | 2 |
| **总计** | **63** |

---

## ✅ 全部功能

### 1. 基础播放控制

| 功能 | API | 说明 |
|------|-----|------|
| 播放/暂停/停止 | `play()` / `pause()` / `stop()` | 基础播放控制 |
| Seek 跳转 | `seek(to:)` | 精确跳转到指定时间 |
| 无缝切歌 | `prepareNext()` | Gapless Playback，预加载下一首 |
| 音质切换 | `switchToNext(seekTo:)` | 不中断播放切换音源 |
| A-B 循环 | `setABLoop(pointA:pointB:)` | 区间循环播放 |
| 播放状态 | `state` / `currentTime` | 状态监听与进度获取 |

### 2. 音量与动态处理

| 功能 | API | FFmpeg 滤镜 | 说明 |
|------|-----|-------------|------|
| 音量控制 | `setVolume(_:)` | `volume` | 增益/衰减，单位 dB |
| 响度标准化 | `setLoudnormEnabled(_:)` | `loudnorm` | EBU R128 标准 |
| 夜间模式 | `setNightModeEnabled(_:)` | `acompressor` | 动态压缩 |
| 限幅器 | `setLimiterEnabled(_:)` | `alimiter` | 防止削波失真 |
| 噪声门 | `setGateEnabled(_:)` | `agate` | 低于阈值静音 |
| 自动增益 | `setAutoGainEnabled(_:)` | `dynaudnorm` | 动态标准化 |

### 3. 速度与音调

| 功能 | API | FFmpeg 滤镜 | 说明 |
|------|-----|-------------|------|
| 变速不变调 | `setTempo(_:)` | `atempo` | 0.5x ~ 4.0x |
| 变调不变速 | `setPitch(_:)` | `asetrate` + `atempo` | ±12 半音 |

### 4. 均衡器与频率

| 功能 | API | FFmpeg 滤镜 | 说明 |
|------|-----|-------------|------|
| 10 段 EQ | `equalizer.setGain(band:gain:)` | `equalizer` | 31Hz ~ 16kHz |
| 低音增强 | `setBassGain(_:)` | `bass` | 低频搁架滤波 |
| 高音增强 | `setTrebleGain(_:)` | `treble` | 高频搁架滤波 |
| 超低音增强 | `setSubboostEnabled(_:)` | `asubboost` | 100Hz 以下 |
| 带通滤波 | `setBandpassEnabled(_:)` | `bandpass` | 只保留指定频率 |
| 带阻滤波 | `setBandrejectEnabled(_:)` | `bandreject` | 去除指定频率 |

### 5. 空间效果

| 功能 | API | FFmpeg 滤镜 | 说明 |
|------|-----|-------------|------|
| 环绕增强 | `setSurroundLevel(_:)` | `extrastereo` | 立体声分离度 |
| 混响效果 | `setReverbLevel(_:)` | `aecho` | 房间混响 |
| 立体声宽度 | `setStereoWidth(_:)` | `stereotools` | 0~2，1=原始 |
| 声道平衡 | `setChannelBalance(_:)` | `pan` | -1=左，+1=右 |
| 单声道 | `setMonoEnabled(_:)` | `pan` | 立体声→单声道 |
| 声道交换 | `setChannelSwapEnabled(_:)` | `pan` | 左右互换 |

### 6. 时间效果

| 功能 | API | FFmpeg 滤镜 | 说明 |
|------|-----|-------------|------|
| 淡入 | `setFadeIn(duration:)` | `afade` | 开头渐变 |
| 淡出 | `setFadeOut(duration:startTime:)` | `afade` | 结尾渐变 |
| 延迟 | `setDelay(_:)` | `adelay` | 声道延迟 |

### 7. 特殊效果

| 功能 | API | FFmpeg 滤镜 | 说明 |
|------|-----|-------------|------|
| 人声消除 | `setVocalRemoval(_:)` | `stereotools` | 卡拉OK 模式 |
| 合唱效果 | `setChorusEnabled(_:)` | `chorus` | 多声部叠加 |
| 镶边效果 | `setFlangerEnabled(_:)` | `flanger` | 金属感 |
| 颤音效果 | `setTremoloEnabled(_:)` | `tremolo` | 音量周期变化 |
| 颤抖效果 | `setVibratoEnabled(_:)` | `vibrato` | 音调周期变化 |
| 失真效果 | `setLoFiEnabled(_:)` | `acrusher` | Lo-Fi 复古 |
| 电话效果 | `setTelephoneEnabled(_:)` | `bandpass` | 模拟电话 |
| 水下效果 | `setUnderwaterEnabled(_:)` | `lowpass` + `aecho` | 模拟水下 |
| 收音机效果 | `setRadioEnabled(_:)` | `bandpass` + `acrusher` | 老式收音机 |
| 交叉淡入淡出 | `setCrossfadeDuration(_:)` | `afade` | DJ 混音 |

### 8. 音频分析

| 功能 | API | 说明 |
|------|-----|------|
| 静音检测 | `AudioAnalyzer.detectSilence()` | 检测静音片段 |
| BPM 检测 | `AudioAnalyzer.detectBPM()` | 检测节拍速度 |
| 峰值检测 | `AudioAnalyzer.detectPeak()` | 检测峰值电平 |
| 响度测量 | `AudioAnalyzer.measureLoudness()` | LUFS 响度 |
| 削波检测 | `AudioAnalyzer.detectClipping()` | 检测数字削波 |
| 相位检测 | `AudioAnalyzer.detectPhase()` | 检测立体声相位问题 |
| 频率分析 | `AudioAnalyzer.analyzeFrequency()` | 主频率、频谱质心、频段能量 |
| 动态范围 | `AudioAnalyzer.analyzeDynamicRange()` | 动态范围、波峰因数 |

### 9. 歌曲识别（音频指纹）

| 功能 | API | 说明 |
|------|-----|------|
| 生成指纹 | `AudioFingerprint.generate()` | 从音频生成指纹 |
| 比较指纹 | `AudioFingerprint.compare()` | 计算两个指纹相似度 |
| 搜索匹配 | `AudioFingerprint.search()` | 在数据库中搜索 |
| 指纹数据库 | `FingerprintDatabase` | 存储、检索、识别歌曲 |

### 10. 文件处理

| 功能 | API | 说明 |
|------|-----|------|
| 音频转码 | `AudioProcessor.transcode()` | MP3→AAC 等 |
| 音频裁剪 | `AudioProcessor.trim()` | 截取片段 |
| 音频拼接 | `AudioProcessor.concatenate()` | 多文件合并 |
| 重采样 | `AudioProcessor.resample()` | 改变采样率 |
| 声道转换 | `AudioProcessor.convertChannels()` | 立体声↔单声道 |
| 提取音频 | `AudioProcessor.extractAudio()` | 从视频提取音频 |
| 获取信息 | `AudioProcessor.getAudioInfo()` | 时长、采样率等 |

### 11. 歌词同步

| 功能 | API | 说明 |
|------|-----|------|
| LRC 解析 | `lyricSyncer.load(lrcContent:)` | 标准/增强 LRC |
| 实时同步 | `lyricSyncer.onSync` | 当前行、逐字进度 |
| 时间偏移 | `lyricSyncer.setOffset(_:)` | 歌词提前/延后 |
| 双语歌词 | 自动合并 | 同时间戳多行合并 |

### 12. 可视化

| 功能 | API | 说明 |
|------|-----|------|
| 实时频谱 | `spectrumAnalyzer` | FFT 频率幅度 |
| 波形预览 | `waveformGenerator` | 整首歌波形数据 |

---

## � 使用示例

### 基础播放

```swift
import FFmpegSwiftSDK

let player = StreamPlayer()
player.delegate = self
player.play(url: "https://example.com/music.mp3")

// 播放控制
player.pause()
player.resume()
player.seek(to: 60.0)
player.stop()
```

### 音频效果

```swift
// 音量 +3dB
player.audioEffects.setVolume(3.0)

// 1.25x 倍速
player.audioEffects.setTempo(1.25)

// 升 2 个半音
player.audioEffects.setPitch(2)

// 夜间模式（动态压缩）
player.audioEffects.setNightModeEnabled(true)

// 人声消除（卡拉OK）
player.audioEffects.setVocalRemoval(0.8)

// 环绕增强
player.audioEffects.setSurroundLevel(0.5)

// 混响
player.audioEffects.setReverbLevel(0.3)

// 电话效果
player.audioEffects.setTelephoneEnabled(true)

// 水下效果
player.audioEffects.setUnderwaterEnabled(true)
```

### 均衡器

```swift
// 10 段 EQ
player.equalizer.setGain(band: .hz63, gain: 6.0)
player.equalizer.setGain(band: .hz1k, gain: -3.0)

// 低音/高音
player.audioEffects.setBassGain(6.0)
player.audioEffects.setTrebleGain(-3.0)
```

### 频谱可视化

```swift
player.spectrumAnalyzer.isEnabled = true
player.spectrumAnalyzer.onSpectrum = { magnitudes in
    // magnitudes: [Float]，频率幅度数组
    // 更新 UI 绑定
}
```

### 歌词同步

```swift
player.lyricSyncer.load(lrcContent: lrcString)
player.lyricSyncer.onSync = { index, line, wordIndex, progress in
    // index: 当前行索引
    // line: LyricLine 对象
    // wordIndex: 逐字索引（增强 LRC）
    // progress: 当前行进度 0~1
}
```

### 音频分析

```swift
// 静音检测
let silences = AudioAnalyzer.detectSilence(
    samples: audioSamples,
    sampleRate: 44100,
    threshold: -50.0,
    minDuration: 0.5
)

// BPM 检测
let bpmResult = AudioAnalyzer.detectBPM(
    samples: audioSamples,
    sampleRate: 44100
)
print("BPM: \(bpmResult.bpm), 置信度: \(bpmResult.confidence)")

// 峰值检测
let peakResult = AudioAnalyzer.detectPeak(
    samples: audioSamples,
    sampleRate: 44100
)
print("峰值: \(peakResult.peakDB) dB, 削波: \(peakResult.isClipping)")

// 相位检测（立体声）
let phaseResult = AudioAnalyzer.detectPhase(
    samples: stereoSamples,
    sampleRate: 44100
)
print("相位相关性: \(phaseResult.correlation), \(phaseResult.description)")

// 频率分析
let freqAnalysis = AudioAnalyzer.analyzeFrequency(
    samples: audioSamples,
    sampleRate: 44100
)
print("主频率: \(freqAnalysis.dominantFrequency) Hz")
print("频谱质心: \(freqAnalysis.spectralCentroid) Hz")
print("低/中/高频能量: \(freqAnalysis.lowEnergyRatio)/\(freqAnalysis.midEnergyRatio)/\(freqAnalysis.highEnergyRatio)")

// 动态范围分析
let dynamicRange = AudioAnalyzer.analyzeDynamicRange(
    samples: audioSamples,
    sampleRate: 44100
)
print("动态范围: \(dynamicRange.dynamicRange) dB")
print("波峰因数: \(dynamicRange.crestFactor) dB")
```

### 歌曲识别（音频指纹）

```swift
// 从音频采样生成指纹
let fingerprint = AudioFingerprint.generate(
    samples: audioSamples,
    sampleRate: 44100
)

// 从文件生成指纹（只取前 10 秒）
let fingerprint = try AudioFingerprint.generate(
    from: audioURL,
    duration: 10.0
)

// 比较两个指纹的相似度
let similarity = AudioFingerprint.compare(fingerprint1, fingerprint2)
print("相似度: \(similarity * 100)%")

// 使用指纹数据库识别歌曲
let database = FingerprintDatabase()

// 添加歌曲到数据库
database.add(entry: FingerprintDatabase.Entry(
    id: "song-001",
    title: "Shape of You",
    artist: "Ed Sheeran",
    fingerprint: fingerprint
))

// 识别未知音频
if let result = database.recognize(samples: unknownSamples, sampleRate: 44100) {
    print("识别结果: \(result.title) - \(result.artist)")
    print("匹配分数: \(result.score), 置信度: \(result.confidence)")
}

// 导出/导入数据库
let data = try database.export()
try database.importData(data)
```

### 文件处理

```swift
let processor = AudioProcessor()

// 转码
try await processor.transcode(
    inputURL: inputURL,
    outputURL: outputURL,
    config: .init(format: .aac, bitrate: 256000)
) { progress in
    print("进度: \(progress * 100)%")
}

// 裁剪
try await processor.trim(
    inputURL: inputURL,
    outputURL: outputURL,
    config: .init(startTime: 10.0, endTime: 30.0, fadeIn: 1.0, fadeOut: 1.0)
)

// 拼接多个文件
try await processor.concatenate(
    inputURLs: [url1, url2, url3],
    outputURL: outputURL
)

// 重采样
try await processor.resample(
    inputURL: inputURL,
    outputURL: outputURL,
    targetSampleRate: 48000
)

// 声道转换（立体声→单声道）
try await processor.convertChannels(
    inputURL: inputURL,
    outputURL: outputURL,
    targetChannels: 1
)

// 从视频提取音频
try await processor.extractAudio(
    inputURL: videoURL,
    outputURL: audioURL,
    format: .aac
)

// 获取信息
let info = try processor.getAudioInfo(url: audioURL)
print("时长: \(info.duration)s, 采样率: \(info.sampleRate), 编码: \(info.codecName)")
```

---

## � 参考资料

- [FFmpeg Audio Filters 官方文档](https://ffmpeg.org/ffmpeg-filters.html#Audio-Filters)
- [FFmpeg Filter Graph 教程](https://trac.ffmpeg.org/wiki/FilteringGuide)
- [EBU R128 响度标准](https://tech.ebu.ch/docs/r/r128.pdf)

---

## 📌 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 0.13.0 | 2025-02 | 新增歌曲识别（音频指纹）、相位检测、频率分析、动态范围分析、文件拼接/重采样/声道转换/提取音频 |
| 0.12.0 | 2025-02 | 新增 50+ 音频效果、音频分析、文件处理、歌词同步 |
| 0.11.0 | 2025-01 | 初始版本 |

