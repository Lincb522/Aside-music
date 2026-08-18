# MonoCompute Engine

## 目标

`MonoComputeEngine` 是 App 全局统一的 CPU/GPU 工作量治理层。它不替换播放器、不进入实时音频渲染线程，也不主动暂停播放；它只向可降级的视觉和后台计算任务下发统一预算，避免每个页面分别判断发热、省电和录屏状态。

## 输入信号

- **进程 CPU**：每 2 秒（前台）或 8 秒（后台）采样一次本进程全部非空闲线程的 `thread_basic_info.cpu_usage`，得到可超过 100% 的多核总占用。
- **系统热状态**：监听 `ProcessInfo.thermalStateDidChangeNotification`。
- **低电量模式**：监听 `NSProcessInfoPowerStateDidChange`。
- **前后台状态**：后台直接进入最低工作预算，但不干预音频会话。
- **录屏/投屏**：检测所有 `UIWindowScene` 的屏幕捕获状态；捕获期间至少进入 reduced 档，给系统编码链路预留算力。
- **实时帧稳定性**：只有沉浸舞台、全屏流体背景和流体迷你播放器处于活动状态时，启动唯一的 30Hz `CADisplayLink` 探针。按 2.5 秒窗口统计漏帧比例与最长帧耗时。
- **瞬时系统压力**：收到内存告警后，临时 90 秒进入 reduced 档，降低后续纹理上传、图片解码和可重建后台任务的压力。

CPU 升档需要连续 3 个高负载样本；恢复需要连续 6 个低负载样本，并且每次只恢复一级。EMA 平滑和迟滞可避免负载临界值附近频繁切档。

渲染压力需要连续 2 个异常窗口才降档，忽略页面转场的一次性卡顿；恢复需要连续 4 个稳定窗口，且每次只恢复一级。没有活动重视觉工作负载时立即关闭帧探针，不产生常驻刷新。

## 四级预算

| 档位 | 交互 FPS | 连续动画 FPS | 重视觉 FPS | GPU 渲染比例 | 粒子密度 | 后台并发 | 昂贵 Shader | 连续触觉 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| maximum | 120 | 60 | 60 | 1.00 | 1.00 | 4 | 开 | 开 |
| balanced | 60 | 45 | 40 | 0.86 | 0.78 | 3 | 开 | 开 |
| reduced | 45 | 30 | 24 | 0.68 | 0.55 | 2 | 开 | 关 |
| minimum | 30 | 24 | 15 | 0.50 | 0.35 | 1 | 关 | 关 |

## GPU 管理方式

iOS 没有适合生产 App 持续轮询的公开全局 GPU 利用率接口，因此引擎不伪造“GPU 百分比”。GPU 通过可控工作量预算治理：

1. 限制 `TimelineView` 的刷新频率；
2. 降低全屏 Metal 流体背景的离屏渲染尺寸；
3. 降低沉浸模式粒子数量；
4. 在最低档关闭昂贵 Shader，并回退到静态/低成本渐变；
5. 热状态、录屏和 CPU 压力共同决定最终档位，避免 CPU 与 GPU 各自降级造成策略冲突。
6. 将实际漏帧比例和最长帧耗时纳入最终档位；即使 CPU 不高，GPU/主线程持续无法按时提交帧也会自动降级。

## 已接入模块

- `AppFrameRate`：所有使用统一 timeline 的动画自动继承交互、连续和重视觉预算。
- `AppFrameRate` 的沉浸模式帧率锁会登记 `immersive-stage` 工作负载，重复刷新帧率配置不会重复创建探针。
- `AriaPerformanceGovernor`：沉浸模式舞台帧率、封面粒子密度和录屏保护统一由计算预算驱动。
- `AsideMusicFluidBackground`：按预算调整 Metal 渲染比例，最低档回退非动态背景。
- `AsideMusicFluidBackground` 与 `FluxFloatingBar`：只在有歌曲播放、前台活动且允许动态效果时登记工作负载；退出页面、暂停或切后台会对称注销。
- `FluxFloatingBar`：昂贵 Shader 被禁用时回退渐变，并使用重视觉帧率预算。
- `AIEqualizerFeatureSampler`：按计算档位降低频谱和 PCM 交付频率，不阻塞实时音频线程。
- `DownloadManager`：新下载任务的并发上限跟随后台计算预算；已在传输中的任务不会被强制中断。
- `AriaHapticBeat`：持续高负载、低电量、过热或录屏时停止新增节拍触觉。

## 并发读取

SwiftUI 观察 `MonoComputeEngine.shared.budget`。非主线程和高频路径只读取 `MonoComputeBudgetStore.shared.current`；该镜像由 `NSLock` 保护，只有主引擎可以写入。这样不会把任意后台任务强制切回 MainActor。

## CPU 任务准入

`MonoComputeScheduler` 是配套的 actor 调度器，按当前计算预算限制可延后的 CPU 密集工作并发：

- `userInitiated`：当前页面正在等待的短任务，可比后台预算多一个并发槽；
- `analysis`：频谱聚合、特征提取等分析任务，严格服从后台计算并发预算；
- `maintenance`：批处理和维护任务，比后台预算少一个并发槽。

调度器采用优先级 + FIFO 排队。预算下降不会中断已运行任务，只阻止新任务进入；取消仍在等待的任务会从队列移除并恢复 continuation，不遗留悬挂任务。目前封面多色取色与 AI 调音最终特征聚合已接入该准入层。

## 诊断

开发诊断可调用：

```swift
let snapshot = MonoComputeEngine.shared.diagnosticSnapshot()
let report = MonoComputeEngine.shared.diagnosticReport()
let scheduler = await MonoComputeScheduler.shared.diagnosticSnapshot()
```

报告包含当前档位、瞬时/平滑 CPU、三类帧率预算、GPU 渲染比例、粒子密度、漏帧比例、最长帧耗时、渲染压力档位、活动工作负载、热状态、省电状态、前后台状态和录屏状态。

## 边界

- 不修改播放队列、播放进度、音频格式或音频会话策略。
- 不在音频 render callback 内采样或加锁。
- 不因为性能降档取消正在播放的歌曲或正在传输的下载；只限制后续可降级工作量。
- 内存压力仍由 `MonoMemoryEngine` 独立管理；两个引擎分别负责容量和算力，避免职责混杂。
