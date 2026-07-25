//  Folia Tilt: sentence-aware 1–4 line composition, progressive line reveal
//  and a single optional italic segment with alternating glyph offsets.

import SwiftUI
import UIKit

private struct AriaTiltGlyph: Identifiable {
    let id: String
    let text: String
    let start: Double
    let end: Double
    let isWhitespace: Bool
}

private struct AriaTiltSegment: Identifiable {
    let id: Int
    let glyphs: [AriaTiltGlyph]
    let isTilt: Bool

    var start: Double { glyphs.first(where: { !$0.isWhitespace })?.start ?? 0 }
    var end: Double { glyphs.last(where: { !$0.isWhitespace })?.end ?? start }
    var visibleGlyphCount: Int { glyphs.filter { !$0.isWhitespace }.count }
}

private struct AriaTiltPlan {
    let segments: [AriaTiltSegment]
    let fontSize: CGFloat
}

private enum AriaTiltLayoutCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: AriaTiltPlan] = [:]
    private static let punctuation = Set("，。；！？、…·.,;!?")

    static func plan(
        for line: AriaLine,
        size: CGSize,
        fontChoice: AriaLyricFontChoice,
        fontScale: Double
    ) -> AriaTiltPlan {
        let key = [
            "\(line.id)",
            "\(line.startTime)",
            "\(line.fullText.hashValue)",
            "\(Int(size.width / 8))",
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
    ) -> AriaTiltPlan {
        let tokens = AriaFoliaSemanticTokenCache.tokens(for: line)
        let glyphs = makeGlyphs(tokens)
        guard !glyphs.isEmpty else {
            return AriaTiltPlan(segments: [], fontSize: 54)
        }

        let characterCount = glyphs.filter { !$0.isWhitespace }.count
        let normalized = log(Double(characterCount + 4)) / log(24)
        let jitter = AriaLyricEngine.seededRandom(line.startTime * 1000, 1) * 0.6 + 0.7
        let score = normalized * jitter * 0.75
        let requestedCount: Int
        if score < 0.45 {
            requestedCount = 1
        } else if score < 1.05 {
            requestedCount = 2
        } else if score < 1.7 {
            requestedCount = 3
        } else {
            requestedCount = 4
        }

        var groups = splitAtPunctuation(glyphs)
        groups = resize(groups, targetCount: min(requestedCount, max(characterCount / 2, 1)))

        if groups.count > 1,
           let last = groups.last,
           visibleCount(last) <= 3 {
            groups[groups.count - 2].append(contentsOf: last)
            groups.removeLast()
        }

        let tiltCandidates = groups.indices.filter { index in
            AriaLyricEngine.seededRandom(line.startTime * 1000, Double(100 + index)) < 0.35
        }
        let tiltIndex: Int? = {
            guard !tiltCandidates.isEmpty else { return nil }
            let roll = AriaLyricEngine.seededRandom(line.startTime * 1000, 200)
            return tiltCandidates[min(Int(roll * Double(tiltCandidates.count)), tiltCandidates.count - 1)]
        }()

        let baseFontSize = min(
            max(size.width * 0.06875 * CGFloat(fontScale), 50 * CGFloat(fontScale)),
            90 * CGFloat(fontScale)
        )
        let regularFont = fontChoice.uiFont(size: baseFontSize, weight: .regular)
        let italicFont = italicized(regularFont)
        let availableWidth = max(size.width * 0.85, 220)
        var widest: CGFloat = 0

        for (index, group) in groups.enumerated() {
            let text = group.map(\.text).joined()
            let font = index == tiltIndex ? italicFont : regularFont
            let tracking = baseFontSize * (index == tiltIndex ? 0.15 : 0.08)
            let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
                + CGFloat(max(visibleCount(group) - 1, 0)) * tracking
            widest = max(widest, textWidth)
        }

        let scale = widest > availableWidth
            ? max(availableWidth / widest, tiltIndex == nil ? 0.55 : 0.5)
            : 1
        let segments = groups.enumerated().map { index, group in
            AriaTiltSegment(
                id: index,
                glyphs: trimWhitespace(group),
                isTilt: index == tiltIndex
            )
        }

        return AriaTiltPlan(
            segments: segments,
            fontSize: baseFontSize * scale
        )
    }

    private static func makeGlyphs(_ tokens: [AriaFoliaToken]) -> [AriaTiltGlyph] {
        var output: [AriaTiltGlyph] = []

        for (tokenIndex, token) in tokens.enumerated() {
            if tokenIndex > 0,
               let previous = tokens[safe: tokenIndex - 1],
               needsSpace(between: previous.text, and: token.text) {
                output.append(
                    AriaTiltGlyph(
                        id: "space-\(tokenIndex)",
                        text: " ",
                        start: token.start,
                        end: token.start,
                        isWhitespace: true
                    )
                )
            }

            let graphemes = token.graphemes.isEmpty
                ? [AriaGrapheme(char: token.text, startTime: token.start, endTime: token.end)]
                : token.graphemes
            output.append(contentsOf: graphemes.enumerated().map { index, grapheme in
                AriaTiltGlyph(
                    id: "\(token.id)-\(index)",
                    text: grapheme.char,
                    start: grapheme.startTime,
                    end: grapheme.endTime,
                    isWhitespace: grapheme.char.allSatisfy(\.isWhitespace)
                )
            })
        }
        return output
    }

    private static func needsSpace(between lhs: String, and rhs: String) -> Bool {
        guard let left = lhs.last, let right = rhs.first else { return false }
        return !AriaLyricEngine.isCJKChar(left)
            && !AriaLyricEngine.isCJKChar(right)
            && !punctuation.contains(right)
    }

    private static func splitAtPunctuation(
        _ glyphs: [AriaTiltGlyph]
    ) -> [[AriaTiltGlyph]] {
        var groups: [[AriaTiltGlyph]] = [[]]
        for glyph in glyphs {
            groups[groups.count - 1].append(glyph)
            if glyph.text.last.map({ punctuation.contains($0) }) == true {
                groups.append([])
            }
        }
        groups.removeAll { trimWhitespace($0).isEmpty }
        return groups.isEmpty ? [glyphs] : groups
    }

    private static func resize(
        _ input: [[AriaTiltGlyph]],
        targetCount: Int
    ) -> [[AriaTiltGlyph]] {
        let targetCount = max(targetCount, 1)
        var groups = input.map(trimWhitespace)

        while groups.count > targetCount {
            var bestIndex = 0
            var bestLength = Int.max
            for index in 0..<(groups.count - 1) {
                let length = visibleCount(groups[index]) + visibleCount(groups[index + 1])
                if length < bestLength {
                    bestLength = length
                    bestIndex = index
                }
            }
            groups[bestIndex].append(contentsOf: groups[bestIndex + 1])
            groups.remove(at: bestIndex + 1)
        }

        while groups.count < targetCount {
            guard let candidateIndex = groups.indices.max(
                by: { visibleCount(groups[$0]) < visibleCount(groups[$1]) }
            ), visibleCount(groups[candidateIndex]) > 3 else {
                break
            }

            let group = groups[candidateIndex]
            let midpoint = group.count / 2
            let whitespaceIndices = group.indices.filter { group[$0].isWhitespace }
            let splitIndex = whitespaceIndices.min {
                abs($0 - midpoint) < abs($1 - midpoint)
            }.map { $0 + 1 } ?? midpoint

            guard splitIndex > 0, splitIndex < group.count else { break }
            let first = trimWhitespace(Array(group[..<splitIndex]))
            let second = trimWhitespace(Array(group[splitIndex...]))
            guard !first.isEmpty, !second.isEmpty else { break }
            groups.replaceSubrange(candidateIndex...candidateIndex, with: [first, second])
        }

        return groups
    }

    private static func visibleCount(_ glyphs: [AriaTiltGlyph]) -> Int {
        glyphs.filter { !$0.isWhitespace }.count
    }

    private static func trimWhitespace(
        _ glyphs: [AriaTiltGlyph]
    ) -> [AriaTiltGlyph] {
        guard let first = glyphs.firstIndex(where: { !$0.isWhitespace }),
              let last = glyphs.lastIndex(where: { !$0.isWhitespace }) else {
            return []
        }
        return Array(glyphs[first...last])
    }

    private static func italicized(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}

struct AriaTiltLyricLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            let plan = AriaTiltLayoutCache.plan(
                for: line,
                size: proxy.size,
                fontChoice: fontChoice,
                fontScale: fontScale
            )
            let visibleIndex = latestVisibleIndex(in: plan.segments)

            VStack(spacing: max(12, plan.fontSize * 0.12)) {
                ForEach(plan.segments) { segment in
                    TiltLineView(
                        segment: segment,
                        visible: segment.id <= visibleIndex,
                        palette: palette,
                        fontChoice: fontChoice,
                        fontSize: plan.fontSize,
                        time: time
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, 24)
    }

    private func latestVisibleIndex(in segments: [AriaTiltSegment]) -> Int {
        guard time >= line.startTime - 0.1,
              time <= line.hints.renderEndTime else {
            return -1
        }

        var result = -1
        for segment in segments where time >= segment.start - 0.25 {
            result = segment.id
        }
        return result
    }
}

private struct TiltLineView: View {
    let segment: AriaTiltSegment
    let visible: Bool
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double

    var body: some View {
        let tracking = fontSize * (segment.isTilt ? 0.15 : 0.08)
        let yOffset = fontSize / 6

        HStack(spacing: tracking) {
            ForEach(Array(segment.glyphs.enumerated()), id: \.element.id) { index, glyph in
                TiltGlyphView(
                    glyph: glyph,
                    glyphIndex: index,
                    visible: visible,
                    isTilt: segment.isTilt,
                    palette: palette,
                    fontChoice: fontChoice,
                    fontSize: fontSize,
                    yOffset: yOffset,
                    segmentStart: segment.start,
                    time: time
                )
            }
        }
        .fixedSize()
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : (segment.isTilt ? 24 : 20))
        .scaleEffect(visible ? 1 : (segment.isTilt ? 0.92 : 1))
    }
}

private struct TiltGlyphView: View {
    let glyph: AriaTiltGlyph
    let glyphIndex: Int
    let visible: Bool
    let isTilt: Bool
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let yOffset: CGFloat
    let segmentStart: Double
    let time: Double

    var body: some View {
        if glyph.isWhitespace {
            Color.clear
                .frame(width: fontSize * (isTilt ? 0.35 : 0.25), height: fontSize)
        } else {
            let entryStart = segmentStart - 0.25 + Double(glyphIndex) * (isTilt ? 0.05 : 0.04)
            let entry = visible
                ? AriaFoliaRuntime.revealProgress(
                    at: time,
                    start: entryStart,
                    duration: 0.5
                )
                : 0
            let staggerDirection: CGFloat = glyphIndex.isMultiple(of: 2) ? -1 : 1
            let targetY = isTilt ? staggerDirection * yOffset : 0
            let pulse = pulseIntensity

            Text(glyph.text)
                .font(
                    fontChoice.font(
                        size: fontSize,
                        weight: isTilt ? .light : .regular
                    )
                )
                .italic(isTilt)
                .foregroundStyle(isTilt ? palette.accent : palette.primary)
                .lineLimit(1)
                .fixedSize()
                .opacity(entry)
                .scaleEffect(1 + CGFloat(pulse) * (isTilt ? 0.18 : 0.15))
                .offset(
                    y: targetY + (1 - CGFloat(entry)) * targetY
                )
        }
    }

    private var pulseIntensity: Double {
        let rawDuration = max(glyph.end - glyph.start, 0.05)
        let duration = min(max(rawDuration, 0.2), 0.9)
        let elapsed = time - glyph.start
        guard elapsed >= 0 else { return 0 }

        if elapsed <= duration {
            return sin(elapsed / duration * .pi)
        }

        let afterElapsed = elapsed - duration
        let afterglowRamp = duration * 1.2
        guard afterElapsed < afterglowRamp else { return 0.25 }
        return 0.25 * (afterElapsed / afterglowRamp)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
