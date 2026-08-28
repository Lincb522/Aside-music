import SwiftUI
import FFmpegSwiftSDK

struct SpectrumMeasurementView: View {
    let values: [Float]
    let frequencies: [Float]
    let mode: GraphicEQMode
    let accent: Color

    @State private var selectedIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bandCount: Int {
        min(values.count, frequencies.count)
    }

    private var resolvedSelection: Int? {
        if let selectedIndex, selectedIndex < bandCount { return selectedIndex }
        return values.prefix(bandCount).enumerated().max(by: { $0.element < $1.element })?.offset
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(mode == .thirtyTwoBand ? String(localized: "eq_thirty_two_band") : String(localized: "eq_ten_band"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.56))

                Spacer()

                if let index = resolvedSelection {
                    Text("\(frequencyLabel(frequencies[index]))  ·  \(String(format: "%.1f dB", values[index]))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }

            GeometryReader { proxy in
                let minimumColumnWidth: CGFloat = mode == .thirtyTwoBand ? 28 : 24
                let contentWidth = max(proxy.size.width, CGFloat(max(1, bandCount)) * minimumColumnWidth)

                ScrollView(.horizontal, showsIndicators: mode == .thirtyTwoBand) {
                    ZStack(alignment: .bottomLeading) {
                        spectrumGrid
                        spectrumBands(columnWidth: contentWidth / CGFloat(max(1, bandCount)))
                    }
                    .frame(width: contentWidth, height: proxy.size.height)
                }
            }
        }
    }

    private var spectrumGrid: some View {
        GeometryReader { proxy in
            ForEach(0..<3, id: \.self) { index in
                Path { path in
                    let y = CGFloat(index) * (proxy.size.height - 21) / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                .stroke(Color.white.opacity(index == 2 ? 0.08 : 0.04), lineWidth: 1)
            }
        }
        .padding(.bottom, 21)
        .allowsHitTesting(false)
    }

    private func spectrumBands(columnWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<bandCount, id: \.self) { index in
                let value = values[index]
                let normalized = CGFloat(min(1, max(0.05, (value + 60) / 60)))
                let isSelected = resolvedSelection == index

                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        selectedIndex = index
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(isSelected ? accent : accent.opacity(0.5))
                            .frame(width: isSelected ? 5 : 3, height: 82 * normalized)
                            .frame(height: 82, alignment: .bottom)
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.18),
                                value: isSelected
                            )

                        Text(frequencyLabel(frequencies[index]))
                            .font(.system(size: 7.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                            .foregroundStyle(isSelected ? .white.opacity(0.86) : .white.opacity(0.54))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                    .frame(width: columnWidth)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func frequencyLabel(_ frequency: Float) -> String {
        if frequency >= 1_000 {
            let value = frequency / 1_000
            return value.rounded() == value
                ? String(format: "%.0fk", value)
                : String(format: "%.1fk", value)
        }
        return String(format: "%.0f", frequency)
    }
}

struct AIEqualizerCurveView: View {
    let gains: [Float]
    let mode: GraphicEQMode
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let midY = proxy.size.height * 0.45
            let usableHeight = proxy.size.height * 0.34

            ZStack(alignment: .topLeading) {
                ForEach([-6, 0, 6], id: \.self) { gain in
                    let normalized = CGFloat(gain) / 9
                    let y = midY - normalized * usableHeight

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    .stroke(
                        Color.white.opacity(gain == 0 ? 0.1 : 0.045),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: gain == 0 ? [4, 4] : []
                        )
                    )
                }

                responsePath(
                    size: proxy.size,
                    midY: midY,
                    usableHeight: usableHeight
                )
                .trim(from: 0, to: revealProgress)
                .stroke(
                    accent,
                    style: StrokeStyle(
                        lineWidth: 2.25,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                ForEach(Array(gains.enumerated()), id: \.offset) { index, _ in
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(1, gains.count - 1))

                    if shouldShowLabel(at: index) {
                        Rectangle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 1, height: 5)
                            .position(x: x, y: proxy.size.height - 22)

                        Text(index < mode.frequencyLabels.count ? mode.frequencyLabels[index] : "")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.56))
                            .position(x: x, y: proxy.size.height - 9)
                    }
                }
            }
            .padding(.horizontal, 7)
        }
        .onAppear { revealCurve() }
        .onChange(of: gains) { _, _ in revealCurve() }
    }

    private func responsePath(
        size: CGSize,
        midY: CGFloat,
        usableHeight: CGFloat
    ) -> Path {
        let points = gains.enumerated().map { index, gain in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(max(1, gains.count - 1)),
                y: midY - CGFloat(min(9, max(-9, gain))) / 9 * usableHeight
            )
        }

        guard let first = points.first else { return Path() }

        var path = Path()
        path.move(to: first)
        guard points.count > 1 else { return path }

        guard points.count > 2 else {
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return path
        }

        let smoothing: CGFloat = 0.14
        for index in 0..<(points.count - 1) {
            let previous = points[max(0, index - 1)]
            let current = points[index]
            let next = points[index + 1]
            let following = points[min(points.count - 1, index + 2)]
            let firstControl = CGPoint(
                x: current.x + (next.x - previous.x) * smoothing,
                y: current.y + (next.y - previous.y) * smoothing
            )
            let secondControl = CGPoint(
                x: next.x - (following.x - current.x) * smoothing,
                y: next.y - (following.y - current.y) * smoothing
            )
            path.addCurve(
                to: next,
                control1: firstControl,
                control2: secondControl
            )
        }
        return path
    }

    private func shouldShowLabel(at index: Int) -> Bool {
        guard mode == .thirtyTwoBand else { return true }
        return index == gains.count - 1 || index.isMultiple(of: 4)
    }

    private func revealCurve() {
        revealProgress = reduceMotion ? 1 : 0
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.55)) {
            revealProgress = 1
        }
    }
}
