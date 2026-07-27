//  调音方案的视觉化对比：先看曲线与主要差异，再按需展开全部频段。

import SwiftUI

@MainActor
struct AIEqualizerProposalComparisonRedesignView: View {
    let current: AIEqualizerProposal?
    let historical: AIEqualizerSavedProposal
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsBandDetails = false

    var body: some View {
        ZStack {
            comparisonBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    pageHeader

                    if let current, current.id != historical.id {
                        proposalHero(current: current, previous: historical.proposal)
                        curveCard(current: current, previous: historical.proposal)
                        summaryGrid(current: current, previous: historical.proposal)
                        metricGrid(current: current, previous: historical.proposal)

                        if current.graphicEQMode == historical.proposal.graphicEQMode {
                            bandDetails(current: current, previous: historical.proposal)
                        }
                    } else {
                        emptyComparison
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 36)
                .iPadContentWidth(760)
            }
        }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var comparisonBackground: some View {
        ZStack {
            Color(red: 0.035, green: 0.037, blue: 0.048)
            RadialGradient(
                colors: [accent.opacity(0.17), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var pageHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                MonoIcon(icon: .close, size: 13, color: .white.opacity(0.88))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

            Text(String(localized: "ai_lab_compare_title"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
    }

    private func proposalHero(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> some View {
        HStack(spacing: 10) {
            proposalIdentity(
                label: String(localized: "ai_lab_previous_result"),
                proposal: previous,
                color: .white.opacity(0.48)
            )

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 30, height: 30)
                MonoIcon(icon: .chevronRight, size: 10, color: .white.opacity(0.48))
            }
            .accessibilityHidden(true)

            proposalIdentity(
                label: String(localized: "ai_lab_current_result"),
                proposal: current,
                color: accent
            )
        }
        .padding(14)
        .background(comparisonCard(cornerRadius: 20, emphasized: true))
    }

    private func proposalIdentity(
        label: String,
        proposal: AIEqualizerProposal,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Text(proposal.profileName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(proposal.resolvedTuningProfile.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func curveCard(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(String(localized: "ai_lab_eq_band_comparison"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()

                curveLegend(
                    title: String(localized: "ai_lab_previous_short"),
                    color: .white.opacity(0.38)
                )
                curveLegend(
                    title: String(localized: "ai_lab_current_short"),
                    color: accent
                )
            }

            AIEqualizerComparisonCurve(
                current: current.gains,
                previous: previous.gains,
                accent: accent
            )
            .frame(height: 154)
        }
        .padding(15)
        .background(comparisonCard(cornerRadius: 18))
    }

    private func curveLegend(title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 14, height: 2)
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
        }
    }

    private func summaryGrid(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> some View {
        let changed = changedBandCount(current: current, previous: previous)
        let largest = largestBandChange(current: current, previous: previous)
        let average = averageBandChange(current: current, previous: previous)

        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 138), spacing: 9)],
            spacing: 9
        ) {
            summaryCard(
                title: String(localized: "ai_lab_changed_bands"),
                value: String(format: String(localized: "ai_lab_changed_bands_format"), changed)
            )
            summaryCard(
                title: String(localized: "ai_lab_largest_change"),
                value: largest.map {
                    "\(frequencyText($0.frequency))  \(String(format: "%+.1f dB", $0.delta))"
                } ?? String(localized: "ai_lab_no_change")
            )
            summaryCard(
                title: String(localized: "ai_lab_average_change"),
                value: String(format: "%.1f dB", average)
            )
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.44))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.horizontal, 12)
        .background(comparisonCard(cornerRadius: 14))
    }

    private func metricGrid(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 210), spacing: 10)],
            spacing: 10
        ) {
            metricCard(
                String(localized: "ai_lab_preamp"),
                current: current.preampDB,
                previous: previous.preampDB,
                range: -12...6,
                suffix: " dB"
            )
            metricCard(
                String(localized: "eq_bass"),
                current: current.tone.bassGain,
                previous: previous.tone.bassGain,
                range: -12...12,
                suffix: " dB"
            )
            metricCard(
                String(localized: "eq_treble"),
                current: current.tone.trebleGain,
                previous: previous.tone.trebleGain,
                range: -12...12,
                suffix: " dB"
            )
            metricCard(
                String(localized: "eq_surround"),
                current: current.spatial.surroundLevel * 100,
                previous: previous.spatial.surroundLevel * 100,
                range: 0...100,
                suffix: "%"
            )
            metricCard(
                String(localized: "eq_reverb"),
                current: current.spatial.reverbLevel * 100,
                previous: previous.spatial.reverbLevel * 100,
                range: 0...100,
                suffix: "%"
            )
            metricCard(
                String(localized: "ai_lab_stereo_width"),
                current: current.spatial.stereoWidth,
                previous: previous.spatial.stereoWidth,
                range: 0.5...2,
                suffix: "x"
            )
            metricCard(
                String(localized: "eq_processing_intensity"),
                current: current.professional.processingIntensity * 100,
                previous: previous.professional.processingIntensity * 100,
                range: 0...100,
                suffix: "%"
            )
        }
    }

    private func metricCard(
        _ title: String,
        current: Float,
        previous: Float,
        range: ClosedRange<Float>,
        suffix: String
    ) -> some View {
        let delta = current - previous

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Text(String(format: "%+.1f", delta))
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(abs(delta) < 0.1 ? .white.opacity(0.38) : accent)
            }

            AIEqualizerDeltaTrack(
                current: current,
                previous: previous,
                range: range,
                accent: accent
            )
            .frame(height: 12)

            HStack {
                metricValue(
                    label: String(localized: "ai_lab_previous_short"),
                    value: String(format: "%.1f%@", previous, suffix),
                    color: .white.opacity(0.46)
                )
                Spacer()
                metricValue(
                    label: String(localized: "ai_lab_current_short"),
                    value: String(format: "%.1f%@", current, suffix),
                    color: accent,
                    alignment: .trailing
                )
            }
        }
        .padding(13)
        .background(comparisonCard(cornerRadius: 16))
    }

    private func metricValue(
        label: String,
        value: String,
        color: Color,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.34))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func bandDetails(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> some View {
        let frequencies = current.graphicEQMode.centerFrequencies
        let count = min(frequencies.count, min(current.gains.count, previous.gains.count))

        return VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) {
                    showsBandDetails.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Text(String(localized: "ai_lab_all_band_details"))
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))

                    Spacer()

                    Text("\(count)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)

                    MonoIcon(icon: .chevronRight, size: 10, color: .white.opacity(0.42))
                        .rotationEffect(.degrees(showsBandDetails ? 90 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsBandDetails {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 132), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(0..<count, id: \.self) { index in
                        bandCell(
                            frequency: frequencies[index],
                            current: current.gains[index],
                            previous: previous.gains[index]
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(comparisonCard(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func bandCell(
        frequency: Float,
        current: Float,
        previous: Float
    ) -> some View {
        let delta = current - previous

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(frequencyText(frequency))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Text(String(format: "%+.1f", delta))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(abs(delta) < 0.15 ? .white.opacity(0.34) : accent)
            }

            HStack(spacing: 5) {
                Text(String(format: "%+.1f", previous))
                    .foregroundStyle(.white.opacity(0.42))
                MonoIcon(icon: .chevronRight, size: 7, color: .white.opacity(0.24))
                Text(String(format: "%+.1f dB", current))
                    .foregroundStyle(accent)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.038))
        )
    }

    private var emptyComparison: some View {
        HStack(spacing: 10) {
            MonoIcon(icon: .infoCircle, size: 16, color: accent)
            Text(String(localized: "ai_lab_no_comparison"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(15)
        .background(comparisonCard(cornerRadius: 16))
    }

    private func comparisonCard(
        cornerRadius: CGFloat,
        emphasized: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(emphasized ? 0.055 : 0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        emphasized ? accent.opacity(0.20) : Color.white.opacity(0.075),
                        lineWidth: 1
                    )
            }
    }

    private func changedBandCount(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> Int {
        guard current.graphicEQMode == previous.graphicEQMode else {
            return current.gains.count
        }
        return zip(current.gains, previous.gains)
            .filter { abs($0 - $1) >= 0.15 }
            .count
    }

    private func largestBandChange(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> (frequency: Float, delta: Float)? {
        guard current.graphicEQMode == previous.graphicEQMode else { return nil }
        let frequencies = current.graphicEQMode.centerFrequencies
        let count = min(frequencies.count, min(current.gains.count, previous.gains.count))
        guard count > 0 else { return nil }
        let index = (0..<count).max {
            abs(current.gains[$0] - previous.gains[$0])
                < abs(current.gains[$1] - previous.gains[$1])
        }
        guard let index else { return nil }
        return (frequencies[index], current.gains[index] - previous.gains[index])
    }

    private func averageBandChange(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> Float {
        let deltas = zip(current.gains, previous.gains).map { abs($0 - $1) }
        guard !deltas.isEmpty else { return 0 }
        return deltas.reduce(0, +) / Float(deltas.count)
    }

    private func frequencyText(_ frequency: Float) -> String {
        frequency >= 1_000
            ? String(format: "%.1f kHz", frequency / 1_000)
            : String(format: "%.0f Hz", frequency)
    }
}

struct AIEqualizerComparisonCurve: View {
    let current: [Float]
    let previous: [Float]
    let accent: Color

    var body: some View {
        Canvas(opaque: false, colorMode: .linear) { context, size in
            guard size.width > 1, size.height > 1 else { return }

            let inset: CGFloat = 5
            let plot = CGRect(
                x: inset,
                y: inset,
                width: size.width - inset * 2,
                height: size.height - inset * 2
            )
            let zeroY = plot.midY

            for index in 0..<5 {
                let y = plot.minY + plot.height * CGFloat(index) / 4
                var line = Path()
                line.move(to: CGPoint(x: plot.minX, y: y))
                line.addLine(to: CGPoint(x: plot.maxX, y: y))
                context.stroke(
                    line,
                    with: .color(.white.opacity(index == 2 ? 0.105 : 0.045)),
                    lineWidth: index == 2 ? 1 : 0.7
                )
            }

            let previousPoints = points(for: previous, in: plot)
            let currentPoints = points(for: current, in: plot)

            if !currentPoints.isEmpty {
                var fill = smoothPath(points: currentPoints)
                fill.addLine(to: CGPoint(x: currentPoints.last?.x ?? plot.maxX, y: zeroY))
                fill.addLine(to: CGPoint(x: currentPoints.first?.x ?? plot.minX, y: zeroY))
                fill.closeSubpath()
                context.fill(
                    fill,
                    with: .linearGradient(
                        Gradient(colors: [accent.opacity(0.16), accent.opacity(0.015)]),
                        startPoint: CGPoint(x: plot.midX, y: plot.minY),
                        endPoint: CGPoint(x: plot.midX, y: plot.maxY)
                    )
                )
            }

            if previousPoints.count > 1 {
                context.stroke(
                    smoothPath(points: previousPoints),
                    with: .color(.white.opacity(0.32)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 5])
                )
            }

            if currentPoints.count > 1 {
                context.stroke(
                    smoothPath(points: currentPoints),
                    with: .color(accent.opacity(0.96)),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func points(for values: [Float], in rect: CGRect) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let divisor = CGFloat(max(1, values.count - 1))
        return values.enumerated().map { index, value in
            let normalized = CGFloat(min(12, max(-12, value)) + 12) / 24
            return CGPoint(
                x: rect.minX + rect.width * CGFloat(index) / divisor,
                y: rect.maxY - rect.height * normalized
            )
        }
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(
                x: (previous.x + current.x) * 0.5,
                y: (previous.y + current.y) * 0.5
            )
            path.addQuadCurve(to: midpoint, control: previous)
            if index == points.count - 1 {
                path.addQuadCurve(to: current, control: current)
            }
        }
        return path
    }
}

private struct AIEqualizerDeltaTrack: View {
    let current: Float
    let previous: Float
    let range: ClosedRange<Float>
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let currentX = width * normalized(current)
            let previousX = width * normalized(previous)
            let lowerX = min(currentX, previousX)
            let upperX = max(currentX, previousX)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 2)

                Capsule()
                    .fill(accent.opacity(0.44))
                    .frame(width: max(2, upperX - lowerX), height: 3)
                    .offset(x: lowerX)

                Circle()
                    .fill(Color.white.opacity(0.62))
                    .frame(width: 7, height: 7)
                    .offset(x: min(max(0, width - 7), max(0, previousX - 3.5)))

                Circle()
                    .fill(accent)
                    .frame(width: 9, height: 9)
                    .shadow(color: accent.opacity(0.38), radius: 4)
                    .offset(x: min(max(0, width - 9), max(0, currentX - 4.5)))
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func normalized(_ value: Float) -> CGFloat {
        let span = max(0.001, range.upperBound - range.lowerBound)
        return CGFloat(min(1, max(0, (value - range.lowerBound) / span)))
    }
}
