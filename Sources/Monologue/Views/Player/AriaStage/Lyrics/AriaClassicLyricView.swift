//  Folia "Classic" visualizer: balanced rows, grapheme timing and restrained glow.

import SwiftUI
import UIKit

// MARK: - Balanced line layout

private struct AriaClassicRow: Identifiable {
    let id: Int
    let tokens: [AriaFoliaToken]
    let width: CGFloat
}

private struct AriaClassicLinePlan {
    let rows: [AriaClassicRow]
    let fontSize: CGFloat
}

private enum AriaClassicLayoutCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: AriaClassicLinePlan] = [:]

    static func plan(
        for line: AriaLine,
        availableWidth: CGFloat,
        fontChoice: AriaLyricFontChoice,
        fontScale: Double
    ) -> AriaClassicLinePlan {
        let widthBucket = Int(availableWidth.rounded())
        let scaleBucket = Int((fontScale * 100).rounded())
        let key = "\(line.id)|\(line.fullText.hashValue)|\(widthBucket)|\(fontChoice.cacheIdentity)|\(scaleBucket)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = storage[key] {
            return cached
        }

        let plan = buildPlan(
            for: line,
            availableWidth: availableWidth,
            fontChoice: fontChoice,
            fontScale: fontScale
        )
        if storage.count >= 128 {
            storage.removeAll(keepingCapacity: true)
        }
        storage[key] = plan
        return plan
    }

    private static func buildPlan(
        for line: AriaLine,
        availableWidth: CGFloat,
        fontChoice: AriaLyricFontChoice,
        fontScale: Double
    ) -> AriaClassicLinePlan {
        let tokens = AriaFoliaTokenCache.tokens(for: line)
        let baseSize = max(38, min(70, availableWidth * 0.056)) * CGFloat(fontScale)
        let size = fitFontSize(
            tokens: tokens,
            proposed: baseSize,
            availableWidth: availableWidth,
            fontChoice: fontChoice
        )
        let font = fontChoice.uiFont(size: size, weight: .heavy)
        let widths = tokens.map { token in
            max(
                4,
                (token.text as NSString).size(withAttributes: [.font: font]).width
            )
        }

        var rows: [[Int]] = [[]]
        var rowWidths: [CGFloat] = [0]

        for index in tokens.indices {
            let spacing = rows[rows.count - 1].isEmpty
                ? 0
                : tokenSpacing(previous: tokens[rows[rows.count - 1].last!], next: tokens[index])
            let projected = rowWidths[rowWidths.count - 1] + spacing + widths[index]

            if projected > availableWidth, !rows[rows.count - 1].isEmpty {
                rows.append([index])
                rowWidths.append(widths[index])
            } else {
                rows[rows.count - 1].append(index)
                rowWidths[rowWidths.count - 1] = projected
            }
        }

        rebalanceOrphanTail(
            rows: &rows,
            rowWidths: &rowWidths,
            widths: widths,
            tokens: tokens,
            availableWidth: availableWidth
        )

        let output = rows.enumerated().map { rowIndex, indices in
            AriaClassicRow(
                id: rowIndex,
                tokens: indices.map { tokens[$0] },
                width: rowWidth(indices: indices, widths: widths, tokens: tokens)
            )
        }
        return AriaClassicLinePlan(rows: output, fontSize: size)
    }

    private static func fitFontSize(
        tokens: [AriaFoliaToken],
        proposed: CGFloat,
        availableWidth: CGFloat,
        fontChoice: AriaLyricFontChoice
    ) -> CGFloat {
        guard !tokens.isEmpty else { return proposed }

        var size = proposed
        while size > 34 {
            let font = fontChoice.uiFont(size: size, weight: .heavy)
            let longest = tokens.map {
                ($0.text as NSString).size(withAttributes: [.font: font]).width
            }.max() ?? 0
            if longest <= availableWidth { break }
            size -= 2
        }
        return size
    }

    private static func rebalanceOrphanTail(
        rows: inout [[Int]],
        rowWidths: inout [CGFloat],
        widths: [CGFloat],
        tokens: [AriaFoliaToken],
        availableWidth: CGFloat
    ) {
        guard rows.count > 1 else { return }

        // Keep at least four CJK graphemes or two normal tokens on the final row.
        while tailWeight(rows.last!, tokens: tokens) < 4,
              rows[rows.count - 2].count > 1 {
            let donorIndex = rows[rows.count - 2].removeLast()
            let candidate = [donorIndex] + rows[rows.count - 1]
            let candidateWidth = rowWidth(indices: candidate, widths: widths, tokens: tokens)
            if candidateWidth > availableWidth {
                rows[rows.count - 2].append(donorIndex)
                break
            }
            rows[rows.count - 1] = candidate
        }

        rowWidths = rows.map { rowWidth(indices: $0, widths: widths, tokens: tokens) }
    }

    private static func tailWeight(_ indices: [Int], tokens: [AriaFoliaToken]) -> Int {
        indices.reduce(0) { result, index in
            result + (tokens[index].isCJK ? max(1, tokens[index].text.count) : 2)
        }
    }

    private static func rowWidth(
        indices: [Int],
        widths: [CGFloat],
        tokens: [AriaFoliaToken]
    ) -> CGFloat {
        guard let first = indices.first else { return 0 }
        var total = widths[first]
        for position in 1..<indices.count {
            let previous = indices[position - 1]
            let current = indices[position]
            total += tokenSpacing(previous: tokens[previous], next: tokens[current])
            total += widths[current]
        }
        return total
    }

    private static func tokenSpacing(
        previous: AriaFoliaToken,
        next: AriaFoliaToken
    ) -> CGFloat {
        previous.isCJK && next.isCJK ? 2 : 12
    }
}

// MARK: - Classic stage

struct AriaClassicLyricStage: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize
    /// 人声呼吸字重 0~1（0 = 关闭，激活字素保持固定 heavy）
    var breathing: Double = 0

    var body: some View {
        if line.isInterlude {
            classicInterlude
        } else {
            lyricBody
        }
    }

    private var lyricBody: some View {
        let width = max(260, stageSize.width * 0.78)
        let plan = AriaClassicLayoutCache.plan(
            for: line,
            availableWidth: width,
            fontChoice: fontChoice,
            fontScale: fontScale
        )

        return VStack(alignment: .center, spacing: max(8, plan.fontSize * 0.16)) {
            ForEach(plan.rows) { row in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    ForEach(Array(row.tokens.enumerated()), id: \.element.id) { index, token in
                        if index > 0 {
                            Color.clear
                                .frame(
                                    width: row.tokens[index - 1].isCJK && token.isCJK ? 2 : 12,
                                    height: 1
                                )
                        }
                        AriaClassicTokenView(
                            token: token,
                            hints: line.hints,
                            palette: palette,
                            fontChoice: fontChoice,
                            fontSize: plan.fontSize,
                            time: time,
                            breathing: breathing
                        )
                    }
                }
                .frame(width: min(row.width, width), alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var classicInterlude: some View {
        let progress = AriaFoliaRuntime.clamp(
            (time - line.startTime) / max(line.rawDuration, 0.1)
        )

        return ZStack {
            Circle()
                .stroke(palette.primary.opacity(0.12), lineWidth: 1)
                .frame(width: 96, height: 96)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    palette.accent.opacity(0.78),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(palette.primary)
                .frame(width: 8, height: 8)
                .shadow(color: palette.accent.opacity(0.55), radius: 10)
        }
    }
}

private struct AriaClassicTokenView: View {
    let token: AriaFoliaToken
    let hints: AriaRenderHints
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double
    var breathing: Double = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(token.graphemes.enumerated()), id: \.offset) { index, grapheme in
                AriaClassicGraphemeView(
                    text: grapheme.char,
                    start: grapheme.startTime,
                    end: grapheme.endTime,
                    tokenID: token.id,
                    graphemeIndex: index,
                    hints: hints,
                    palette: palette,
                    fontChoice: fontChoice,
                    fontSize: fontSize,
                    time: time,
                    breathing: breathing
                )
            }
        }
    }
}

private struct AriaClassicGraphemeView: View {
    let text: String
    let start: Double
    let end: Double
    let tokenID: Int
    let graphemeIndex: Int
    let hints: AriaRenderHints
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double
    var breathing: Double = 0

    private var effectiveEnd: Double {
        switch hints.revealMode {
        case .instant: return hints.renderEndTime
        case .fast: return min(hints.renderEndTime, max(end, start + 0.1))
        case .normal: return end
        }
    }

    private var status: AriaWordStatus {
        if time >= start - hints.wordLookahead, time <= effectiveEnd {
            return .active
        }
        return time > effectiveEnd ? .passed : .waiting
    }

    private var glow: Double {
        let token = AriaFoliaTokenProxy(start: start, end: end)
        return token.glow(hints: hints, time: time)
    }

    private var bodyMix: Double {
        let token = AriaFoliaTokenProxy(start: start, end: end)
        return token.bodyMix(hints: hints, time: time)
    }

    private var deterministicTilt: Double {
        let seed = abs(tokenID &* 17 &+ graphemeIndex &* 11)
        return Double(seed % 5 - 2) * 0.22
    }

    var body: some View {
        let drift: CGFloat = status == .passed
            ? CGFloat(AriaFoliaRuntime.easeInOutQuad(
                AriaFoliaRuntime.clamp((time - effectiveEnd) / 5)
            ))
            : 0
        let activePulse: CGFloat = status == .active
            ? CGFloat(sin(max(0, time - start) * 6) * 0.006)
            : 0
        let color = AriaFoliaColor.mix(
            palette.primary,
            palette.accent,
            amount: bodyMix
        )

        Text(text)
            .font(
                breathing > 0.001 && status == .active
                    ? fontChoice.breathingFont(size: fontSize, amount: breathing)
                    : fontChoice.font(size: fontSize, weight: .heavy)
            )
            .foregroundStyle(color)
            .ariaSyntheticBreathingWeight(
                fontChoice: fontChoice,
                amount: breathing,
                active: status == .active
            )
            .opacity(opacity)
            .scaleEffect(scale + activePulse)
            .rotationEffect(.degrees(status == .waiting ? deterministicTilt : 0))
            .offset(y: yOffset - drift * 8)
            .shadow(
                color: palette.accent.opacity(glow * 0.34),
                radius: 4 + CGFloat(glow) * 12
            )
            .animation(.smooth(duration: 0.34), value: status)
    }

    private var opacity: Double {
        switch status {
        case .waiting: return 0.22
        case .active: return 1
        case .passed: return 0.68
        }
    }

    private var scale: CGFloat {
        switch status {
        case .waiting: return 0.985
        case .active: return 1.025
        case .passed: return 1
        }
    }

    private var yOffset: CGFloat {
        switch status {
        case .waiting: return 8
        case .active: return -1
        case .passed: return -2
        }
    }
}

private struct AriaFoliaTokenProxy {
    let start: Double
    let end: Double

    func glow(hints: AriaRenderHints, time: Double) -> Double {
        if hints.revealMode == .instant {
            guard time >= start, time <= hints.renderEndTime else { return 0 }
            return AriaFoliaRuntime.revealProgress(at: time, start: start, duration: 0.067)
        }

        let duration = max(end - start, hints.revealMode == .fast ? 0.045 : 0.1)
        guard time >= start else { return 0 }
        if time <= end {
            let progress = AriaFoliaRuntime.clamp((time - start) / duration)
            if progress < 0.18 {
                return AriaFoliaRuntime.easeOutCubic(progress / 0.18)
            }
            return 1
        }
        let fadeDuration = hints.revealMode == .fast ? 0.14 : 0.9
        return pow(
            1 - AriaFoliaRuntime.clamp((time - end) / fadeDuration),
            2
        )
    }

    func bodyMix(hints: AriaRenderHints, time: Double) -> Double {
        if time < start { return 0 }
        if hints.revealMode == .instant {
            return time <= hints.renderEndTime ? 1 : 0
        }
        if time <= end {
            return AriaFoliaRuntime.clamp((time - start) / max(end - start, 0.05))
        }
        let fadeDuration = hints.revealMode == .fast ? 0.12 : 0.8
        return 1 - AriaFoliaRuntime.clamp((time - end) / fadeDuration)
    }
}

// MARK: - Subtitle

struct AriaSubtitleOverlay: View {
    let translation: String
    let palette: AriaPalette
    /// 已解析的字体值：在舞台侧用主字体 + 主自定义 ID 提前解析，
    /// 避免被外语字体的自定义 ID 覆盖污染（翻译多为中文，恒用主字体）。
    let font: Font

    var body: some View {
        Text(translation.preventingOrphanLastLine())
            .font(font)
            .foregroundStyle(palette.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 34)
            .padding(.vertical, 12)
            .background(.black.opacity(0.18), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}
