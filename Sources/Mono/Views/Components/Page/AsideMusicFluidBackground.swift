import SwiftUI

/// AsideMusic 默认主题的全屏流体背景。
///
/// 只在根主题宿主中挂载一次；封面变化时重新提取调色板，播放时流动，
/// 暂停、切到后台或开启“减弱动态效果”时冻结当前画面。
@MainActor
struct AsideMusicFluidBackground: View {
    let artworkURL: String
    var onBrightnessChanged: ((Bool) -> Void)?

    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var compute = MonoComputeEngine.shared
    // FLUX 原版使用三种独立颜料。这里固定至少提取五色，再从首、中、尾
    // 选出跨度最大的三色，避免全局取色数量设为 2 时退化成双色渐变。
    @StateObject private var coverColors = CoverColorExtractor(minimumColorCount: 5)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var accumulatedMotionTime: TimeInterval = 0
    @State private var motionAnchorDate = Date()
    @State private var motionIsRunning = false
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
        player.isPlaying
            && scenePhase == .active
            && !reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let renderScale = max(
                CGFloat(0.34),
                CGFloat(0.58 * compute.budget.gpuRenderScale)
            )
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
            coverColors.extract(from: artworkURL)
            synchronizeMotionClock()
        }
        .onChange(of: artworkURL) { _, newURL in
            coverColors.extract(from: newURL)
            synchronizeMotionClock(reset: true)
        }
        .onChange(of: player.isPlaying) { _, _ in
            synchronizeMotionClock()
        }
        .onChange(of: scenePhase) { _, _ in
            synchronizeMotionClock()
        }
        .onChange(of: reduceMotion) { _, _ in
            synchronizeMotionClock()
        }
        .onChange(of: compute.budget) { _, _ in
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
            if let computeWorkloadToken {
                compute.endWorkload(computeWorkloadToken)
                self.computeWorkloadToken = nil
            }
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
        let shouldObserve = player.isPlaying
            && scenePhase == .active
            && !reduceMotion
            && coverColors.resolvedURL == artworkURL
        if shouldObserve, computeWorkloadToken == nil {
            computeWorkloadToken = compute.beginWorkload(.fluidBackground)
        } else if !shouldObserve, let computeWorkloadToken {
            compute.endWorkload(computeWorkloadToken)
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
