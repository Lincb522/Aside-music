# 实现计划: AudioKit 集成

## 概述

本计划将 AudioKit 框架全面集成到 AsideMusic 应用中，实现 EQ 均衡器、混响、压缩器等音频效果功能。采用增量开发方式，每个任务都建立在前一个任务的基础上。

## 任务

- [x] 1. 项目配置和依赖添加
  - [x] 1.1 更新 Package.swift 添加 AudioKit 依赖
    - 添加 AudioKit 核心包
    - 添加 SoundpipeAudioKit 效果包
    - 配置平台要求 iOS 17+
    - _需求: 1.1, 1.2, 1.3_

- [-] 2. 核心音频引擎实现
  - [x] 2.1 创建 AudioKitManager 基础结构
    - 创建 `Sources/AsideMusic/Audio/AudioKitManager.swift`
    - 实现 AudioEngine 初始化和生命周期管理
    - 实现 startEngine() 和 stopEngine() 方法
    - 配置音频会话
    - _需求: 1.4, 1.5, 1.6_
  
  - [ ] 2.2 编写 AudioKitManager 单元测试
    - 测试引擎启动和停止
    - _需求: 1.4_

- [ ] 3. EQ 均衡器实现
  - [x] 3.1 创建 EQProcessor 处理器
    - 创建 `Sources/AsideMusic/Audio/Effects/EQProcessor.swift`
    - 实现 10 频段参数均衡器
    - 实现增益调节（-12dB 到 +12dB）
    - 实现 bypass 开关
    - _需求: 3.1, 3.2, 3.3, 3.4, 3.6_
  
  - [ ] 3.2 编写 EQ 参数 round-trip 属性测试
    - **Property 4: 音频效果参数 Round-Trip**
    - **验证: 需求 3.2, 3.3**
  
  - [ ] 3.3 编写 EQ bypass 状态切换属性测试
    - **Property 5: 效果 Bypass 状态切换**
    - **验证: 需求 3.6**

- [ ] 4. 混响效果实现
  - [x] 4.1 创建 ReverbProcessor 处理器
    - 创建 `Sources/AsideMusic/Audio/Effects/ReverbProcessor.swift`
    - 实现混响效果节点
    - 实现干湿比、衰减时间、房间大小参数
    - 实现 bypass 开关
    - _需求: 4.1, 4.2, 4.3, 4.4, 4.6_
  
  - [ ] 4.2 编写混响参数 round-trip 属性测试
    - **Property 4: 音频效果参数 Round-Trip**
    - **验证: 需求 4.2, 4.3, 4.4**

- [ ] 5. 压缩器效果实现
  - [x] 5.1 创建 CompressorProcessor 处理器
    - 创建 `Sources/AsideMusic/Audio/Effects/CompressorProcessor.swift`
    - 实现动态范围压缩器
    - 实现阈值、压缩比、启动/释放时间参数
    - 实现 bypass 开关
    - _需求: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  
  - [ ] 5.2 编写压缩器参数 round-trip 属性测试
    - **Property 4: 音频效果参数 Round-Trip**
    - **验证: 需求 5.2, 5.3, 5.4, 5.5**

- [ ] 6. 检查点 - 确保所有效果处理器测试通过
  - 确保所有测试通过，如有问题请询问用户。

- [ ] 7. 效果链管理实现
  - [x] 7.1 创建 EffectChainManager
    - 创建 `Sources/AsideMusic/Audio/EffectChainManager.swift`
    - 实现效果节点串联
    - 实现效果独立开关
    - 实现效果顺序调整
    - _需求: 6.1, 6.2, 6.3_
  
  - [ ] 7.2 编写效果链顺序管理属性测试
    - **Property 6: 效果链顺序管理**
    - **验证: 需求 6.3**
  
  - [ ] 7.3 实现效果链配置持久化
    - 创建 EffectChainConfiguration 数据模型
    - 实现 saveConfiguration() 和 loadConfiguration()
    - 使用 UserDefaults 或文件存储
    - _需求: 6.5, 6.6_
  
  - [ ] 7.4 编写效果链配置持久化 round-trip 属性测试
    - **Property 7: 效果链配置持久化 Round-Trip**
    - **验证: 需求 6.5, 6.6**

- [ ] 8. 预设系统实现
  - [x] 8.1 创建预设数据模型
    - 创建 `Sources/AsideMusic/Audio/Presets/EQPreset.swift`
    - 创建 `Sources/AsideMusic/Audio/Presets/ReverbPreset.swift`
    - 定义内置 EQ 预设（流行、摇滚、古典、爵士、电子、人声、低音增强、高音增强）
    - 定义内置混响预设（小房间、中型大厅、大型大厅、教堂、录音室）
    - _需求: 7.1, 7.2_
  
  - [x] 8.2 创建 PresetManager
    - 创建 `Sources/AsideMusic/Audio/Presets/PresetManager.swift`
    - 实现预设加载和应用
    - 实现自定义预设创建和删除
    - 实现预设持久化存储
    - _需求: 7.3, 7.4, 7.5, 7.6_
  
  - [ ] 8.3 编写预设应用一致性属性测试
    - **Property 8: 预设应用一致性**
    - **验证: 需求 7.3**
  
  - [ ] 8.4 编写预设管理 round-trip 属性测试
    - **Property 9: 预设管理 Round-Trip**
    - **验证: 需求 7.4, 7.5, 7.6**

- [ ] 9. 检查点 - 确保预设系统测试通过
  - 确保所有测试通过，如有问题请询问用户。

- [ ] 10. 与 PlayerManager 集成
  - [ ] 10.1 修改 PlayerManager 集成 AudioKit
    - 在 PlayerManager 中初始化 AudioKitManager
    - 将 AVPlayer 音频路由到 AudioKit 效果链
    - 保持现有播放控制接口不变
    - _需求: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  
  - [ ] 10.2 编写播放器状态转换属性测试
    - **Property 1: 播放器状态转换一致性**
    - **验证: 需求 2.3**
  
  - [ ] 10.3 编写 Seek 操作准确性属性测试
    - **Property 2: Seek 操作准确性**
    - **验证: 需求 2.4**
  
  - [ ] 10.4 编写时间信息有效性属性测试
    - **Property 3: 时间信息有效性**
    - **验证: 需求 2.5**

- [ ] 11. 系统集成
  - [ ] 11.1 实现后台播放和锁屏控制
    - 配置音频会话后台模式
    - 集成 MPRemoteCommandCenter
    - 更新 Now Playing 信息
    - _需求: 10.1, 10.2, 10.3_
  
  - [ ] 11.2 实现音频设备切换处理
    - 监听音频路由变化通知
    - 处理 AirPlay 和蓝牙设备切换
    - _需求: 10.4, 10.5, 10.6_
  
  - [ ] 11.3 实现音频会话中断处理
    - 处理来电等中断事件
    - 实现中断恢复逻辑
    - _需求: 10.7_

- [ ] 12. 检查点 - 确保集成测试通过
  - 确保所有测试通过，如有问题请询问用户。

- [ ] 13. 用户界面实现
  - [ ] 13.1 创建 EQ 调节视图
    - 创建 `Sources/AsideMusic/Views/Audio/EQView.swift`
    - 实现 10 频段滑块控件
    - 实现预设选择器
    - 实现重置和 bypass 按钮
    - _需求: 8.1, 8.4, 8.5, 8.6, 8.7_
  
  - [ ] 13.2 创建混响调节视图
    - 创建 `Sources/AsideMusic/Views/Audio/ReverbView.swift`
    - 实现干湿比、衰减时间、房间大小滑块
    - 实现预设选择器
    - _需求: 8.2, 8.4, 8.5_
  
  - [ ] 13.3 创建压缩器调节视图
    - 创建 `Sources/AsideMusic/Views/Audio/CompressorView.swift`
    - 实现阈值、压缩比、启动/释放时间滑块
    - _需求: 8.3, 8.5_
  
  - [ ] 13.4 创建音频效果主视图
    - 创建 `Sources/AsideMusic/Views/Audio/AudioEffectsView.swift`
    - 整合 EQ、混响、压缩器视图
    - 实现全局效果开关
    - 实现效果顺序调整
    - _需求: 8.7, 8.8_
  
  - [ ] 13.5 集成到设置页面
    - 在 SettingsView 中添加音频效果入口
    - 保持与现有视觉风格一致
    - _需求: 8.8_

- [ ] 14. 错误处理和日志
  - [ ] 14.1 实现错误处理机制
    - 创建 AudioKitError 错误类型
    - 实现错误降级策略
    - 添加错误日志记录
    - _需求: 9.5_

- [ ] 15. 最终检查点 - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户。

## 备注

- 每个任务都引用了具体的需求以便追溯
- 检查点用于确保增量验证
- 属性测试验证通用正确性属性
- 单元测试验证具体示例和边界情况
