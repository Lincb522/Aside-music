# 需求文档

## 简介

本文档描述了在 AsideMusic 音乐播放器应用中全面集成 AudioKit 框架的需求。目标是使用 AudioKit 完全替代现有的 AVPlayer 音频播放方案，实现更强大的音频处理能力，包括 EQ 均衡器、混响、压缩等音频效果，同时解决之前因 MainActor 线程问题导致的崩溃问题。

## 术语表

- **AudioKit**: 一个强大的 Swift 音频合成、处理和分析框架
- **AudioKit_Engine**: AudioKit 音频引擎，负责管理整个音频处理链
- **AudioKit_Player**: AudioKit 的音频播放器，替代 AVPlayer
- **EQ (Equalizer)**: 均衡器，用于调整不同频段音频信号的增益
- **Reverb**: 混响效果，模拟声音在空间中的反射
- **Compressor**: 压缩器，用于控制音频的动态范围
- **Audio_Node**: 音频节点，AudioKit 中的音频处理单元
- **Effect_Chain**: 效果链，多个音频效果串联处理
- **Preset**: 预设，预定义的效果参数配置
- **Band**: 频段，EQ 中的单个频率调节点
- **Gain**: 增益，音频信号的放大或衰减量（单位：dB）
- **Bypass**: 旁通，临时禁用音频效果处理

## 需求

### 需求 1：AudioKit 框架集成与项目配置

**用户故事：** 作为开发者，我希望将 AudioKit 框架完整集成到项目中，以便使用其全部音频处理能力。

#### 验收标准

1. THE Package_Manager SHALL 通过 Swift Package Manager 添加 AudioKit 核心依赖
2. THE Package_Manager SHALL 添加 AudioKitEX 扩展包以支持高级音频效果
3. THE Package_Manager SHALL 添加 SoundpipeAudioKit 以支持更多音频效果
4. THE AudioKit_Engine SHALL 在应用启动时正确初始化
5. WHEN 应用进入后台时，THE AudioKit_Engine SHALL 保持音频处理正常运行
6. WHEN 音频会话被中断时，THE AudioKit_Engine SHALL 正确处理中断并在恢复时继续工作

### 需求 2：AudioKit 播放器替代 AVPlayer

**用户故事：** 作为用户，我希望音乐播放使用 AudioKit 引擎，以获得更好的音频处理能力和稳定性。

#### 验收标准

1. THE AudioKit_Player SHALL 完全替代现有的 AVPlayer 进行音频播放
2. THE AudioKit_Player SHALL 支持从 URL 加载和播放音频流
3. THE AudioKit_Player SHALL 支持播放、暂停、停止操作
4. THE AudioKit_Player SHALL 支持进度跳转（seek）操作
5. THE AudioKit_Player SHALL 提供当前播放时间和总时长信息
6. THE AudioKit_Player SHALL 支持播放完成回调以实现自动播放下一首
7. WHEN 播放新歌曲时，THE AudioKit_Player SHALL 平滑切换而不产生爆音
8. THE AudioKit_Player SHALL 支持多种音频格式（MP3、AAC、FLAC 等）

### 需求 3：EQ 均衡器功能

**用户故事：** 作为用户，我希望能够调整音乐的频率响应，以获得更好的听觉体验。

#### 验收标准

1. THE EQ_Processor SHALL 提供至少 10 个可调节的频段
2. WHEN 用户调整某个频段的增益时，THE EQ_Processor SHALL 实时应用该变化到音频输出
3. THE EQ_Processor SHALL 支持 -12dB 到 +12dB 的增益调节范围
4. THE EQ_Processor SHALL 覆盖 20Hz 到 20kHz 的完整可听频率范围
5. WHEN EQ 参数发生变化时，THE EQ_Processor SHALL 平滑过渡以避免音频爆音
6. THE EQ_Processor SHALL 提供 Bypass 开关功能

### 需求 4：混响效果功能

**用户故事：** 作为用户，我希望能够为音乐添加混响效果，以获得更丰富的空间感。

#### 验收标准

1. THE Reverb_Processor SHALL 提供可调节的混响效果
2. THE Reverb_Processor SHALL 支持调节混响的干湿比（Dry/Wet Mix）
3. THE Reverb_Processor SHALL 支持调节混响时间（Decay Time）
4. THE Reverb_Processor SHALL 支持调节房间大小参数
5. THE Reverb_Processor SHALL 提供多种混响预设（如：小房间、大厅、教堂等）
6. THE Reverb_Processor SHALL 提供 Bypass 开关功能

### 需求 5：压缩器效果功能

**用户故事：** 作为用户，我希望能够使用压缩器来控制音频的动态范围，使音量更加均衡。

#### 验收标准

1. THE Compressor_Processor SHALL 提供动态范围压缩功能
2. THE Compressor_Processor SHALL 支持调节阈值（Threshold）参数
3. THE Compressor_Processor SHALL 支持调节压缩比（Ratio）参数
4. THE Compressor_Processor SHALL 支持调节启动时间（Attack）参数
5. THE Compressor_Processor SHALL 支持调节释放时间（Release）参数
6. THE Compressor_Processor SHALL 提供 Bypass 开关功能

### 需求 6：效果链管理

**用户故事：** 作为用户，我希望能够灵活管理多个音频效果的组合和顺序。

#### 验收标准

1. THE Effect_Chain SHALL 支持串联多个音频效果处理器
2. THE Effect_Chain SHALL 允许用户独立开关每个音频效果
3. THE Effect_Chain SHALL 支持调整效果的处理顺序
4. WHEN 效果链配置改变时，THE Effect_Chain SHALL 平滑过渡以避免音频中断
5. THE Effect_Chain SHALL 将用户的效果配置持久化存储
6. WHEN 应用重新启动时，THE Effect_Chain SHALL 恢复用户上次的效果配置

### 需求 7：预设管理系统

**用户故事：** 作为用户，我希望能够使用和管理预设配置，以便快速切换不同的音效设置。

#### 验收标准

1. THE Preset_Manager SHALL 为 EQ 提供至少 8 种内置预设（流行、摇滚、古典、爵士、电子、人声、低音增强、高音增强）
2. THE Preset_Manager SHALL 为混响提供至少 5 种内置预设
3. WHEN 用户选择一个预设时，THE Preset_Manager SHALL 立即应用该预设的参数
4. THE Preset_Manager SHALL 允许用户创建和保存自定义预设
5. THE Preset_Manager SHALL 允许用户删除自定义预设
6. THE Preset_Manager SHALL 将用户的预设持久化存储到本地

### 需求 8：音频效果用户界面

**用户故事：** 作为用户，我希望有一个直观的界面来调整所有音频效果设置。

#### 验收标准

1. THE Audio_Effects_View SHALL 提供 EQ 调节界面，显示所有频段的可视化滑块
2. THE Audio_Effects_View SHALL 提供混响调节界面
3. THE Audio_Effects_View SHALL 提供压缩器调节界面
4. THE Audio_Effects_View SHALL 显示当前选中的预设名称
5. WHEN 用户调整参数时，THE Audio_Effects_View SHALL 实时显示当前值
6. THE Audio_Effects_View SHALL 提供一键重置功能
7. THE Audio_Effects_View SHALL 提供全局效果开关
8. THE Audio_Effects_View SHALL 与应用现有的视觉风格保持一致

### 需求 9：线程安全与性能

**用户故事：** 作为用户，我希望音频处理功能稳定运行，不会导致应用崩溃或卡顿。

#### 验收标准

1. THE AudioKit_Engine SHALL 在专用的音频线程上执行所有音频处理操作
2. THE AudioKit_Engine SHALL 避免在 MainActor 上执行耗时的音频操作
3. WHEN 音频参数需要更新时，THE AudioKit_Engine SHALL 使用线程安全的方式传递参数
4. THE AudioKit_Engine SHALL 在音频处理过程中保持低延迟（小于 50ms）
5. IF 音频引擎发生错误，THEN THE AudioKit_Engine SHALL 优雅降级并记录错误日志
6. THE AudioKit_Engine SHALL 正确管理内存，避免音频缓冲区泄漏

### 需求 10：系统集成与兼容性

**用户故事：** 作为用户，我希望 AudioKit 播放器能够与系统功能无缝集成。

#### 验收标准

1. THE AudioKit_Player SHALL 支持后台播放
2. THE AudioKit_Player SHALL 支持锁屏控制（播放/暂停/上一首/下一首）
3. THE AudioKit_Player SHALL 支持控制中心的 Now Playing 信息显示
4. THE AudioKit_Player SHALL 与 AirPlay 音频输出兼容
5. THE AudioKit_Player SHALL 与蓝牙音频设备兼容
6. WHEN 音频输出设备改变时，THE AudioKit_Player SHALL 自动适应新设备
7. THE AudioKit_Player SHALL 正确处理音频会话中断（如来电）
