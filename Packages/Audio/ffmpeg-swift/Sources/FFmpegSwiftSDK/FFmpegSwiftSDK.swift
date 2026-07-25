// FFmpegSwiftSDK.swift
// FFmpegSwiftSDK
//
// FFmpeg Swift SDK 模块入口。
//
// 本 SDK 将 FFmpeg C 库封装为 Swift 友好的 API，提供流媒体播放、
// 音频均衡器、50+ 种音频效果、音频分析、文件处理等功能。
//
// ## 公开 API
//
// ### 播放器
// - ``StreamPlayer``          — 主播放器类：连接、播放、暂停、恢复、停止、Seek、A-B 循环。
// - ``StreamPlayerDelegate``  — 播放状态、错误、时长回调代理协议。
// - ``PlaybackState``         — 播放状态枚举（idle、connecting、playing、paused、stopped、error）。
//
// ### 音频均衡器
// - ``AudioEqualizer``        — 10 段 EQ，31Hz ~ 16kHz 频段增益控制。
// - ``EQBand``                — 频段枚举。
// - ``EQBandGain``            — 增益设置结构体，自动钳位到 [-12, +12] dB。
//
// ### 音频效果（50+ 种）
// - ``AudioEffects``          — 音频效果控制器，提供以下效果：
//   - 基础：音量控制
//   - 动态：响度标准化、夜间模式（动态压缩）、限幅器、噪声门、自动增益
//   - 速度音调：变速不变调、变调不变速
//   - 频率：低音、高音、超低音增强、带通/带阻滤波
//   - 空间：环绕增强、混响、立体声宽度、声道平衡、单声道、声道交换
//   - 时间：淡入淡出、延迟
//   - 特效：人声消除（卡拉OK）、合唱、镶边、颤音、颤抖、失真（Lo-Fi）、电话/水下/收音机效果
//
// ### 音频可视化
// - ``SpectrumAnalyzer``      — 实时 FFT 频谱分析器，输出频率幅度数据供 UI 绘制。
// - ``WaveformGenerator``     — 波形预览生成器，解码整首歌生成波形缩略图数据。
//
// ### 元数据
// - ``MetadataReader``        — 读取 ID3 标签、专辑封面、艺术家等元数据。
// - ``AudioMetadata``         — 元数据结构体。
//
// ### 歌词同步
// - ``LyricSyncer``           — 实时歌词同步引擎，LRC 解析 + 时间对准。
// - ``LyricParser``           — LRC 格式解析器（标准/增强/多时间标签）。
// - ``LyricLine``             — 歌词行数据（时间、文字、逐字、翻译）。
// - ``LyricWord``             — 逐字歌词数据（起止时间 + 文字）。
// - ``LyricMetadata``         — LRC 文件元信息（标题、艺术家等）。
//
// ### 音频分析
// - ``AudioAnalyzer``         — 音频分析器，提供以下功能：
//   - 静音检测：检测音频中的静音片段
//   - BPM 检测：检测歌曲节拍速度
//   - 峰值检测：检测音频峰值电平
//   - 响度测量：测量 LUFS 响度
//   - 削波检测：检测数字削波
//
// ### 音频处理
// - ``AudioProcessor``        — 音频文件处理器，提供以下功能：
//   - 音频转码：格式转换（MP3→AAC 等）
//   - 音频裁剪：截取指定时间段
//   - 音频信息：获取文件时长、采样率、比特率等
//
// ### 模型
// - ``StreamInfo``            — 媒体流元数据（编解码器、分辨率、时长）。
// - ``VideoFrame``            — 解码后的视频帧（CVPixelBuffer + 时间信息）。
// - ``AudioBuffer``           — 解码后的音频缓冲区。
//
// ### 错误
// - ``FFmpegError``           — 统一错误类型，将 FFmpeg C 错误码映射为 Swift 错误。
//
// ## 快速开始
//
// ```swift
// import FFmpegSwiftSDK
//
// let player = StreamPlayer()
// player.delegate = self
// player.play(url: "https://example.com/music.mp3")
//
// // 10 段 EQ
// player.equalizer.setGain(band: .hz63, gain: 6.0)
//
// // 音频效果
// player.audioEffects.setTempo(1.25)           // 1.25x 倍速
// player.audioEffects.setPitch(2)              // 升 2 个半音
// player.audioEffects.setVocalRemoval(0.8)     // 人声消除
// player.audioEffects.setNightModeEnabled(true) // 夜间模式
//
// // 频谱可视化
// player.spectrumAnalyzer.onSpectrum = { magnitudes in
//     // 更新 UI
// }
//
// // 歌词同步
// player.lyricSyncer.load(lrcContent: lrcString)
// player.lyricSyncer.onSync = { index, line, wordIndex, progress in
//     // 高亮当前行
// }
//
// // 播放控制
// player.pause()
// player.resume()
// player.seek(to: 60.0)
// player.stop()
// ```

import Foundation
