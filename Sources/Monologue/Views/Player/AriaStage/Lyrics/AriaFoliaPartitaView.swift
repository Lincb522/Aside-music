//  Folia Partita: semantic phrases arranged as one restrained typographic
//  staircase, with sequential illumination and a continuous visual rhythm.

import SwiftUI
import UIKit

private struct AriaPartitaChunk: Identifiable {
    let id: Int
    let tokens: [AriaFoliaToken]
    let offsetX: CGFloat
    let guideFromLeading: Bool
}

private struct AriaPartitaPlan {
    let chunks: [AriaPartitaChunk]
    let fontSize: CGFloat
    let rowSpacing: CGFloat
}

private enum AriaPartitaLayoutCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: AriaPartitaPlan] = [:]

    static func plan(
        for line: AriaLine,
        size: CGSize,
        fontChoice: AriaLyricFontChoice,
        fontScale: Double
    ) -> AriaPartitaPlan {
        let key = [
            "\(line.id)",
            "\(line.startTime)",
            "\(line.fullText.hashValue)",
            "\(Int(size.width / 8))",
            "\(Int(size.height / 8))",
            fontChoice.cacheIdentity,
            "\(Int(fontScale * 100))"
        ].joined(separator: "|")

        lock.lock()
        defer { lock.unlock() }

        if let cached = storage[key] {
            return cached
        }

        let result = build(
            line: line,
            size: size,
            fontChoice: fontChoice,
            fontScale: fontScale
        )
        if storage.count >= 72 {
            storage.removeAll(keepingCapacity: true)
        }
        storage[key] = result
        return result
    }

    private static func build(
        line: AriaLine,
        size: CGSize,
        fontChoice: AriaLyricFontChoice,
        fontScale: Double
    ) -> AriaPartitaPlan {
        let tokens = AriaFoliaSemanticTokenCache.tokens(for: line)
        guard !tokens.isEmpty else {
            return AriaPartitaPlan(chunks: [], fontSize: 44, rowSpacing: 14)
        }

        let totalGraphemes = max(
            line.fullText.filter { !$0.isWhitespace }.count,
            tokens.count
        )
        let preferredChunkCount: Int
        switch totalGraphemes {
        case ...8:
            preferredChunkCount = 1
        case ...16:
            preferredChunkCount = 2
        case ...28:
            preferredChunkCount = 3
        default:
            preferredChunkCount = 4
        }
        let maximumChunkCount = max(1, Int(floor(max(size.height * 0.62, 100) / 112)))
        let chunkCount = min(
            tokens.count,
            min(preferredChunkCount, maximumChunkCount)
        )
        let chunks = makeBalancedChunks(tokens, count: chunkCount)

        let densityScale: CGFloat = totalGraphemes > 40 ? 0.82 : 1
        var fontSize = min(max(size.width * 0.052, 36), 64)
            * densityScale
            * CGFloat(fontScale)
        let spacing = max(6, fontSize * 0.12)
        let uiFont = fontChoice.uiFont(size: fontSize, weight: .bold)
        let widestChunk = chunks.reduce(CGFloat.zero) { widest, chunk in
            let width = chunk.reduce(CGFloat.zero) { partial, token in
                partial + (token.text as NSString).size(
                    withAttributes: [.font: uiFont]
                ).width
            } + CGFloat(max(chunk.count - 1, 0)) * spacing
            return max(widest, width)
        }
        let allowedWidth = max(size.width * 0.72, 180)
        if widestChunk > allowedWidth {
            fontSize *= max(allowedWidth / widestChunk, 0.58)
        }

        let direction: CGFloat = line.id.isMultiple(of: 2) ? 1 : -1
        let centerIndex = CGFloat(chunks.count - 1) / 2
        let stepDistance = min(max(size.width * 0.042, 22), 38)
        let plans = chunks.enumerated().map { index, chunk -> AriaPartitaChunk in
            return AriaPartitaChunk(
                id: index,
                tokens: chunk,
                offsetX: (CGFloat(index) - centerIndex) * stepDistance * direction,
                guideFromLeading: direction > 0
            )
        }

        return AriaPartitaPlan(
            chunks: plans,
            fontSize: fontSize,
            rowSpacing: min(max(fontSize * 0.24, 12), 20)
        )
    }

    private static func makeBalancedChunks(
        _ tokens: [AriaFoliaToken],
        count: Int
    ) -> [[AriaFoliaToken]] {
        guard count > 1 else { return [tokens] }

        let weights = tokens.map {
            max($0.text.filter { !$0.isWhitespace }.count, 1)
        }
        let proportions = [0.82, 1.12, 0.92, 1.08]
        var chunks: [[AriaFoliaToken]] = []
        var tokenIndex = 0
        var remainingWeight = weights.reduce(0, +)

        for chunkIndex in 0..<count {
            let remainingChunks = count - chunkIndex
            if remainingChunks == 1 {
                chunks.append(Array(tokens[tokenIndex...]))
                break
            }

            let averageWeight = Double(remainingWeight) / Double(remainingChunks)
            let targetWeight = max(
                Int((averageWeight * proportions[chunkIndex % proportions.count]).rounded()),
                1
            )
            let lastAllowedIndex = tokens.count - (remainingChunks - 1)
            let chunkStart = tokenIndex
            var chunkWeight = 0

            while tokenIndex < lastAllowedIndex {
                chunkWeight += weights[tokenIndex]
                tokenIndex += 1
                if chunkWeight >= targetWeight {
                    break
                }
            }

            chunks.append(Array(tokens[chunkStart..<tokenIndex]))
            remainingWeight -= chunkWeight
        }

        return chunks
    }
}

struct AriaPartitaLyricLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            let plan = AriaPartitaLayoutCache.plan(
                for: line,
                size: proxy.size,
                fontChoice: fontChoice,
                fontScale: fontScale
            )
            let floatY = CGFloat(sin(time * 2 * .pi / 8.5) * 4)

            VStack(spacing: plan.rowSpacing) {
                ForEach(plan.chunks) { chunk in
                    PartitaChunkView(
                        chunk: chunk,
                        line: line,
                        palette: palette,
                        fontChoice: fontChoice,
                        fontSize: plan.fontSize,
                        time: time
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .offset(y: floatY)
        }
        .padding(.horizontal, 24)
    }
}

private struct PartitaChunkView: View {
    let chunk: AriaPartitaChunk
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double

    private var startTime: Double {
        chunk.tokens.first?.start ?? line.startTime
    }

    private var endTime: Double {
        guard let token = chunk.tokens.last else { return line.endTime }
        return AriaFoliaRuntime.activeEnd(for: token, hints: line.hints)
    }

    private var status: AriaWordStatus {
        if time >= startTime - line.hints.wordLookahead, time <= endTime {
            return .active
        }
        return time > endTime ? .passed : .waiting
    }

    private var reveal: Double {
        AriaFoliaRuntime.revealProgress(
            at: time,
            start: startTime - line.hints.wordLookahead,
            duration: line.hints.revealMode == .fast ? 0.12 : 0.34
        )
    }

    var body: some View {
        let color = status == .active
            ? palette.accent
            : palette.primary.opacity(status == .passed ? 0.30 : 0.18)
        let entryDirection: CGFloat = chunk.guideFromLeading ? -1 : 1

        HStack(alignment: .firstTextBaseline, spacing: max(6, fontSize * 0.12)) {
            ForEach(chunk.tokens) { token in
                PartitaTokenView(
                    token: token,
                    line: line,
                    palette: palette,
                    fontChoice: fontChoice,
                    fontSize: fontSize,
                    time: time
                )
            }
        }
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            PartitaGuide(
                fromLeading: chunk.guideFromLeading,
                color: color,
                progress: reveal
            )
        }
        .opacity(status == .waiting ? 0.24 + reveal * 0.76 : (status == .passed ? 0.72 : 1))
        .scaleEffect(status == .active ? 1.025 : 0.985)
        .offset(
            x: chunk.offsetX + entryDirection * CGFloat(1 - reveal) * 24,
            y: CGFloat(1 - reveal) * 7
        )
        .blur(radius: status == .waiting ? CGFloat(1 - reveal) * 2.5 : 0)
    }
}

private struct PartitaGuide: View {
    let fromLeading: Bool
    let color: Color
    let progress: Double

    var body: some View {
        ZStack(alignment: fromLeading ? .bottomLeading : .bottomTrailing) {
            Capsule()
                .fill(color)
                .frame(height: 1)
                .scaleEffect(
                    x: progress,
                    y: 1,
                    anchor: fromLeading ? .leading : .trailing
                )

            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .scaleEffect(0.65 + CGFloat(progress) * 0.35)
        }
        .offset(y: 7)
        .shadow(color: color.opacity(0.24), radius: 6)
        .allowsHitTesting(false)
    }
}

private struct PartitaTokenView: View {
    let token: AriaFoliaToken
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double

    private var status: AriaWordStatus {
        AriaFoliaRuntime.status(for: token, hints: line.hints, time: time)
    }

    private var reveal: Double {
        AriaFoliaRuntime.revealProgress(
            at: time,
            start: token.start - line.hints.wordLookahead,
            duration: line.hints.revealMode == .fast ? 0.1 : 0.24
        )
    }

    private var progress: Double {
        AriaFoliaRuntime.bodyMix(for: token, hints: line.hints, time: time)
    }

    var body: some View {
        let activeColor = AriaFoliaColor.mix(
            palette.primary,
            palette.accent,
            amount: progress
        )
        let baseOpacity = status == .waiting ? 0.28 : (status == .passed ? 0.68 : 1)
        let glow = AriaFoliaRuntime.glowEnvelope(
            for: token,
            hints: line.hints,
            time: time
        )

        Text(token.text)
            .font(fontChoice.font(size: fontSize, weight: .bold))
            .foregroundStyle(activeColor)
            .lineLimit(1)
            .fixedSize()
            .opacity(baseOpacity)
            .scaleEffect(status == .active ? 1.08 : 1)
            .blur(radius: status == .waiting ? CGFloat(1 - reveal) * 2 : 0)
            .brightness(status == .active ? 0.06 : 0)
            .shadow(
                color: palette.accent.opacity(glow * 0.58),
                radius: 12
            )
            .shadow(
                color: palette.accent.opacity(glow * 0.18),
                radius: 26
            )
    }
}
