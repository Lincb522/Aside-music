import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Aperture Theme (圆窗唱片)

struct ApertureWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let paperTop = Color(hex: "F2F2F2")
    private let paperBottom = Color(hex: "DFDFDF")
    private let ink = Color(hex: "24231E")
    private let mutedInk = Color(hex: "9B9B98")
    private let rule = Color.black.opacity(0.10)
    private let consoleFill = Color.white.opacity(0.34)

    init(entry: NowPlayingEntry, family: WidgetFamily) {
        self.entry = entry
        self.family = family
    }

    private var song: String { entry.isEmpty ? "未在播放" : entry.songName }
    private var artist: String { entry.isEmpty ? "暂无歌曲信息" : entry.artistName }
    private var totalSeconds: Int {
        guard entry.playbackDuration.isFinite, entry.playbackDuration > 0 else { return 0 }
        return Int(entry.playbackDuration.rounded(.down))
    }
    private var durationText: String {
        totalSeconds > 0 ? formatTime(totalSeconds) : "--:--"
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge: largeLayout
        default: smallLayout
        }
    }

    private var smallLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(w, h) * 0.18
            let discSide = w * 1.16

            ZStack(alignment: .top) {
                apertureSurface

                coverDisc(side: discSide, hubSize: w * 0.32)
                    .offset(y: -discSide * 0.56)

                smallInfoStack(
                    width: w * 0.76,
                    controlSize: min(19, w * 0.125)
                )
                .padding(.top, h * 0.43)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(cardStroke(radius: radius))
            .widgetURL(URL(string: "monologue://player"))
        }
    }

    private var mediumLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(h * 0.24, 28)
            let discSide = h * 1.14

            ZStack {
                apertureSurface

                // 唱片吸附在右缘，露出约 58%，与小尺寸「圆窗探出」语言呼应
                coverDisc(side: discSide, hubSize: discSide * 0.24)
                    .offset(x: w - discSide * 0.62, y: (h - discSide) / 2)
                    .frame(width: w, height: h, alignment: .topLeading)

                mediumInfoColumn(width: w * 0.56, height: h)
                    .padding(.leading, 16)
                    .frame(width: w, height: h, alignment: .leading)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(cardStroke(radius: radius))
            .widgetURL(URL(string: "monologue://player"))
        }
    }

    private func mediumInfoColumn(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.periodic(from: entry.playbackReferenceDate, by: 1.0)) { timeline in
            let activeDate = entry.isPlaying ? timeline.date : entry.playbackReferenceDate
            let activeSeconds = playbackSeconds(at: activeDate)
            let progress = progressValue(at: activeDate)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    statusBadge(entry.isPlaying ? "PLAYING" : "READY", fontSize: 8)
                    Text(formatTime(activeSeconds))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.36))
                        .monospacedDigit()
                }

                Spacer(minLength: 6)

                Text(artist.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.34))
                    .tracking(1.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(song)
                    .font(.system(size: 19, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(entry.isEmpty ? 0.46 : 0.98))
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    progressBar(width: min(width * 0.6, 108), progress: progress)
                    Text(durationText)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.28))
                        .monospacedDigit()
                }
                .padding(.top, 9)

                Spacer(minLength: 8)

                transportControls(buttonSize: 27, playSize: 38, spacing: 12, elevated: true)
            }
            .padding(.vertical, 13)
            .frame(width: width, height: height, alignment: .leading)
        }
    }

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let panelHeight = min(h * 0.44, 154)
            let heroHeight = max(144, h - panelHeight - 14)

            ZStack {
                apertureSurface

                VStack(spacing: 0) {
                    largeHero(width: w, height: heroHeight)

                    largePlayerPanel(width: w - 28, height: panelHeight)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
            }
            .frame(width: w, height: h)
            .clipShape(ContainerRelativeShape())
            .overlay(
                ContainerRelativeShape()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .widgetURL(URL(string: "monologue://player"))
        }
    }

    private func smallInfoStack(width: CGFloat, controlSize: CGFloat) -> some View {
        TimelineView(.periodic(from: entry.playbackReferenceDate, by: 1.0)) { timeline in
            let activeDate = entry.isPlaying ? timeline.date : entry.playbackReferenceDate
            let activeSeconds = playbackSeconds(at: activeDate)
            let progress = progressValue(at: activeDate)

            VStack(spacing: 2) {
                Image(systemName: entry.statusSymbolName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(mutedInk.opacity(0.78))
                    .contentTransition(.symbolEffect(.replace))

                Text(artist)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.32))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(song)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(entry.isEmpty ? 0.42 : 0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                progressBar(width: 38, progress: progress)
                    .padding(.top, 1)

                timeRow(fontSize: 11, currentSeconds: activeSeconds)

                transportControls(
                    buttonSize: controlSize,
                    playSize: controlSize + 3,
                    spacing: width * 0.06,
                    elevated: false
                )
                .padding(.top, 1)
            }
            .frame(width: width)
        }
    }

    private func largeHero(width: CGFloat, height: CGFloat) -> some View {
        let side = width * 0.92

        return TimelineView(.periodic(from: entry.playbackReferenceDate, by: 1.0)) { timeline in
            let activeDate = entry.isPlaying ? timeline.date : entry.playbackReferenceDate
            let activeSeconds = playbackSeconds(at: activeDate)

            ZStack(alignment: .topTrailing) {
                coverDisc(side: side, hubSize: side * 0.25)
                    .offset(x: -width * 0.18, y: -side * 0.30)

                VStack(alignment: .trailing, spacing: 7) {
                    statusBadge("APERTURE", fontSize: 10)
                    Text(formatTime(activeSeconds))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.42))
                        .monospacedDigit()
                }
                .padding(.top, 18)
                .padding(.trailing, 20)
            }
            .frame(width: width, height: height)
            .clipped()
        }
    }

    private func largePlayerPanel(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.periodic(from: entry.playbackReferenceDate, by: 1.0)) { timeline in
            let activeDate = entry.isPlaying ? timeline.date : entry.playbackReferenceDate
            let activeSeconds = playbackSeconds(at: activeDate)
            let progress = progressValue(at: activeDate)

            VStack(alignment: .leading, spacing: 0) {
                Text(artist.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.34))
                    .tracking(1.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(song)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(entry.isEmpty ? 0.46 : 0.98))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .padding(.top, 5)

                HStack(spacing: 10) {
                    progressBar(width: min(width * 0.58, 174), progress: progress)
                    timeRow(fontSize: 13, currentSeconds: activeSeconds)
                        .layoutPriority(1)
                }
                .padding(.top, 10)

                Spacer(minLength: 10)

                HStack {
                    Text(entry.sourceName.isEmpty ? "MONO" : entry.sourceName.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.28))
                        .tracking(1.4)

                    Spacer(minLength: 12)

                    transportControls(buttonSize: 36, playSize: 58, spacing: 18, elevated: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(consoleFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.50), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
        }
    }

    private func statusBadge(_ text: String, fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .foregroundStyle(ink.opacity(0.46))
            .tracking(1.2)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.32))
                    .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
            )
    }

    private func transportControls(buttonSize: CGFloat, playSize: CGFloat, spacing: CGFloat, elevated: Bool) -> some View {
        HStack(spacing: spacing) {
            apertureControlButton(intent: PreviousTrackIntent(), icon: "backward.fill", size: buttonSize, isPrimary: false, elevated: elevated)
            apertureControlButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: playSize, isPrimary: true, elevated: elevated)
            apertureControlButton(intent: NextTrackIntent(), icon: "forward.fill", size: buttonSize, isPrimary: false, elevated: elevated)
        }
    }

    private func apertureControlButton<I: AppIntent>(
        intent: I,
        icon: String,
        size: CGFloat,
        isPrimary: Bool,
        elevated: Bool
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: size * (isPrimary ? 0.34 : 0.32), weight: .semibold))
                .foregroundStyle(isPrimary ? paperTop : ink.opacity(0.62))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? ink : Color.white.opacity(elevated ? 0.56 : 0.20))
                        .overlay(
                            Circle()
                                .stroke(isPrimary ? Color.white.opacity(0.10) : Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(elevated ? 0.16 : 0.06),
                            radius: elevated ? 7 : 2,
                            x: 0,
                            y: elevated ? 4 : 1
                        )
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }

    private var apertureSurface: some View {
        ZStack {
            LinearGradient(colors: [paperTop, paperBottom], startPoint: .top, endPoint: .bottom)

            LinearGradient(
                colors: [Color.white.opacity(0.55), Color.clear, Color.black.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func cardStroke(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.black.opacity(0.10), lineWidth: 1)
    }

    /// 唱片旋转目标角：由整首歌的播放进度派生（9°/秒，约 40 秒一圈）。
    /// 动画时长 = entry 间隔 + 0.5 秒提前量（顶满 WidgetKit 2 秒上限）：
    /// 下一条 entry 准点到达时动画尚在飞行中，线性动画从当前呈现值无缝续接；
    /// 迟到 ≤0.5 秒时唱片仍以原速转动，只会轻微变速而不是突停。
    /// 切换时机的随机抖动无法消除，慢速旋转让残余的速度修正难以察觉。
    private var discAnimationDuration: TimeInterval {
        min(2.0, max(0.1, entry.entryDisplayDuration) + 0.5)
    }

    private var discRotationAngle: Angle {
        guard !entry.isEmpty else { return .zero }
        let targetTime = max(0, entry.playbackCurrentTime)
            + (entry.isPlaying ? discAnimationDuration : 0)
        return .degrees(targetTime * 9)
    }

    private var discRotationAnimation: Animation {
        entry.isPlaying
            ? .linear(duration: discAnimationDuration)
            : .snappy(duration: 0.4)
    }

    private func coverDisc(side: CGFloat, hubSize: CGFloat) -> some View {
        ZStack {
            // 旋转部分：盘面渐变 + 封面
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                entry.secondaryColor.opacity(0.88),
                                entry.dominantColor.opacity(0.9),
                                Color(hex: "ECEAE7"),
                                entry.dominantColor.opacity(0.78),
                                entry.secondaryColor.opacity(0.88)
                            ],
                            center: .center
                        )
                    )

                if let data = entry.coverImageData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                }
            }
            .rotationEffect(discRotationAngle)
            .animation(discRotationAnimation, value: discRotationAngle)

            // 固定部分：高光、描边、轴心不随盘面旋转
            LinearGradient(
                colors: [Color.white.opacity(0.22), Color.clear, Color.black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(Circle())

            Circle()
                .stroke(Color.black.opacity(0.14), lineWidth: 1)

            discHub(size: hubSize)
        }
        .frame(width: side, height: side)
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    private func discHub(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "C9C9C9"))
            Circle()
                .stroke(Color.white.opacity(0.70), lineWidth: max(2, size * 0.08))
                .padding(size * 0.12)
            Circle()
                .stroke(Color(hex: "8E8E94").opacity(0.36), lineWidth: max(1, size * 0.03))
                .padding(size * 0.22)
            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(
                    Color(hex: "B4A92F").opacity(0.58),
                    style: StrokeStyle(lineWidth: max(2, size * 0.04), lineCap: .round)
                )
                .rotationEffect(.degrees(84))
                .padding(size * 0.02)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
    }

    private func infoStack(
        width: CGFloat,
        iconSize: CGFloat,
        artistSize: CGFloat,
        songSize: CGFloat,
        timeSize: CGFloat,
        progressWidth: CGFloat,
        spacing: CGFloat
    ) -> some View {
        VStack(spacing: spacing) {
            Image(systemName: entry.statusSymbolName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(mutedInk.opacity(0.78))
                .contentTransition(.symbolEffect(.replace))

            Text(artist)
                .font(.system(size: artistSize, weight: .medium, design: .monospaced))
                .foregroundStyle(ink.opacity(0.32))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.interpolate)

            Text(song)
                .font(.system(size: songSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink.opacity(entry.isEmpty ? 0.42 : 0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .contentTransition(.interpolate)

            progressBar(width: progressWidth, progress: progressValue(at: entry.playbackReferenceDate))
                .padding(.top, spacing * 0.28)

            timeRow(fontSize: timeSize, currentSeconds: playbackSeconds(at: entry.playbackReferenceDate))
                .padding(.top, spacing * 0.2)
        }
        .frame(width: width)
    }

    private func progressBar(width: CGFloat, progress: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(rule)
            Rectangle()
                .fill(Color.black.opacity(entry.isEmpty ? 0.16 : 0.40))
                .frame(width: width * progress)
        }
        .frame(width: width, height: 4)
    }

    private func timeRow(fontSize: CGFloat, currentSeconds: Int) -> some View {
        HStack(spacing: max(6, fontSize * 0.35)) {
            Text(formatTime(currentSeconds))
                .foregroundStyle(ink.opacity(entry.isEmpty ? 0.38 : 0.98))
            Text("/")
                .foregroundStyle(ink.opacity(0.32))
            Text(durationText)
                .foregroundStyle(ink.opacity(0.32))
        }
        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }

    private func progressValue(at date: Date) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(min(max(playbackTime(at: date) / Double(totalSeconds), 0), 1))
    }

    private func playbackSeconds(at date: Date) -> Int {
        Int(playbackTime(at: date).rounded(.down))
    }

    private func playbackTime(at date: Date) -> TimeInterval {
        let baseTime = max(0, entry.playbackCurrentTime)
        let elapsed = entry.isPlaying ? max(0, date.timeIntervalSince(entry.playbackReferenceDate)) : 0
        let activeTime = baseTime + elapsed
        guard totalSeconds > 0 else { return activeTime }
        return min(activeTime, Double(totalSeconds))
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}
