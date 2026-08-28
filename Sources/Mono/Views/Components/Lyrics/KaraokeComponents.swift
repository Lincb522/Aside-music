import SwiftUI
import Combine

// MARK: - Karaoke Components

struct KaraokeWordView: View {
    let word: LyricWord
    let progress: CGFloat
    var font: Font = .rounded(size: 26, weight: .bold)
    var activeColor: Color = .monoTextPrimary
    var inactiveColor: Color = .gray.opacity(0.3)
    var activeGradient: LinearGradient? = nil
    var style: KaraokeWordStyle = .flow
    
    var body: some View {
        KaraokeStyledWordView(
            text: word.text,
            progress: progress,
            font: font,
            style: style,
            inactiveColor: inactiveColor,
            activeColor: activeColor,
            activeGradient: activeGradient
        )
    }
    
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    /// 行内对齐：默认靠左（标签云等场景）；歌词逐字用 .center，
    /// 长句换行后每行都居中，而不是整块居中、行内靠左
    var rowAlignment: HorizontalAlignment = .leading
    /// Stable token for rapidly animated content whose intrinsic sizes do not
    /// change between frames. Other FlowLayout call sites keep the default and
    /// retain SwiftUI's normal cache invalidation semantics.
    var measurementToken: Int? = nil
    
    struct Cache {
        var sizes: [CGSize] = []
        var proposedWidth: CGFloat?
        var rows: [Row] = []
        var measurementToken: Int?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(
            sizes: subviews.map { $0.sizeThatFits(.unspecified) },
            measurementToken: measurementToken
        )
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        if let measurementToken,
           cache.measurementToken == measurementToken,
           cache.sizes.count == subviews.count {
            return
        }
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.proposedWidth = nil
        cache.rows.removeAll(keepingCapacity: true)
        cache.measurementToken = measurementToken
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let rows = cachedRows(proposal: proposal, subviews: subviews, cache: &cache)
        let maxWidth = rows.map(\.maxX).max() ?? 0
        let totalHeight = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: maxWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        // SwiftUI may omit the width in the placement proposal even though it
        // supplied one during measurement. Reuse the measured wrapping width
        // instead of measuring every word for a second time on every lyric tick.
        let placementProposal = ProposedViewSize(
            width: proposal.width ?? cache.proposedWidth ?? bounds.width,
            height: proposal.height
        )
        let rows = cachedRows(proposal: placementProposal, subviews: subviews, cache: &cache)
        for row in rows {
            let leftover = max(0, bounds.width - row.maxX)
            let rowOffset: CGFloat
            switch rowAlignment {
            case .center: rowOffset = leftover / 2
            case .trailing: rowOffset = leftover
            default: rowOffset = 0
            }
            for item in row.items {
                guard subviews.indices.contains(item.index) else { continue }
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + rowOffset + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(cache.sizes[item.index])
                )
            }
        }
    }
    
    struct Row {
        var y: CGFloat
        var height: CGFloat
        var items: [Item]
        var maxX: CGFloat = 0
    }
    
    struct Item {
        var index: Int
        var x: CGFloat
    }

    private func cachedRows(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> [Row] {
        let proposedWidth = proposal.width
        if cache.sizes.count != subviews.count {
            cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            cache.proposedWidth = nil
        }

        if cache.rows.isEmpty || cache.proposedWidth != proposedWidth {
            cache.rows = arrangeSubviews(proposal: proposal, sizes: cache.sizes)
            cache.proposedWidth = proposedWidth
        }
        return cache.rows
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, sizes: [CGSize]) -> [Row] {
        var rows: [Row] = []
        var currentRowY: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var currentX: CGFloat = 0
        var currentItems: [Item] = []
        
        let maxWidth = proposal.width ?? .infinity
        
        for (index, viewSize) in sizes.enumerated() {
            
            if currentX + viewSize.width > maxWidth && !currentItems.isEmpty {
                rows.append(Row(y: currentRowY, height: currentRowHeight, items: currentItems, maxX: currentX - spacing))
                currentRowY += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
                currentItems = []
            }
            
            currentItems.append(Item(index: index, x: currentX))
            currentX += viewSize.width + spacing
            currentRowHeight = max(currentRowHeight, viewSize.height)
        }
        
        if !currentItems.isEmpty {
            rows.append(Row(y: currentRowY, height: currentRowHeight, items: currentItems, maxX: currentX - spacing))
        }
        
        return rows
    }
}

struct KaraokeLineView: View {
    let line: LyricLine
    let isCurrent: Bool
    let currentTime: TimeInterval
    let progress: Double
    let showTranslation: Bool
    let enableKaraoke: Bool
    var lyricColorMode: String = "default"
    var lyricSolidColorHex: String = "007AFF"
    var lyricGradientStartHex: String = "FF6B6B"
    var lyricGradientEndHex: String = "4ECDC4"
    var lyricAutoPalette: [Color] = []
    var forceUppercaseEnglish = false
    var playerFontSelectionRaw = MonoPlayerFont.followThemeRawValue
    var playerCustomFontID = ""
    var playerFontScale = 1.0
    var karaokeStyle: KaraokeWordStyle = .flow
    var adaptivePrimaryColor: Color? = nil
    var adaptiveSecondaryColor: Color? = nil
    var enforcesAdaptiveContrast = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 大字报主题判断
    private var isPoster: Bool {
        PlayerThemeManager.shared.currentTheme == .poster
    }
    
    // 水韵主题判断
    private var isAqua: Bool {
        PlayerThemeManager.shared.currentTheme == .aqua
    }

    // 打字机主题判断
    private var isTypewriter: Bool {
        PlayerThemeManager.shared.currentTheme == .typewriter
    }
    
    // 字魂半天云魅黑手书字体
    private let posterFont = "zihunbantianyunmeiheishoushu"
    
    // 文道泡泡体（水韵主题）
    private let aquaFont = "WDPPT"

    private var displayText: String {
        forceUppercaseEnglish
            ? line.text.monoUppercasingEnglish()
            : line.text
    }

    private var displayTranslation: String? {
        guard let translation = line.translation else { return nil }
        return forceUppercaseEnglish
            ? translation.monoUppercasingEnglish()
            : translation
    }
    
    // 当前行字体
    private var currentLineFont: Font {
        let size: CGFloat
        let fallback: Font
        if isPoster {
            size = 28 * CGFloat(playerFontScale)
            fallback = .custom(posterFont, size: size)
        } else if isAqua {
            size = 26 * CGFloat(playerFontScale)
            fallback = .custom(aquaFont, size: size)
        } else if isTypewriter {
            size = 24 * CGFloat(playerFontScale)
            fallback = .system(size: size, weight: .semibold, design: .monospaced)
        } else {
            size = 26 * CGFloat(playerFontScale)
            fallback = .rounded(size: size, weight: .bold)
        }
        return MonoPlayerFont.font(
            selectionRaw: playerFontSelectionRaw,
            customFontID: playerCustomFontID,
            size: size,
            weight: .bold,
            fallback: fallback
        )
    }
    
    // 非当前行字体
    private var normalLineFont: Font {
        let size: CGFloat
        let fallback: Font
        if isPoster {
            size = 16 * CGFloat(playerFontScale)
            fallback = .custom(posterFont, size: size)
        } else if isAqua {
            size = 16 * CGFloat(playerFontScale)
            fallback = .custom(aquaFont, size: size)
        } else if isTypewriter {
            size = 15 * CGFloat(playerFontScale)
            fallback = .system(size: size, weight: .medium, design: .monospaced)
        } else {
            size = 16 * CGFloat(playerFontScale)
            fallback = .rounded(size: size, weight: .medium)
        }
        return MonoPlayerFont.font(
            selectionRaw: playerFontSelectionRaw,
            customFontID: playerCustomFontID,
            size: size,
            weight: .medium,
            fallback: fallback
        )
    }
    
    // 翻译字体
    private func translationFont(isCurrent: Bool) -> Font {
        let size: CGFloat
        let fallback: Font
        if isPoster {
            size = (isCurrent ? 16 : 12) * CGFloat(playerFontScale)
            fallback = .custom(posterFont, size: size)
        } else if isAqua {
            size = (isCurrent ? 15 : 13) * CGFloat(playerFontScale)
            fallback = .custom(aquaFont, size: size)
        } else if isTypewriter {
            size = (isCurrent ? 14 : 12) * CGFloat(playerFontScale)
            fallback = .system(size: size, weight: .regular, design: .monospaced)
        } else {
            size = (isCurrent ? 15 : 13) * CGFloat(playerFontScale)
            fallback = .rounded(size: size, weight: .regular)
        }
        return MonoPlayerFont.font(
            selectionRaw: playerFontSelectionRaw,
            customFontID: playerCustomFontID,
            size: size,
            weight: .regular,
            fallback: fallback
        )
    }
    
    // MARK: - 自定义歌词颜色（仅默认主题）
    
    private var customActiveColor: Color {
        if enforcesAdaptiveContrast, let adaptivePrimaryColor {
            return adaptivePrimaryColor
        }
        guard lyricColorMode != "default" else {
            return adaptivePrimaryColor ?? .monoTextPrimary
        }
        if lyricColorMode == "auto" {
            return lyricAutoPalette.first ?? .monoTextPrimary
        }
        if lyricColorMode == "solid" {
            return Color(hex: lyricSolidColorHex)
        }
        return Color(hex: lyricGradientStartHex)
    }
    
    private var customActiveGradient: LinearGradient? {
        if enforcesAdaptiveContrast { return nil }
        if lyricColorMode == "auto", lyricAutoPalette.count > 1 {
            return LinearGradient(
                colors: Array(lyricAutoPalette.prefix(6)),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        guard lyricColorMode == "gradient" else { return nil }
        return LinearGradient(
            colors: [Color(hex: lyricGradientStartHex), Color(hex: lyricGradientEndHex)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(spacing: isPoster ? 4 : (isTypewriter ? 5 : 6)) {
            if isPoster {
                // 大字报歌词 — 黑条从左滑入
                posterLyricContent
            } else {
                // 默认歌词样式
                defaultLyricContent
            }
            
            // 翻译
            if showTranslation, let trans = displayTranslation, !trans.isEmpty {
                if isPoster {
                    let transColor: Color = isCurrent
                        ? (colorScheme == .dark ? .black.opacity(0.7) : .white.opacity(0.7))
                        : .monoTextPrimary.opacity(0.12)
                    Text(trans)
                        .font(translationFont(isCurrent: isCurrent))
                        .foregroundColor(transColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, isCurrent ? 12 : 0)
                        .padding(.vertical, isCurrent ? 6 : 0)
                        .background(isCurrent ? Color(hex: "FF0000").opacity(0.8) : .clear)
                } else {
                    Text(trans)
                        .font(translationFont(isCurrent: isCurrent))
                        .foregroundColor(
                            isCurrent
                                ? (adaptivePrimaryColor ?? .monoTextPrimary).opacity(0.82)
                                : (adaptiveSecondaryColor ?? .gray.opacity(0.5))
                        )
                        .multilineTextAlignment(.center)
                        .blur(radius: isCurrent ? 0 : 0.3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                        .transition(.opacity)
                }
            }
        }
    }
    
    // MARK: - 大字报歌词样式
    @ViewBuilder
    private var posterLyricContent: some View {
        if isCurrent && !displayText.trimmingCharacters(in: .whitespaces).isEmpty {
            // 当前行 — 黑条贴左边缘，和屏幕左边连成一体，支持自动换行
            HStack(spacing: 0) {
                currentPosterLine
                    .padding(.leading, 32)
                    .padding(.trailing, 16)
                    .padding(.vertical, 12)
                    .background(Color.monoTextPrimary)
                
                Spacer(minLength: 0)
            }
            .padding(.leading, -32)
            .transition(.asymmetric(
                insertion: .move(edge: .leading),
                removal: .opacity
            ))
            .id("poster_\(line.time)")
        } else {
            // 非当前行
            Text(displayText)
                .font(normalLineFont)
                .foregroundColor(.monoTextPrimary.opacity(0.15))
                .tracking(1)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    /// 大字报当前行内容 — 使用字魂字体，支持自动换行
    @ViewBuilder
    private var currentPosterLine: some View {
        // 大字报当前行：背景是 fg（深色=白，浅色=黑），文字需要反色
        let invertedFg: Color = colorScheme == .dark ? .black : .white
        
        Text(displayText)
            .font(currentLineFont)
            .foregroundColor(invertedFg)
            .tracking(-1)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 默认歌词样式
    @ViewBuilder
    private var defaultLyricContent: some View {
        if isCurrent {
            if enableKaraoke {
                if #available(iOS 16.0, *) {
                    let words = resolvedKaraokeWords()
                    FlowLayout(
                        spacing: 0,
                        rowAlignment: .center,
                        measurementToken: karaokeMeasurementToken(words: words)
                    ) {
                        ForEach(words.indices, id: \.self) { i in
                            KaraokeWordView(
                                word: words[i],
                                progress: LyricKaraokeTimeline.progress(
                                    for: words[i],
                                    at: currentTime
                                ),
                                font: currentLineFont,
                                activeColor: customActiveColor,
                                inactiveColor: adaptiveSecondaryColor ?? .gray.opacity(0.3),
                                activeGradient: customActiveGradient,
                                style: karaokeStyle
                            )
                        }
                    }
                    .scaleEffect(1.05)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                } else {
                    constructFallbackText()
                        .multilineTextAlignment(.center)
                        .scaleEffect(1.05)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                }
            } else {
                if let gradient = customActiveGradient {
                    Text(displayText)
                        .font(currentLineFont)
                        .foregroundStyle(gradient)
                        .multilineTextAlignment(.center)
                        .scaleEffect(1.05)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                } else {
                    Text(displayText)
                        .font(currentLineFont)
                        .foregroundColor(customActiveColor)
                        .multilineTextAlignment(.center)
                        .scaleEffect(1.05)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                }
            }
        } else {
            Text(displayText)
                .font(normalLineFont)
                .foregroundColor(adaptiveSecondaryColor ?? .gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .blur(radius: 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
        }
    }
    
    private func resolvedKaraokeWords() -> [LyricWord] {
        // The parser normalizes every line once before publishing it. Reusing
        // that immutable timeline avoids filtering, sorting and allocating new
        // UUID-backed words at 60 fps. Uppercase mode is the only case that
        // needs a display-only copy.
        if !line.words.isEmpty {
            guard forceUppercaseEnglish else { return line.words }
            return line.words.map {
                LyricWord(
                    text: $0.text.monoUppercasingEnglish(),
                    startTime: $0.startTime,
                    duration: $0.duration
                )
            }
        }
        return LyricKaraokeTimeline.resolvedWords(for: line, displayText: displayText)
    }

    private func karaokeMeasurementToken(words: [LyricWord]) -> Int {
        var hasher = Hasher()
        hasher.combine(line.id)
        hasher.combine(words.count)
        hasher.combine(forceUppercaseEnglish)
        hasher.combine(playerFontSelectionRaw)
        hasher.combine(playerCustomFontID)
        hasher.combine(playerFontScale.bitPattern)
        return hasher.finalize()
    }

    private func constructFallbackText() -> Text {
        let chars = Array(displayText)
        let threshold = Int(Double(chars.count) * progress)
        
        var combined = Text("")
        for (index, char) in chars.enumerated() {
            let isActive = index <= threshold && progress > 0
            let color: Color = isActive
                ? (adaptivePrimaryColor ?? .monoTextPrimary)
                : (adaptiveSecondaryColor ?? .gray.opacity(0.3))
            combined = combined + Text(String(char))
                .font(currentLineFont)
                .foregroundColor(color)
        }
        return combined
    }
    
}
