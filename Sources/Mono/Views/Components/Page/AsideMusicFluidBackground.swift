import SwiftUI

/// AsideMusic 默认主题的全屏流体背景。
///
/// 封面变化时重新提取调色板，播放时流动；离开页面、暂停、
/// 切到后台或开启“减弱动态效果”时冻结当前画面。
@MainActor
struct AsideMusicFluidBackground: View {
    let artworkURL: String
    var onBrightnessChanged: ((Bool) -> Void)?

    @State private var isPlaying = FloatingBarPlaybackModel.shared.isPlaying
    // FLUX 原版使用三种独立颜料。这里固定至少提取五色，再从首、中、尾
    // 选出跨度最大的三色，避免全局取色数量设为 2 时退化成双色渐变。
    @StateObject private var coverColors = CoverColorExtractor(minimumColorCount: 5)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var accumulatedMotionTime: TimeInterval = 0
    @State private var motionAnchorDate = Date()
    @State private var motionIsRunning = false
    @State private var isVisible = false
    @State private var computeWorkloadToken: UUID?

    private var palette: [Color] {
        let extracted = coverColors.palette
        guard extracted.count >= 3 else {
            return [
                coverColors.dominantColor,
                coverColors.secondaryColor,
                coverColors.dominantColor.opacity(0.78),
            ]
        }

        return [
            extracted[0],
            extracted[extracted.count / 2],
            extracted[extracted.count - 1],
        ]
    }

    private var shouldRunMotion: Bool {
        isVisible && isPlaying
            && scenePhase == .active
            && !reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            // 渲染分辨率是该材质的固定设计参数，不随设备压力改变，避免
            // MonoCompute 策略更新令整块 Shader 视图重建或视觉清晰度跳变。
            let renderScale = CGFloat(0.58)
            let renderSize = CGSize(
                width: max(proxy.size.width * renderScale, 1),
                height: max(proxy.size.height * renderScale, 1)
            )

            ZStack {
                Color.monoBackground

                if coverColors.resolvedURL == artworkURL,
                   #available(iOS 17.0, *) {
                    AsideMusicFluidMetalSurface(
                        size: renderSize,
                        colors: palette,
                        accumulatedMotionTime: accumulatedMotionTime,
                        motionAnchorDate: motionAnchorDate,
                        motionIsRunning: motionIsRunning,
                        isDarkMode: colorScheme == .dark
                    )
                    .frame(width: renderSize.width, height: renderSize.height)
                    .scaleEffect(1 / renderScale, anchor: .topLeading)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .topLeading
                    )
                } else if coverColors.resolvedURL == artworkURL {
                    DynamicCoverPaletteLayer(
                        colors: palette,
                        opacity: colorScheme == .dark ? 0.82 : 0.62
                    )
                    .blur(radius: 34)
                    .scaleEffect(1.16)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            isVisible = true
            coverColors.extract(from: artworkURL)
            synchronizeMotionClock()
        }
        .onChange(of: artworkURL) { _, newURL in
            coverColors.extract(from: newURL)
            synchronizeMotionClock(reset: true)
        }
        .onReceive(FloatingBarPlaybackModel.shared.$isPlaying.removeDuplicates()) { playing in
            guard isPlaying != playing else { return }
            isPlaying = playing
            synchronizeMotionClock()
        }
        .onChange(of: scenePhase) { _, _ in
            synchronizeMotionClock()
        }
        .onChange(of: reduceMotion) { _, _ in
            synchronizeMotionClock()
        }
        .onChange(of: coverColors.isDark) { _, isDark in
            onBrightnessChanged?(isDark)
        }
        .onChange(of: coverColors.resolvedURL) { _, resolvedURL in
            guard resolvedURL == artworkURL else { return }
            onBrightnessChanged?(coverColors.isDark)
            synchronizeComputeWorkload()
        }
        .onDisappear {
            isVisible = false
            synchronizeMotionClock()
        }
    }

    private func synchronizeMotionClock(reset: Bool = false) {
        let now = Date()

        if reset {
            accumulatedMotionTime = 0
        } else if motionIsRunning {
            accumulatedMotionTime += max(now.timeIntervalSince(motionAnchorDate), 0)
        }

        motionAnchorDate = now
        motionIsRunning = shouldRunMotion
        synchronizeComputeWorkload()
    }

    private func synchronizeComputeWorkload() {
        let shouldObserve = shouldRunMotion
            && coverColors.resolvedURL == artworkURL
        if shouldObserve, computeWorkloadToken == nil {
            computeWorkloadToken = MonoComputeEngine.shared.beginWorkload(.fluidBackground)
        } else if !shouldObserve, let computeWorkloadToken {
            MonoComputeEngine.shared.endWorkload(computeWorkloadToken)
            self.computeWorkloadToken = nil
        }
    }
}

@available(iOS 17.0, *)
private struct AsideMusicFluidMetalSurface: View {
    let size: CGSize
    let colors: [Color]
    let accumulatedMotionTime: TimeInterval
    let motionAnchorDate: Date
    let motionIsRunning: Bool
    let isDarkMode: Bool

    var body: some View {
        TimelineView(
            AppFrameRate.throttledTimeline(
                maximumFramesPerSecond: 30,
                paused: !motionIsRunning
            )
        ) { context in
            Rectangle()
                .fill(Color.white)
                .colorEffect(
                    ShaderLibrary.asideMusicFluidBackgroundMaterial(
                        .float2(size),
                        .float(Float(motionTime(at: context.date))),
                        .float(isDarkMode ? 1 : 0),
                        .color(colors[0]),
                        .color(colors[1]),
                        .color(colors[2])
                    )
                )
        }
    }

    private func motionTime(at date: Date) -> TimeInterval {
        let liveElapsed = motionIsRunning
            ? max(date.timeIntervalSince(motionAnchorDate), 0)
            : 0
        return accumulatedMotionTime + liveElapsed
    }
}
