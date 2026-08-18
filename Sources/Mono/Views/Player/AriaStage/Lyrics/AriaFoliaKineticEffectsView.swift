//  Three lightweight immersive lyric effects. They only replace the lyric
//  renderer; background, player structure and the shared lyric timeline stay
//  untouched. Expensive line measurement is cached and every frame only
//  updates scalar transforms and colors.

import SwiftUI
import UIKit

// MARK: - Shared measured layout

private struct AriaKineticToken: Identifiable {
    let token: AriaFoliaToken
    let ordinal: Int

    var id: Int { token.id }
}

private struct AriaKineticRow: Identifiable {
    let id: Int
    let tokens: [AriaKineticToken]
}

private struct AriaKineticPlan {
    let rows: [AriaKineticRow]
    let fontSize: CGFloat
    let tokenSpacing: CGFloat
    let rowSpacing: CGFloat
    let tokenCount: Int
}

private enum AriaKineticLayoutCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: AriaKineticPlan] = [:]

    static func plan(
        for line: AriaLine,
        size: CGSize,
        fontChoice: AriaLyricFontChoice,
        fontScale: Double
    ) -> AriaKineticPlan {
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
        if let cached = storage[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result = build(
            line: line,
            size: size,
            fontChoice: fontChoice,
            fontScale: fontScale
        )

        lock.lock()
        if storage.count >= 96 {
            storage.removeAll(keepingCapacity: true)
        }
        storage[key] = result
        lock.unlock()
        return result
    }

    private static func build(
        line: AriaLine,
        size: CGSize,
        fontChoice: AriaLyricFontChoice,
        fontScale: Double
    ) -> AriaKineticPlan {
        let source = AriaFoliaSemanticTokenCache.tokens(for: line)
        let tokens = source.enumerated().map {
            AriaKineticToken(token: $0.element, ordinal: $0.offset)
        }
        guard !tokens.isEmpty else {
            return AriaKineticPlan(
                rows: [],
                fontSize: 48,
                tokenSpacing: 8,
                rowSpacing: 14,
                tokenCount: 0
            )
        }

        let glyphCount = max(line.fullText.filter { !$0.isWhitespace }.count, 1)
        let scale = CGFloat(fontScale)
        let widthBase = min(max(size.width * 0.074, 40), 78)
        let densityPenalty = min(CGFloat(max(glyphCount - 12, 0)) * 1.05, 28)
        var fontSize = min(max((widthBase - densityPenalty) * scale, 30), 92)
        let availableWidth = max(min(size.width * 0.84, size.width - 56), 220)
        var rows: [[AriaKineticToken]] = []
        var spacing: CGFloat = 8

        // At most three passes; line measurement never runs on the animation
        // path again after this plan enters the cache.
        for _ in 0..<3 {
            spacing = max(3, min(fontSize * 0.13, 12))
            rows = makeRows(
                tokens: tokens,
                availableWidth: availableWidth,
                font: fontChoice.uiFont(size: fontSize, weight: .bold),
                spacing: spacing
            )
            if rows.count <= 3 { break }
            fontSize = max(fontSize * 0.82, 26)
        }

        // Extremely long malformed lines still remain bounded: overflow rows
        // are merged into the third line and the existing lyric viewport clips
        // them instead of expanding the whole stage.
        if rows.count > 3 {
            let overflow = rows.dropFirst(2).flatMap { $0 }
            rows = [rows[0], rows[1], overflow]
        }

        return AriaKineticPlan(
            rows: rows.enumerated().map { AriaKineticRow(id: $0.offset, tokens: $0.element) },
            fontSize: fontSize,
            tokenSpacing: spacing,
            rowSpacing: max(10, min(fontSize * 0.24, 20)),
            tokenCount: tokens.count
        )
    }

    private static func makeRows(
        tokens: [AriaKineticToken],
        availableWidth: CGFloat,
        font: UIFont,
        spacing: CGFloat
    ) -> [[AriaKineticToken]] {
        var rows: [[AriaKineticToken]] = [[]]
        var rowWidth: CGFloat = 0

        for token in tokens {
            let measured = (token.token.text as NSString).size(
                withAttributes: [.font: font]
            ).width
            let width = min(max(measured, font.pointSize * 0.2), availableWidth)
            let proposed = rowWidth + (rows[rows.count - 1].isEmpty ? 0 : spacing) + width
            if proposed > availableWidth, !rows[rows.count - 1].isEmpty {
                rows.append([token])
                rowWidth = width
            } else {
                rows[rows.count - 1].append(token)
                rowWidth = proposed
            }
        }
        return rows
    }
}

private enum AriaKineticMetrics {
    static func lineProgress(_ line: AriaLine, time: Double) -> Double {
        AriaFoliaRuntime.clamp(
            (time - line.startTime) / max(line.rawDuration, 0.1)
        )
    }

    static func opacity(
        for token: AriaFoliaToken,
        line: AriaLine,
        time: Double
    ) -> Double {
        switch AriaFoliaRuntime.status(for: token, hints: line.hints, time: time) {
        case .waiting:
            let approach = AriaFoliaRuntime.clamp((time - token.start + 0.5) / 0.5)
            return AriaFoliaRuntime.mix(0.18, 0.42, approach)
        case .active:
            return 1
        case .passed:
            return AriaFoliaRuntime.mix(
                0.78,
                0.52,
                AriaFoliaRuntime.passedDrift(for: token, time: time)
            )
        }
    }
}

// MARK: - 潮汐

struct AriaTideLyricLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let plan = AriaKineticLayoutCache.plan(
                for: line,
                size: proxy.size,
                fontChoice: fontChoice,
                fontScale: fontScale
            )
            let lineProgress = AriaKineticMetrics.lineProgress(line, time: time)
            let colorMixer = AriaFoliaColor.mixer(palette.primary, palette.accent)
            let font = fontChoice.font(size: plan.fontSize, weight: .bold)

            VStack(spacing: plan.rowSpacing) {
                ForEach(plan.rows) { row in
                    HStack(alignment: .center, spacing: plan.tokenSpacing) {
                        ForEach(row.tokens) { item in
                            tideToken(
                                item,
                                plan: plan,
                                lineProgress: lineProgress,
                                colorMixer: colorMixer,
                                font: font
                            )
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .offset(y: reduceMotion ? 0 : CGFloat(sin(time * 0.55)) * 2)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.fullText)
    }

    private func tideToken(
        _ item: AriaKineticToken,
        plan: AriaKineticPlan,
        lineProgress: Double,
        colorMixer: AriaFoliaColor.Mixer,
        font: Font
    ) -> some View {
        let token = item.token
        let status = AriaFoliaRuntime.status(for: token, hints: line.hints, time: time)
        let glow = AriaFoliaRuntime.glowEnvelope(for: token, hints: line.hints, time: time)
        let phase = Double(item.ordinal) * 0.72 + lineProgress * .pi * 1.35
        let wave = reduceMotion ? 0 : sin(phase)
        let activeLift = status == .active ? -5.0 * glow : 0
        let offsetY = CGFloat(wave * 8 + activeLift)
        let color = colorMixer.color(
            amount: status == .active ? 0.32 + glow * 0.68 : 0
        )

        return Text(token.text)
            .font(font)
            .foregroundStyle(color)
            .opacity(AriaKineticMetrics.opacity(for: token, line: line, time: time))
            .scaleEffect(1 + CGFloat(glow) * 0.045)
            .offset(y: offsetY)
            .modifier(
                AriaKineticGlowModifier(
                    color: palette.accent,
                    opacity: status == .active ? 0.38 * glow : 0,
                    radius: 8
                )
            )
    }
}

// MARK: - 回响

struct AriaEchoLyricLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let plan = AriaKineticLayoutCache.plan(
                for: line,
                size: proxy.size,
                fontChoice: fontChoice,
                fontScale: fontScale
            )
            let progress = AriaKineticMetrics.lineProgress(line, time: time)
            let direction: CGFloat = line.id.isMultiple(of: 2) ? 1 : -1
            let spread = reduceMotion ? 0 : CGFloat(0.35 + progress * 0.65)
            let colorMixer = AriaFoliaColor.mixer(palette.primary, palette.accent)
            let font = fontChoice.font(size: plan.fontSize, weight: .bold)

            ZStack {
                echoLayer(
                    plan: plan,
                    color: palette.secondary,
                    opacity: 0.12,
                    offset: CGSize(width: direction * 22 * spread, height: -14 * spread),
                    scale: 0.965,
                    blur: reduceMotion ? 0 : 1.5,
                    isPrimary: false,
                    colorMixer: colorMixer,
                    font: font
                )

                echoLayer(
                    plan: plan,
                    color: palette.accent,
                    opacity: 0.22,
                    offset: CGSize(width: direction * 11 * spread, height: -7 * spread),
                    scale: 0.985,
                    blur: 0,
                    isPrimary: false,
                    colorMixer: colorMixer,
                    font: font
                )

                echoLayer(
                    plan: plan,
                    color: palette.primary,
                    opacity: 1,
                    offset: .zero,
                    scale: 1,
                    blur: 0,
                    isPrimary: true,
                    colorMixer: colorMixer,
                    font: font
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.fullText)
    }

    private func echoLayer(
        plan: AriaKineticPlan,
        color: Color,
        opacity: Double,
        offset: CGSize,
        scale: CGFloat,
        blur: CGFloat,
        isPrimary: Bool,
        colorMixer: AriaFoliaColor.Mixer,
        font: Font
    ) -> some View {
        VStack(spacing: plan.rowSpacing) {
            ForEach(plan.rows) { row in
                HStack(spacing: plan.tokenSpacing) {
                    ForEach(row.tokens) { item in
                        echoToken(
                            item,
                            plan: plan,
                            color: color,
                            isPrimary: isPrimary,
                            colorMixer: colorMixer,
                            font: font
                        )
                    }
                }
            }
        }
        .opacity(opacity)
        .offset(offset)
        .scaleEffect(scale)
        .blur(radius: blur)
    }

    private func echoToken(
        _ item: AriaKineticToken,
        plan: AriaKineticPlan,
        color: Color,
        isPrimary: Bool,
        colorMixer: AriaFoliaColor.Mixer,
        font: Font
    ) -> some View {
        let token = item.token
        let status = AriaFoliaRuntime.status(for: token, hints: line.hints, time: time)
        let glow = AriaFoliaRuntime.glowEnvelope(for: token, hints: line.hints, time: time)
        let resolvedColor = isPrimary
            ? colorMixer.color(amount: status == .active ? 0.25 + glow * 0.75 : 0)
            : color

        return Text(token.text)
            .font(font)
            .foregroundStyle(resolvedColor)
            .opacity(
                isPrimary
                    ? AriaKineticMetrics.opacity(for: token, line: line, time: time)
                    : max(0.35, AriaKineticMetrics.opacity(for: token, line: line, time: time))
            )
            .modifier(
                AriaKineticGlowModifier(
                    color: palette.accent,
                    opacity: isPrimary && status == .active ? 0.42 * glow : 0,
                    radius: 9
                )
            )
    }
}

private struct AriaKineticGlowModifier: ViewModifier {
    let color: Color
    let opacity: Double
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if opacity > 0.001 {
            content.shadow(color: color.opacity(opacity), radius: radius)
        } else {
            content
        }
    }
}

// MARK: - 折光

struct AriaRefractionLyricLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let plan = AriaKineticLayoutCache.plan(
                for: line,
                size: proxy.size,
                fontChoice: fontChoice,
                fontScale: fontScale
            )
            let colorMixer = AriaFoliaColor.mixer(palette.primary, palette.accent)
            let font = fontChoice.font(size: plan.fontSize, weight: .bold)

            VStack(spacing: plan.rowSpacing) {
                ForEach(plan.rows) { row in
                    HStack(spacing: plan.tokenSpacing) {
                        ForEach(row.tokens) { item in
                            refractedToken(
                                item,
                                plan: plan,
                                colorMixer: colorMixer,
                                font: font
                            )
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.fullText)
    }

    private func refractedToken(
        _ item: AriaKineticToken,
        plan: AriaKineticPlan,
        colorMixer: AriaFoliaColor.Mixer,
        font: Font
    ) -> some View {
        let token = item.token
        let status = AriaFoliaRuntime.status(for: token, hints: line.hints, time: time)
        let glow = AriaFoliaRuntime.glowEnvelope(for: token, hints: line.hints, time: time)
        let wordProgress = AriaFoliaRuntime.progress(for: token, time: time)
        // 折光只在当前词内部完成一次「分片 → 聚合」。与回响的整句纵深
        // 副本不同，唱过的字不会留下任何彩色余影。
        let prismEnvelope = status == .active
            ? sin(AriaFoliaRuntime.clamp(wordProgress) * .pi)
            : 0
        let split = reduceMotion ? 0 : CGFloat(prismEnvelope) * 6.5
        let opacity = AriaKineticMetrics.opacity(for: token, line: line, time: time)
        let bandHeight = max(plan.fontSize * 0.34, 10)
        let baseColor = colorMixer.color(
            amount: status == .active ? 0.12 + glow * 0.28 : 0
        )

        return ZStack {
            Text(token.text)
                .font(font)
                .foregroundStyle(baseColor)

            if status == .active, !reduceMotion {
                prismBand(
                    text: token.text,
                    font: font,
                    color: palette.secondary,
                    alignment: .top,
                    height: bandHeight,
                    offsetX: -split,
                    opacity: 0.34 + prismEnvelope * 0.34
                )

                prismBand(
                    text: token.text,
                    font: font,
                    color: palette.accent,
                    alignment: .center,
                    height: bandHeight * 0.72,
                    offsetX: split * 0.38,
                    opacity: 0.28 + prismEnvelope * 0.26
                )

                prismBand(
                    text: token.text,
                    font: font,
                    color: palette.accent,
                    alignment: .bottom,
                    height: bandHeight,
                    offsetX: split,
                    opacity: 0.38 + prismEnvelope * 0.38
                )
            }
        }
        .opacity(opacity)
        .scaleEffect(1 + CGFloat(prismEnvelope) * 0.018)
    }

    private func prismBand(
        text: String,
        font: Font,
        color: Color,
        alignment: Alignment,
        height: CGFloat,
        offsetX: CGFloat,
        opacity: Double
    ) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .mask(alignment: alignment) {
                Rectangle()
                    .frame(height: height)
            }
            .offset(x: offsetX)
            .opacity(opacity)
            .blendMode(.plusLighter)
    }
}
