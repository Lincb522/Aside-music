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
                .fill(LinearGradient(colors: resolvedFillColors, startPoint: .leading, endPoint: .trailing))
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
///
/// Design: bars float directly on the layout with no container box. The played
/// side carries the accent gradient, the remainder is a quiet tint of the same
/// hue. Bars around the playhead breathe gently while music plays, and the
/// whole wave lifts slightly while scrubbing.
struct GlobalWaveformPlaybackProgressBar: View {
    let progress: CGFloat
    var isPlaying: Bool = false
    var color: Color = .monologueTextPrimary
    var trackOpacity: Double = 0.14
    var fillColors: [Color]?
    var onSeek: ((CGFloat) -> Void)?
    var onCommit: ((CGFloat) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @GestureState private var isScrubbing = false

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
        color.opacity(colorScheme == .dark ? max(trackOpacity, 0.2) : max(trackOpacity, 0.14))
    }

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 20, paused: !isPlaying || isScrubbing)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let height = max(geometry.size.height, 1)

                Canvas { context, size in
                    drawWave(context: &context, size: size, time: time)
                }
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .gesture(seekGesture(width: width))
            }
        }
        .scaleEffect(x: 1, y: isScrubbing ? 1.18 : 1, anchor: .center)
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: isScrubbing)
    }

    private func drawWave(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let barWidth: CGFloat = 3
        let pitch: CGFloat = 5.5
        let barCount = max(Int(size.width / pitch), 12)
        let usedWidth = CGFloat(barCount) * pitch - (pitch - barWidth)
        let leadingInset = (size.width - usedWidth) / 2

        let playheadWidth: CGFloat = 3
        let maxBarHeight = max(size.height - 8, 8)
        let minBarHeight: CGFloat = 3.5
        let midY = size.height / 2

        let progressX = leadingInset + usedWidth * clampedProgress
        let playheadIndex = Double(clampedProgress) * Double(barCount - 1)

        var barsPath = Path()
        for index in 0..<barCount {
            let amplitude = amplitude(index: index, count: barCount, time: time, playheadIndex: playheadIndex)
            let barHeight = minBarHeight + amplitude * (maxBarHeight - minBarHeight)
            let x = leadingInset + CGFloat(index) * pitch
            let rect = CGRect(x: x, y: midY - barHeight / 2, width: barWidth, height: barHeight)
            barsPath.addRoundedRect(in: rect, cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2))
        }

        // 未播放侧：同色系低透明度
        context.fill(barsPath, with: .color(trackColor))

        // 已播放侧：裁剪到进度位置后用主题渐变填充
        var played = context
        played.clip(to: Path(CGRect(x: 0, y: 0, width: progressX, height: size.height)))
        played.fill(
            barsPath,
            with: .linearGradient(
                Gradient(colors: resolvedFillColors),
                startPoint: CGPoint(x: leadingInset, y: midY),
                endPoint: CGPoint(x: leadingInset + usedWidth, y: midY)
            )
        )

        // 播放头：略高于波形的圆头竖条，带一点同色光晕
        guard clampedProgress > 0 else { return }
        let playheadHeight = maxBarHeight + 5
        let playheadRect = CGRect(
            x: min(max(progressX - playheadWidth / 2, 0), size.width - playheadWidth),
            y: midY - playheadHeight / 2,
            width: playheadWidth,
            height: playheadHeight
        )
        var playhead = context
        playhead.addFilter(.shadow(color: resolvedFillColor.opacity(0.55), radius: 3, x: 0, y: 0))
        playhead.fill(
            Path(roundedRect: playheadRect, cornerSize: CGSize(width: playheadWidth / 2, height: playheadWidth / 2)),
            with: .color(resolvedFillColor)
        )
    }

    /// 确定性的伪波形轮廓：低频起伏叠加少量细节，避免旧版的密集噪点感；
    /// 播放中时，播放头附近数根条做轻微呼吸。
    private func amplitude(index: Int, count: Int, time: TimeInterval, playheadIndex: Double) -> CGFloat {
        let i = Double(index)
        let t = i / Double(max(count - 1, 1))

        let envelope = 0.66 + 0.34 * sin(t * .pi)
        let body = 0.5
            + 0.30 * sin(i * 0.31 + 0.8)
            + 0.16 * sin(i * 0.73 + 2.1)
            + 0.06 * sin(i * 1.61 + 0.3)
        var amp = envelope * body

        if isPlaying, !isScrubbing {
            let distance = abs(i - playheadIndex)
            let falloff = max(0, 1 - distance / 4.5)
            if falloff > 0 {
                amp += Double(falloff) * 0.24 * sin(time * 5.4 + i * 1.3)
            }
        }

        return CGFloat(min(max(amp, 0.12), 1.0))
    }

    private func seekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($isScrubbing) { _, state, _ in
                state = true
            }
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
