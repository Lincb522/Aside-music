//
//  AriaFoliaCadenzaView.swift
//  Monologue
//
//  Folia Cadenza: measured semantic fragments, one centered hero and
//  collision-aware surrounding placements. No random single-character rows.
//

import SwiftUI
import UIKit

private struct AriaCadenzaPlacement: Identifiable {
    let token: AriaFoliaToken
    let center: CGPoint
    let width: CGFloat
    let height: CGFloat
    let baseScale: CGFloat
    let passedRotation: Double
    let passedDrift: CGVector
    let isHero: Bool

    var id: Int { token.id }
}

private struct AriaCadenzaPlan {
    let fontSize: CGFloat
    let placements: [AriaCadenzaPlacement]
}

private enum AriaCadenzaLayoutCache {
    private struct Draft {
        let token: AriaFoliaToken
        let center: CGPoint
        let width: CGFloat
        let height: CGFloat
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: AriaCadenzaPlan] = [:]

    static func plan(
        for line: AriaLine,
        size: CGSize,
        fontChoice: AriaLyricFontChoice,
        fontScale: Double
    ) -> AriaCadenzaPlan {
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
    ) -> AriaCadenzaPlan {
        let tokens = AriaFoliaSemanticTokenCache.tokens(for: line)
        guard !tokens.isEmpty, size.width > 0, size.height > 0 else {
            return AriaCadenzaPlan(fontSize: 44, placements: [])
        }

        let graphemeCount = max(
            line.fullText.filter { !$0.isWhitespace }.count,
            1
        )
        let widthBase = min(max(size.width * 0.086, 34), 94)
        let lengthPenalty = graphemeCount > 12
            ? min(CGFloat(graphemeCount - 12) * 1.8, 34)
            : 0
        let densityPenalty = tokens.count > 7
            ? min(CGFloat(tokens.count - 7) * 1.5, 18)
            : 0
        let fontSize = min(
            max((widthBase - lengthPenalty - densityPenalty) * CGFloat(fontScale) * 1.12, 28),
            110
        )
        let uiFont = fontChoice.uiFont(size: fontSize, weight: .bold)
        let lineHeight = round(fontSize * 1.16)
        let availableWidth = max(size.width - 56, 160)
        let maxWidth = min(max(size.width * 0.72, min(220, availableWidth)), availableWidth)
        let spacing = max(8, fontSize * 0.14)

        let measured = tokens.map { token -> (AriaFoliaToken, CGFloat, CGFloat) in
            let rawWidth = (token.text as NSString).size(withAttributes: [.font: uiFont]).width
            return (
                token,
                min(max(rawWidth, fontSize * 0.2), maxWidth),
                fontSize * 1.02
            )
        }

        var rows: [[Int]] = [[]]
        var rowWidth: CGFloat = 0
        for index in measured.indices {
            let width = measured[index].1
            let proposed = rowWidth + (rows[rows.count - 1].isEmpty ? 0 : spacing) + width
            if proposed > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([index])
                rowWidth = width
            } else {
                rows[rows.count - 1].append(index)
                rowWidth = proposed
            }
        }

        let totalHeight = CGFloat(rows.count) * lineHeight
        var drafts: [Draft] = []
        for (rowIndex, row) in rows.enumerated() {
            let width = row.reduce(CGFloat.zero) { $0 + measured[$1].1 }
                + CGFloat(max(row.count - 1, 0)) * spacing
            var cursor = -width / 2
            let y = -totalHeight / 2 + lineHeight * (CGFloat(rowIndex) + 0.5)

            for itemIndex in row {
                let item = measured[itemIndex]
                drafts.append(
                    Draft(
                        token: item.0,
                        center: CGPoint(x: cursor + item.1 / 2, y: y),
                        width: item.1,
                        height: item.2
                    )
                )
                cursor += item.1 + spacing
            }
        }

        let centerIndex = Double(max(drafts.count - 1, 0)) / 2
        let heroID = drafts.enumerated().max { lhs, rhs in
            heroScore(
                lhs.element,
                index: lhs.offset,
                centerIndex: centerIndex,
                totalCount: drafts.count
            ) < heroScore(
                rhs.element,
                index: rhs.offset,
                centerIndex: centerIndex,
                totalCount: drafts.count
            )
        }?.element.token.id

        guard let heroDraft = drafts.first(where: { $0.token.id == heroID }) else {
            return AriaCadenzaPlan(fontSize: fontSize, placements: [])
        }

        let heroScale: CGFloat = 1.46
        let heroPlacement = makePlacement(
            draft: heroDraft,
            center: .zero,
            scale: heroScale,
            isHero: true,
            lineSeed: line.startTime
        )
        var occupied = [
            collisionRect(for: heroPlacement, padding: max(10, fontSize * 0.16))
        ]
        var placements: [AriaCadenzaPlacement] = []

        for (index, draft) in drafts.enumerated() where draft.token.id != heroID {
            let scale: CGFloat = 1.01
            var preferred = draft.center
            let heroRect = occupied[0].insetBy(dx: -fontSize * 0.22, dy: -fontSize * 0.16)
            let preferredRect = rect(
                center: preferred,
                width: draft.width * scale,
                height: draft.height * scale
            )

            if preferredRect.intersects(heroRect) {
                var direction = CGVector(dx: preferred.x, dy: preferred.y)
                if abs(direction.dx) + abs(direction.dy) < 1 {
                    let angle = Double(index) * 2.399963
                    direction = CGVector(dx: cos(angle), dy: sin(angle))
                }
                let length = max(hypot(direction.dx, direction.dy), 1)
                direction.dx /= length
                direction.dy /= length
                preferred.x += direction.dx * (fontSize * 0.92)
                preferred.y += direction.dy * (fontSize * 0.72)
            }

            let chosen = collisionFreeCenter(
                preferred: preferred,
                width: draft.width * scale,
                height: draft.height * scale,
                occupied: occupied,
                bounds: CGRect(
                    x: -size.width * 0.47,
                    y: -size.height * 0.40,
                    width: size.width * 0.94,
                    height: size.height * 0.80
                ),
                step: max(9, fontSize * 0.13),
                maxRadius: max(fontSize * 2.2, draft.width * 0.72),
                seed: line.startTime + Double(index) * 17
            )
            let placement = makePlacement(
                draft: draft,
                center: chosen,
                scale: scale,
                isHero: false,
                lineSeed: line.startTime
            )
            placements.append(placement)
            occupied.append(
                collisionRect(for: placement, padding: max(5, fontSize * 0.08))
            )
        }

        placements.append(heroPlacement)
        return AriaCadenzaPlan(fontSize: fontSize, placements: placements)
    }

    private static func heroScore(
        _ draft: Draft,
        index: Int,
        centerIndex: Double,
        totalCount: Int
    ) -> Double {
        let count = max(draft.token.text.filter { !$0.isWhitespace }.count, 1)
        let semanticWeight = draft.token.isCJK
            ? min(Double(count) * 0.18, 0.54)
            : min(Double(count) * 0.08, 0.36)
        let centerBias = 1
            - abs(Double(index) - centerIndex) / Double(max(totalCount, 1))
        return semanticWeight + max(centerBias, 0) * 0.18
    }

    private static func makePlacement(
        draft: Draft,
        center: CGPoint,
        scale: CGFloat,
        isHero: Bool,
        lineSeed: Double
    ) -> AriaCadenzaPlacement {
        let seed = lineSeed + Double(draft.token.id) * 17
        let rotation = (AriaLyricEngine.seededRandom(seed, 3) - 0.5) * 12
        let outwardLength = max(hypot(center.x, center.y), 1)
        let driftAmount = isHero
            ? 4 + AriaLyricEngine.seededRandom(seed, 6) * 4
            : 5 + AriaLyricEngine.seededRandom(seed, 6) * 6
        return AriaCadenzaPlacement(
            token: draft.token,
            center: center,
            width: draft.width,
            height: draft.height,
            baseScale: scale,
            passedRotation: rotation,
            passedDrift: CGVector(
                dx: center.x / outwardLength * driftAmount,
                dy: center.y / outwardLength * driftAmount * 0.72
            ),
            isHero: isHero
        )
    }

    private static func collisionFreeCenter(
        preferred: CGPoint,
        width: CGFloat,
        height: CGFloat,
        occupied: [CGRect],
        bounds: CGRect,
        step: CGFloat,
        maxRadius: CGFloat,
        seed: Double
    ) -> CGPoint {
        var best = preferred
        var bestOverlap = CGFloat.greatestFiniteMagnitude
        let baseAngle = atan2(preferred.y, preferred.x)
            + CGFloat(AriaLyricEngine.seededRandom(seed, 4) - 0.5) * 0.35

        var radius: CGFloat = 0
        while radius <= maxRadius {
            let samples = radius == 0
                ? 1
                : max(12, Int((2 * .pi * radius / max(step, 1)).rounded()))

            for sample in 0..<samples {
                let angle = baseAngle + CGFloat(sample) / CGFloat(samples) * 2 * .pi
                let candidate = CGPoint(
                    x: preferred.x + cos(angle) * radius,
                    y: preferred.y + sin(angle) * radius * 0.9
                )
                let candidateRect = rect(
                    center: candidate,
                    width: width + step,
                    height: height + step
                )
                guard bounds.contains(candidateRect) else { continue }

                let overlap = occupied.reduce(CGFloat.zero) { partial, existing in
                    partial + overlapArea(candidateRect, existing)
                }
                if overlap < bestOverlap {
                    best = candidate
                    bestOverlap = overlap
                }
                if overlap <= 0.5 {
                    return candidate
                }
            }
            radius += step
        }
        return best
    }

    private static func collisionRect(
        for placement: AriaCadenzaPlacement,
        padding: CGFloat
    ) -> CGRect {
        rect(
            center: placement.center,
            width: placement.width * placement.baseScale + padding * 2,
            height: placement.height * placement.baseScale + padding * 2
        )
    }

    private static func rect(center: CGPoint, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }

    private static func overlapArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}

struct AriaCadenzaLyricLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            let plan = AriaCadenzaLayoutCache.plan(
                for: line,
                size: proxy.size,
                fontChoice: fontChoice,
                fontScale: fontScale
            )

            ZStack {
                ForEach(plan.placements) { placement in
                    CadenzaPlacementView(
                        placement: placement,
                        line: line,
                        palette: palette,
                        fontChoice: fontChoice,
                        fontSize: plan.fontSize,
                        time: time
                    )
                    .position(
                        x: proxy.size.width / 2 + placement.center.x,
                        y: proxy.size.height * 0.46 + placement.center.y
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, 12)
    }
}

private struct CadenzaPlacementView: View {
    let placement: AriaCadenzaPlacement
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double

    private var status: AriaWordStatus {
        AriaFoliaRuntime.status(
            for: placement.token,
            hints: line.hints,
            time: time
        )
    }

    private var reveal: Double {
        AriaFoliaRuntime.revealProgress(
            at: time,
            start: placement.token.start - line.hints.wordLookahead,
            duration: line.hints.revealMode == .fast ? 0.12 : 0.28
        )
    }

    private var bodyMix: Double {
        AriaFoliaRuntime.bodyMix(
            for: placement.token,
            hints: line.hints,
            time: time
        )
    }

    private var glow: Double {
        AriaFoliaRuntime.glowEnvelope(
            for: placement.token,
            hints: line.hints,
            time: time
        )
    }

    private var passedProgress: Double {
        AriaFoliaRuntime.passedDrift(for: placement.token, time: time)
    }

    var body: some View {
        let activePulse = status == .active
            ? 1 + sin(time * 10 + placement.token.start * 5) * 0.04
            : 1
        let targetScale: CGFloat = {
            switch status {
            case .waiting:
                return max(placement.baseScale * 0.5, 0.5)
            case .active:
                return placement.baseScale * 1.3 * CGFloat(activePulse)
            case .passed:
                return placement.baseScale
            }
        }()
        let opacity: Double = {
            switch status {
            case .waiting: return 0
            case .active: return 1
            case .passed: return 0.82
            }
        }()
        let color = AriaFoliaColor.mix(
            palette.primary,
            palette.accent,
            amount: bodyMix
        )
        let rotation: Double = {
            switch status {
            case .waiting: return 20
            case .active: return 0
            case .passed: return placement.passedRotation * passedProgress
            }
        }()
        let floatX = sin(time * 1.2 + Double(placement.token.id) * 0.6) * 1.8
        let floatY = cos(time * 1.5 + Double(placement.token.id) * 0.4) * 1.2

        ZStack {
            if status == .active {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, palette.accent.opacity(0.26), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: placement.width * 1.12, height: 2)
                    .blur(radius: 3)
                    .offset(y: placement.height * 0.40)
            }

            Text(placement.token.text)
                .font(fontChoice.font(size: fontSize, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .shadow(
                    color: palette.accent.opacity(glow * 0.78),
                    radius: 20
                )
                .shadow(
                    color: palette.accent.opacity(glow * 0.28),
                    radius: 40
                )

            if line.isChorus, status == .active {
                Circle()
                    .stroke(palette.accent.opacity((1 - bodyMix) * 0.42), lineWidth: 1)
                    .frame(
                        width: max(placement.width, placement.height) * CGFloat(0.7 + bodyMix * 0.5),
                        height: max(placement.width, placement.height) * CGFloat(0.7 + bodyMix * 0.5)
                    )
            }
        }
        .frame(width: placement.width, height: placement.height)
        .opacity(opacity)
        .scaleEffect(targetScale)
        .rotationEffect(.degrees(rotation))
        .offset(
            x: floatX + placement.passedDrift.dx * passedProgress,
            y: floatY + placement.passedDrift.dy * passedProgress
        )
        .blur(radius: status == .waiting ? CGFloat((1 - reveal) * 10) : 0)
        .zIndex(status == .active ? 3 : (placement.isHero ? 2 : 1))
    }
}
