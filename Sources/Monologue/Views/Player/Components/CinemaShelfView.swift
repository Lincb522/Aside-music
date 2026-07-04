import SwiftUI
import UIKit
import AudioToolbox

/// 影院沉浸播放器的 3D 歌架 — 复刻 Mineradio 侧栏歌单架的手感：
/// - 实卡黑玻璃底，独立 accent 描边
/// - 整体 -15° 侧向角（Mineradio 静态镜头默认角度）+ 透视轮盘排布
/// - 滚动选择跟随中心卡高亮，切换时清脆咔哒反馈（触感 + 键击音）
/// - 中心卡通过 floatMix 浮起：向观者位移、放大、提亮、描边发光
/// - 点击非中心卡先滚动居中，点击中心卡播放
struct CinemaShelfView: View {
    @ObservedObject var player = PlayerManager.shared
    let pulse: CinemaAudioPulse
    var accent: Color = .monologueAccent
    /// 每次交互（拖拽/点选）回调，供外层重置自动隐藏计时
    var onInteraction: () -> Void = {}

    /// 滚动位置（卡片单位，非整数表示滚动中）
    @State private var scroll: Double = 0
    @State private var dragBase: Double? = nil
    @State private var lastTickIndex: Int = -1

    private let cardSpacing: Double = 78
    private let cardWidth: CGFloat = 248
    private let cardHeight: CGFloat = 64
    private let visibleRange: Double = 3.8

    private var songs: [Song] { player.currentContextList }

    var body: some View {
        GeometryReader { geo in
            let centerY = geo.size.height / 2
            ZStack {
                ForEach(visibleIndices, id: \.self) { i in
                    card(at: i)
                        .position(x: geo.size.width / 2, y: centerY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(width: cardWidth + 40)
        // Mineradio 静态镜头默认侧向角度 -15°
        .rotation3DEffect(.degrees(-15), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.55)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .onAppear {
            scroll = Double(player.contextIndex)
            lastTickIndex = player.contextIndex
        }
        .onChange(of: player.contextIndex) { _, newIndex in
            // 切歌后中心卡跟随当前播放（拖拽中不打断）
            guard dragBase == nil else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                scroll = Double(newIndex)
            }
        }
        .onChange(of: songs.count) { _, newCount in
            scroll = min(scroll, Double(max(0, newCount - 1)))
        }
    }

    private var visibleIndices: [Int] {
        guard !songs.isEmpty else { return [] }
        let lo = max(0, Int(floor(scroll - visibleRange)))
        let hi = min(songs.count - 1, Int(ceil(scroll + visibleRange)))
        guard lo <= hi else { return [] }
        return Array(lo...hi)
    }

    // MARK: - 单张卡片（轮盘排布 + floatMix 浮起）

    @ViewBuilder
    private func card(at index: Int) -> some View {
        let song = songs[index]
        let delta = Double(index) - scroll
        let absDelta = abs(delta)
        // 中心权重：中心卡 1，相邻卡快速衰减（对应 selected/floatMix）
        let floatMix = max(0, 1 - absDelta * 2)
        let isCurrent = index == player.contextIndex

        let cardScale: Double = max(0.78, 1 - absDelta * 0.085) + floatMix * 0.05
        let offsetX: CGFloat = CGFloat(pow(absDelta, 1.6) * 7 - floatMix * 12)
        let offsetY: CGFloat = CGFloat(delta * cardSpacing)
        let tiltDegrees: Double = -delta * 13
        let cardOpacity: Double = max(0, 1 - absDelta * 0.24)

        shelfCard(song: song, isCurrent: isCurrent, floatMix: floatMix)
            .frame(width: cardWidth, height: cardHeight)
            // 浮起：向观者（左）位移 + 放大 + 提亮
            .scaleEffect(cardScale)
            .offset(x: offsetX, y: offsetY)
            .rotation3DEffect(
                .degrees(tiltDegrees),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.6
            )
            .opacity(cardOpacity)
            .zIndex(-absDelta)
            .contentShape(Rectangle())
            .onTapGesture {
                onInteraction()
                let center = Int(scroll.rounded())
                if index == center {
                    player.playFromQueue(song: song)
                } else {
                    playShelfSelectTick()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        scroll = Double(index)
                    }
                    lastTickIndex = index
                }
            }
    }

    @ViewBuilder
    private func shelfCard(song: Song, isCurrent: Bool, floatMix: Double) -> some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: song.coverUrl?.sized(100)) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.10))
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72 + floatMix * 0.28))
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.42 + floatMix * 0.18))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isCurrent {
                PlayingVisualizerView(isAnimating: player.isPlaying, color: accent)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(cardGlass(floatMix: floatMix))
        .overlay(centerRing(floatMix: floatMix, isCurrent: isCurrent))
        .shadow(color: .black.opacity(0.30 + floatMix * 0.20), radius: 8 + 10 * floatMix, x: 0, y: 5)
    }

    /// 液态玻璃卡底。
    /// 注意：不能用 iOS 26 的 glassEffect —— 卡片每帧都在做 3D 位移，
    /// glassEffect 的取景层异步更新会留下残影外框；改用材质模糊 + 高光描边模拟。
    @ViewBuilder
    private func cardGlass(floatMix: Double) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.30 + floatMix * 0.08))
            )
            .overlay(
                // 顶缘高光，液态玻璃质感
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22 + floatMix * 0.12), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 中心高亮描边：accent 色 + 节拍轻微呼吸
    @ViewBuilder
    private func centerRing(floatMix: Double, isCurrent: Bool) -> some View {
        if floatMix > 0.01 {
            TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 20, paused: !player.isPlaying)) { _ in
                let beat = pulse.snapshot().beatPulse
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        accent.opacity(floatMix * (0.55 + beat * 0.45)),
                        lineWidth: 1.4 + floatMix * 0.6
                    )
                    .shadow(color: accent.opacity(floatMix * beat * 0.5), radius: 8)
            }
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: - 拖拽滚轮 + 咔哒选择反馈

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                onInteraction()
                if dragBase == nil { dragBase = scroll }
                guard let base = dragBase, !songs.isEmpty else { return }
                let raw = base - Double(value.translation.height) / cardSpacing
                scroll = min(max(raw, -0.35), Double(songs.count - 1) + 0.35)

                let centered = Int(scroll.rounded())
                if centered != lastTickIndex, centered >= 0, centered < songs.count {
                    lastTickIndex = centered
                    playShelfSelectTick()
                }
            }
            .onEnded { value in
                guard let base = dragBase, !songs.isEmpty else { dragBase = nil; return }
                dragBase = nil
                // 惯性投影后吸附到最近卡片
                let projected = base - Double(value.predictedEndTranslation.height) / cardSpacing
                let target = min(max(projected.rounded(), 0), Double(songs.count - 1))
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                    scroll = target
                }
                let idx = Int(target)
                if idx != lastTickIndex {
                    lastTickIndex = idx
                    playShelfSelectTick()
                }
            }
    }

    /// PSP 式清脆机械咔哒：selection 触感 + 键击短音
    private func playShelfSelectTick() {
        UISelectionFeedbackGenerator().selectionChanged()
        AudioServicesPlaySystemSound(1104)
    }
}
