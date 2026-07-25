//  Folia "Fume" visualizer: the full lyric becomes an editorial score while
//  the camera follows the current sentence.

import SwiftUI

struct AriaFumeLyricStage: View {
    let lines: [AriaLine]
    let activeIndex: Int
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    private var activeLineID: Int {
        guard lines.indices.contains(activeIndex) else { return -1 }
        return lines[activeIndex].id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    Color.clear
                        .frame(height: stageSize.height * 0.34)

                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let isActive = index == activeIndex
                        FumeLineView(
                            line: line,
                            index: index,
                            distance: activeIndex < 0 ? 99 : abs(index - activeIndex),
                            isActive: isActive,
                            palette: palette.lineVariant(line.id),
                            fontChoice: fontChoice,
                            fontScale: fontScale,
                            // 只有活跃行与间奏行消费时间；其余行冻结为 0，
                            // 配合 Equatable 让时间轴 tick 不再重排整屏文本
                            time: isActive || line.isInterlude ? time : 0,
                            stageWidth: stageSize.width
                        )
                        .equatable()
                        .id(line.id)
                    }

                    Color.clear
                        .frame(height: stageSize.height * 0.38)
                }
                .frame(maxWidth: stageSize.width * 0.86, alignment: .leading)
                .padding(.horizontal, stageSize.width * 0.07)
            }
            .scrollDisabled(true)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.13),
                        .init(color: .white, location: 0.85),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .leading) {
                fumeRail
            }
            .onAppear {
                guard activeLineID >= 0 else { return }
                proxy.scrollTo(activeLineID, anchor: .center)
            }
            .onChange(of: activeLineID) { _, newValue in
                guard newValue >= 0 else { return }
                withAnimation(cameraAnimation) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var cameraAnimation: Animation {
        guard lines.indices.contains(activeIndex) else {
            return .easeOut(duration: 0.35)
        }
        switch lines[activeIndex].hints.transitionMode {
        case .none: return .linear(duration: 0.01)
        case .fast: return .easeOut(duration: 0.26)
        case .normal: return .smooth(duration: 0.48)
        }
    }

    private var fumeRail: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            palette.primary.opacity(0.16),
                            palette.accent.opacity(0.46),
                            palette.primary.opacity(0.16),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)

            if activeIndex >= 0 {
                Text(String(format: "%02d", activeIndex + 1))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.secondary.opacity(0.72))
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
            }
        }
        .padding(.vertical, 48)
        .offset(x: stageSize.width * 0.026)
        .allowsHitTesting(false)
    }
}

private struct FumeLineView: View, @MainActor Equatable {
    let line: AriaLine
    let index: Int
    let distance: Int
    let isActive: Bool
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageWidth: CGFloat

    static func == (lhs: FumeLineView, rhs: FumeLineView) -> Bool {
        lhs.line.id == rhs.line.id
            && lhs.line.fullText == rhs.line.fullText
            && lhs.index == rhs.index
            && lhs.distance == rhs.distance
            && lhs.isActive == rhs.isActive
            && lhs.palette == rhs.palette
            && lhs.fontChoice == rhs.fontChoice
            && lhs.fontScale == rhs.fontScale
            && lhs.time == rhs.time
            && lhs.stageWidth == rhs.stageWidth
    }

    private var fontSize: CGFloat {
        let base = min(48, max(31, stageWidth * 0.038)) * CGFloat(fontScale)
        return isActive ? base * 1.08 : base
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(
                    isActive ? palette.accent.opacity(0.82) : palette.secondary.opacity(0.28)
                )
                .frame(width: 24, alignment: .trailing)
                .padding(.top, 8)

            if line.isInterlude {
                interlude
            } else if isActive {
                activeLine
            } else {
                Text(line.fullText.preventingOrphanLastLine())
                    .font(fontChoice.font(size: fontSize, weight: .bold))
                    .tracking(-0.45)
                    .foregroundStyle(palette.primary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .opacity(lineOpacity)
        .scaleEffect(
            isActive ? 1 : CGFloat(max(0.94, 1 - Double(distance) * 0.012)),
            anchor: .leading
        )
        .blur(radius: distance > 3 ? CGFloat(min(3, distance - 3)) * 0.5 : 0)
        .animation(.smooth(duration: 0.4), value: isActive)
    }

    private var activeLine: some View {
        AriaFumeFlowLayout(spacing: 7) {
            ForEach(AriaFoliaTokenCache.tokens(for: line)) { token in
                FumeTokenView(
                    token: token,
                    hints: line.hints,
                    palette: palette,
                    fontChoice: fontChoice,
                    fontSize: fontSize,
                    time: time
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var interlude: some View {
        HStack(spacing: 9) {
            ForEach(0..<5, id: \.self) { dot in
                Circle()
                    .fill(
                        dot <= Int(
                            AriaFoliaRuntime.clamp(
                                (time - line.startTime) / max(line.rawDuration, 0.1)
                            ) * 5
                        )
                        ? palette.accent
                        : palette.primary.opacity(0.16)
                    )
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.top, 9)
    }

    private var lineOpacity: Double {
        if isActive { return 1 }
        if distance == 1 { return 0.38 }
        if distance == 2 { return 0.22 }
        return max(0.07, 0.16 - Double(distance) * 0.018)
    }
}

private struct FumeTokenView: View {
    let token: AriaFoliaToken
    let hints: AriaRenderHints
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double

    private var status: AriaWordStatus {
        AriaFoliaRuntime.status(for: token, hints: hints, time: time)
    }

    var body: some View {
        let mix = AriaFoliaRuntime.bodyMix(for: token, hints: hints, time: time)
        let glow = AriaFoliaRuntime.glowEnvelope(for: token, hints: hints, time: time)
        let color = status == .waiting
            ? palette.primary.opacity(0.24)
            : AriaFoliaColor.mix(palette.primary, palette.accent, amount: mix)

        Text(token.text)
            .font(fontChoice.font(size: fontSize, weight: .black))
            .tracking(-0.7)
            .foregroundStyle(color)
            .lineLimit(1)
            .opacity(status == .passed ? 0.72 : 1)
            .scaleEffect(status == .active ? 1.018 : 1)
            .shadow(color: palette.accent.opacity(glow * 0.24), radius: 10)
            .animation(.smooth(duration: 0.24), value: status)
    }
}

private struct AriaFumeFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: usedWidth, height: y + lineHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
