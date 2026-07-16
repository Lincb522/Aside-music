//
//  AriaFoliaCappellaView.swift
//  Monologue
//
//  Folia "Cappella" visualizer: timed duet bubbles using the current cover
//  on the left and the NetEase profile avatar on the right.
//

import SwiftUI

struct AriaCappellaLyricStage: View {
    let lines: [AriaLine]
    let activeIndex: Int
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var homeViewModel = HomeViewModel.shared
    @State private var cachedAvatarURL: URL?

    private var activeLineID: Int {
        guard lines.indices.contains(activeIndex) else { return -1 }
        return lines[activeIndex].id
    }

    private var neteaseAvatarURL: URL? {
        if let value = homeViewModel.userProfile?.avatarUrl,
           let url = URL(string: value) {
            return url
        }
        return cachedAvatarURL
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    Color.clear
                        .frame(height: stageSize.height * 0.32)

                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let isActive = index == activeIndex
                        CappellaBubbleRow(
                            line: line,
                            index: index,
                            distance: activeIndex < 0 ? 99 : abs(index - activeIndex),
                            isActive: isActive,
                            palette: palette.lineVariant(line.id),
                            fontChoice: fontChoice,
                            fontScale: fontScale,
                            // 只有活跃行与间奏行消费时间；其余行冻结，
                            // 配合 Equatable 避免每个 tick 重排整屏气泡
                            time: isActive || line.isInterlude ? time : 0,
                            coverURL: player.currentSong?.coverUrl?.sized(100),
                            profileURL: neteaseAvatarURL,
                            stageWidth: max(
                                220,
                                stageSize.width
                                    - 2 * max(34, stageSize.width * 0.085)
                            )
                        )
                        .equatable()
                        .id(line.id)
                    }

                    Color.clear
                        .frame(height: stageSize.height * 0.34)
                }
                .padding(.horizontal, max(34, stageSize.width * 0.085))
            }
            .scrollDisabled(true)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.12),
                        .init(color: .white, location: 0.86),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .onAppear {
                loadCachedAvatar()
                guard activeLineID >= 0 else { return }
                proxy.scrollTo(activeLineID, anchor: .center)
            }
            .onChange(of: activeLineID) { _, newValue in
                guard newValue >= 0 else { return }
                withAnimation(.smooth(duration: 0.46)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onChange(of: homeViewModel.userProfile?.avatarUrl) { _, newValue in
                cachedAvatarURL = newValue.flatMap(URL.init(string:))
            }
        }
    }

    private func loadCachedAvatar() {
        if let value = homeViewModel.userProfile?.avatarUrl,
           let url = URL(string: value) {
            cachedAvatarURL = url
            return
        }

        if let profile = OptimizedCacheManager.shared.getObject(
            forKey: "user_profile_detail",
            type: UserProfile.self
        ), let value = profile.avatarUrl {
            cachedAvatarURL = URL(string: value)
        }
    }
}

private struct CappellaBubbleRow: View, @MainActor Equatable {
    let line: AriaLine
    let index: Int
    let distance: Int
    let isActive: Bool
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let coverURL: URL?
    let profileURL: URL?
    let stageWidth: CGFloat

    static func == (lhs: CappellaBubbleRow, rhs: CappellaBubbleRow) -> Bool {
        lhs.line.id == rhs.line.id
            && lhs.line.fullText == rhs.line.fullText
            && lhs.index == rhs.index
            && lhs.distance == rhs.distance
            && lhs.isActive == rhs.isActive
            && lhs.palette == rhs.palette
            && lhs.fontChoice == rhs.fontChoice
            && lhs.fontScale == rhs.fontScale
            && lhs.time == rhs.time
            && lhs.coverURL == rhs.coverURL
            && lhs.profileURL == rhs.profileURL
            && lhs.stageWidth == rhs.stageWidth
    }

    private var isLeft: Bool {
        index.isMultiple(of: 2)
    }

    private var visualLength: CGFloat {
        line.fullText.unicodeScalars.reduce(0) { partial, scalar in
            let isCJK = (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
            return partial + (isCJK ? 1 : 0.54)
        }
    }

    private var bubbleContentWidth: CGFloat {
        let available = stageWidth - 42 - 12 - max(16, stageWidth * 0.04) - 36
        let desiredRatio: CGFloat
        switch visualLength {
        case ...10: desiredRatio = 0.42
        case ...20: desiredRatio = 0.54
        case ...34: desiredRatio = 0.62
        default: desiredRatio = 0.68
        }
        return min(max(available, 90), max(90, stageWidth * desiredRatio))
    }

    private var adaptiveFontSize: CGFloat {
        let base = min(32, max(22, stageWidth * 0.031)) * CGFloat(fontScale)
        switch visualLength {
        case ...18: return base
        case ...30: return max(19, base * 0.9)
        case ...44: return max(17, base * 0.79)
        default: return max(15, base * 0.7)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if isLeft {
                CappellaAvatar(
                    url: coverURL,
                    fallback: .microphone,
                    palette: palette,
                    isActive: isActive
                )
                bubble
                Spacer(minLength: max(16, stageWidth * 0.04))
            } else {
                Spacer(minLength: max(16, stageWidth * 0.04))
                bubble
                CappellaAvatar(
                    url: profileURL,
                    fallback: .profileFilled,
                    palette: palette,
                    isActive: isActive
                )
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(rowOpacity)
        .scaleEffect(isActive ? 1 : 0.965, anchor: isLeft ? .bottomLeading : .bottomTrailing)
        .blur(radius: distance > 3 ? CGFloat(min(3, distance - 3)) * 0.45 : 0)
        .animation(.smooth(duration: 0.38), value: isActive)
    }

    private var bubble: some View {
        Group {
            if line.isInterlude {
                interludeBubble
            } else if isActive {
                activeBubble
            } else {
                Text(line.fullText.preventingOrphanLastLine())
                    .font(
                        fontChoice.font(
                            size: adaptiveFontSize * 0.92,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(palette.primary.opacity(0.82))
                    .multilineTextAlignment(isLeft ? .leading : .trailing)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: bubbleContentWidth,
                        alignment: isLeft ? .leading : .trailing
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background {
            bubbleSurface
        }
        .overlay(alignment: isLeft ? .bottomLeading : .bottomTrailing) {
            CappellaBubbleTail(isLeft: isLeft)
                .fill(
                    isActive
                        ? palette.primary.opacity(0.13)
                        : palette.primary.opacity(0.07)
                )
                .frame(width: 15, height: 12)
                .offset(x: isLeft ? -8 : 8, y: 1)
        }
    }

    private var activeBubble: some View {
        AriaCappellaFlowLayout(spacing: 5) {
            ForEach(AriaFoliaTokenCache.tokens(for: line)) { token in
                CappellaTokenView(
                    token: token,
                    hints: line.hints,
                    palette: palette,
                    fontChoice: fontChoice,
                    fontSize: adaptiveFontSize,
                    time: time
                )
            }
        }
        .frame(
            maxWidth: bubbleContentWidth,
            alignment: isLeft ? .leading : .trailing
        )
    }

    private var interludeBubble: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                let progress = AriaFoliaRuntime.clamp(
                    (time - line.startTime) / max(line.rawDuration, 0.1)
                )
                Circle()
                    .fill(
                        index <= Int(progress * 3)
                            ? palette.accent
                            : palette.primary.opacity(0.2)
                    )
                    .frame(width: 7, height: 7)
            }
        }
        .frame(width: 64, height: 22)
    }

    private var bubbleSurface: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.primary.opacity(isActive ? 0.13 : 0.07),
                        palette.primary.opacity(isActive ? 0.075 : 0.04)
                    ],
                    startPoint: isLeft ? .topLeading : .topTrailing,
                    endPoint: isLeft ? .bottomTrailing : .bottomLeading
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isActive
                            ? palette.accent.opacity(0.26)
                            : palette.primary.opacity(0.08),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: isActive ? palette.accent.opacity(0.12) : .black.opacity(0.12),
                radius: isActive ? 18 : 10,
                y: 6
            )
    }

    private var rowOpacity: Double {
        if isActive { return 1 }
        if distance == 1 { return 0.54 }
        if distance == 2 { return 0.32 }
        return max(0.09, 0.24 - Double(distance) * 0.025)
    }
}

private struct CappellaAvatar: View {
    let url: URL?
    let fallback: MonologueIcon.IconType
    let palette: AriaPalette
    let isActive: Bool

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url) {
                    palette.primary.opacity(0.08)
                }
                .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    palette.primary.opacity(0.08)
                    MonologueIcon(
                        icon: fallback,
                        size: 18,
                        color: palette.secondary,
                        lineWidth: 1.7
                    )
                }
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isActive ? palette.accent.opacity(0.72) : palette.primary.opacity(0.12),
                    lineWidth: isActive ? 1.5 : 1
                )
        }
        .shadow(color: palette.accent.opacity(isActive ? 0.22 : 0), radius: 10)
    }
}

private struct CappellaTokenView: View {
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
        let color = status == .waiting
            ? palette.primary.opacity(0.25)
            : AriaFoliaColor.mix(palette.primary, palette.accent, amount: mix)

        Text(token.text)
            .font(fontChoice.font(size: fontSize, weight: .black))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.56)
            .opacity(status == .passed ? 0.76 : 1)
            .scaleEffect(status == .active ? 1.025 : 1)
            .shadow(
                color: palette.accent.opacity(status == .active ? 0.24 : 0),
                radius: 10
            )
            .animation(.smooth(duration: 0.24), value: status)
    }
}

private struct CappellaBubbleTail: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isLeft {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.maxX * 0.35, y: rect.maxY * 0.8)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.65))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.maxX * 0.65, y: rect.maxY * 0.8)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.65))
        }
        path.closeSubpath()
        return path
    }
}

private struct AriaCappellaFlowLayout: Layout {
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
            let size = measuredSize(for: subview, maximumWidth: maxWidth)
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
            let size = measuredSize(for: subview, maximumWidth: bounds.width)
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

    private func measuredSize(
        for subview: LayoutSubview,
        maximumWidth: CGFloat
    ) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard maximumWidth.isFinite, natural.width > maximumWidth else {
            return natural
        }
        let constrained = subview.sizeThatFits(
            ProposedViewSize(width: maximumWidth, height: nil)
        )
        return CGSize(
            width: min(maximumWidth, constrained.width),
            height: constrained.height
        )
    }
}
