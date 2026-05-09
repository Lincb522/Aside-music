import SwiftUI

/// App-wide playback progress rail used by floating bars and mini players.
/// Keep this view light: it updates frequently while music is playing.
struct GlobalPlaybackProgressBar: View {
    let progress: CGFloat
    var height: CGFloat = 3
    var minFillWidth: CGFloat = 6
    var trackColor: Color?
    var strokeColor: Color?
    var fillColors: [Color]?
    var showsThumb: Bool = false
    var thumbSize: CGFloat?
    var onSeek: ((CGFloat) -> Void)?
    var onCommit: ((CGFloat) -> Void)?

    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var isInteractive: Bool {
        onSeek != nil || onCommit != nil
    }

    private var resolvedTrackColor: Color {
        if let trackColor { return trackColor }
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(colorScheme == .dark ? 0.20 : 0.13) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(colorScheme == .dark ? 0.42 : 0.34) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(colorScheme == .dark ? 0.52 : 0.38) }
        if CapsuleStyle.isActive { return CapsuleStyle.separator.opacity(colorScheme == .dark ? 0.58 : 0.44) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(colorScheme == .dark ? 0.54 : 0.42) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.separator.opacity(colorScheme == .dark ? 0.58 : 0.38) }
        if ClayStyle.isActive { return ClayStyle.ink.opacity(colorScheme == .dark ? 0.18 : 0.12) }
        if SignalStyle.isActive { return SignalStyle.separator.opacity(colorScheme == .dark ? 0.54 : 0.38) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(colorScheme == .dark ? 0.52 : 0.36) }
        return Color.monologueTextPrimary.opacity(colorScheme == .dark ? 0.14 : 0.08)
    }

    private var resolvedStrokeColor: Color {
        if let strokeColor { return strokeColor }
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.18) }
        if CapsuleStyle.isActive { return CapsuleStyle.hairline.opacity(0.46) }
        if LiquidGlassStyle.isActive { return Color.white.opacity(colorScheme == .dark ? 0.14 : 0.42) }
        return Color.white.opacity(colorScheme == .dark ? 0.05 : 0.32)
    }

    private var resolvedFillColors: [Color] {
        if let fillColors, !fillColors.isEmpty { return fillColors }
        if MangaStyle.isActive { return [MangaStyle.accentPink, MangaStyle.labelYellow] }
        if MujiStyle.isActive { return [MujiStyle.clay, MujiStyle.indigo.opacity(0.84)] }
        if NeumorphicStyle.isActive { return [NeumorphicStyle.accent, NeumorphicStyle.sage] }
        if CapsuleStyle.isActive { return CapsuleStyle.accentGradient }
        if SequoiaStyle.isActive { return [SequoiaStyle.accent, SequoiaStyle.aqua] }
        if LiquidGlassStyle.isActive { return [LiquidGlassStyle.accent, LiquidGlassStyle.cyan, LiquidGlassStyle.violet] }
        if ClayStyle.isActive { return [ClayStyle.sky, ClayStyle.peach] }
        if SignalStyle.isActive { return [SignalStyle.accent, SignalStyle.mint] }
        if BentoStyle.isActive { return [BentoStyle.tomato, BentoStyle.mustard] }
        return [Color.monologueAccent.opacity(0.62), Color.monologueAccent.opacity(0.92)]
    }

    private var resolvedFillColor: Color {
        resolvedFillColors.last ?? Color.monologueAccent
    }

    private var resolvedThumbSize: CGFloat {
        thumbSize ?? max(8, height * 2.4)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)

            if isInteractive {
                bar(width: width)
                    .gesture(seekGesture(width: width))
            } else {
                bar(width: width)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: max(height, showsThumb ? resolvedThumbSize : height))
    }

    @ViewBuilder
    private func bar(width: CGFloat) -> some View {
        let fillWidth = clampedProgress > 0 ? max(minFillWidth, width * clampedProgress) : 0
        let thumbOffset = min(max(fillWidth - resolvedThumbSize / 2, 0), max(width - resolvedThumbSize, 0))

        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(resolvedTrackColor)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(resolvedStrokeColor, lineWidth: 0.55)
                }
                .frame(height: height)

            Capsule(style: .continuous)
                .fill(resolvedFillColor)
                .frame(width: fillWidth, height: height)

            if showsThumb && clampedProgress > 0 {
                Circle()
                    .fill(resolvedFillColor)
                    .frame(width: resolvedThumbSize, height: resolvedThumbSize)
                    .offset(x: thumbOffset)
            }
        }
        .frame(height: max(height, showsThumb ? resolvedThumbSize : height))
        .contentShape(Rectangle())
        .animation(.linear(duration: 0.12), value: clampedProgress)
    }

    private func seekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let next = min(max(value.location.x / max(width, 1), 0), 1)
                onSeek?(next)
            }
            .onEnded { value in
                let next = min(max(value.location.x / max(width, 1), 0), 1)
                onCommit?(next)
            }
    }
}

/// Compact waveform-style playback progress rail.
/// Used by the default player and FM player so they share the same redesigned
/// audio-texture language while keeping seek interactions lightweight.
struct GlobalWaveformPlaybackProgressBar: View {
    let progress: CGFloat
    var isPlaying: Bool = false
    var color: Color = .monologueTextPrimary
    var trackOpacity: Double = 0.14
    var fillColors: [Color]?
    var onSeek: ((CGFloat) -> Void)?
    var onCommit: ((CGFloat) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var resolvedFillColors: [Color] {
        if let fillColors, !fillColors.isEmpty { return fillColors }
        if MangaStyle.isActive { return [MangaStyle.accentPink, MangaStyle.labelYellow] }
        if MujiStyle.isActive { return [MujiStyle.clay, MujiStyle.indigo.opacity(0.86)] }
        if NeumorphicStyle.isActive { return [NeumorphicStyle.accent, NeumorphicStyle.sage] }
        if CapsuleStyle.isActive { return CapsuleStyle.accentGradient }
        if SequoiaStyle.isActive { return [SequoiaStyle.accent, SequoiaStyle.aqua] }
        if LiquidGlassStyle.isActive { return [LiquidGlassStyle.accent, LiquidGlassStyle.cyan, LiquidGlassStyle.violet] }
        if ClayStyle.isActive { return [ClayStyle.sky, ClayStyle.peach] }
        if SignalStyle.isActive { return [SignalStyle.accent, SignalStyle.mint] }
        if BentoStyle.isActive { return [BentoStyle.tomato, BentoStyle.mustard] }
        return [color.opacity(0.66), color.opacity(0.96)]
    }

    private var resolvedFillColor: Color {
        resolvedFillColors.last ?? color
    }

    private var trackColor: Color {
        color.opacity(colorScheme == .dark ? max(trackOpacity, 0.16) : trackOpacity)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let barCount = width > 320 ? 86 : (width > 240 ? 72 : 56)
            let spacing: CGFloat = 1.6
            let horizontalInset: CGFloat = 2
            let waveformWidth = max(1, width - horizontalInset * 2)
            let barWidth = max(1.8, (waveformWidth - CGFloat(barCount - 1) * spacing) / CGFloat(barCount))
            let railHeight = max(12, height * 0.72)
            let maxWaveHeight = max(railHeight - 7, 7)
            let thumbWidth: CGFloat = 3
            let thumbHeight = max(railHeight - 3, 10)
            let thumbX = min(max(width * clampedProgress - thumbWidth / 2, 0), max(width - thumbWidth, 0))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: max(6, railHeight * 0.28), style: .continuous)
                    .fill(trackColor.opacity(colorScheme == .dark ? 0.34 : 0.28))
                    .frame(height: railHeight)

                waveformBars(
                    barCount: barCount,
                    spacing: spacing,
                    barWidth: barWidth,
                    railHeight: railHeight,
                    maxWaveHeight: maxWaveHeight,
                    fill: color.opacity(colorScheme == .dark ? 0.28 : 0.20)
                )
                .padding(.horizontal, horizontalInset)

                waveformBars(
                    barCount: barCount,
                    spacing: spacing,
                    barWidth: barWidth,
                    railHeight: railHeight,
                    maxWaveHeight: maxWaveHeight,
                    fill: resolvedFillColor
                )
                .padding(.horizontal, horizontalInset)
                .frame(width: max(0, width * clampedProgress), alignment: .leading)
                .clipped()

                Capsule(style: .continuous)
                    .fill(resolvedFillColor)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .offset(x: thumbX)
                    .opacity(clampedProgress > 0 ? 1 : 0)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(seekGesture(width: width))
            .animation(.linear(duration: 0.12), value: clampedProgress)
        }
    }

    private func waveformBars(
        barCount: Int,
        spacing: CGFloat,
        barWidth: CGFloat,
        railHeight: CGFloat,
        maxWaveHeight: CGFloat,
        fill: Color
    ) -> some View {
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let amplitude = waveformAmplitude(index: index, count: barCount)
                    let lineHeight = 3 + amplitude * maxWaveHeight

                    RoundedRectangle(cornerRadius: max(1.2, barWidth * 0.72), style: .continuous)
                        .fill(fill)
                        .frame(width: barWidth, height: min(lineHeight, max(3, railHeight - 5)))
                }
            }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func waveformAmplitude(index: Int, count: Int) -> CGFloat {
        let t = Double(index) / Double(max(count - 1, 1))
        let envelope = 0.56 + 0.44 * sin(t * .pi)
        let primary = 0.52 + 0.48 * sin(Double(index) * 1.23 + 0.7)
        let detail = 0.72 + 0.28 * sin(Double(index) * 2.17 + 1.9)
        return CGFloat(min(max(envelope * primary * detail, 0.18), 1.0))
    }

    private func seekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let next = min(max(value.location.x / max(width, 1), 0), 1)
                onSeek?(next)
            }
            .onEnded { value in
                let next = min(max(value.location.x / max(width, 1), 0), 1)
                onCommit?(next)
            }
    }
}
