import SwiftUI
import AVFoundation
import Combine

/// 广播电台播放器 — FM 电台仪表风格
struct BroadcastPlayerView: View {
    let channel: BroadcastChannel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BroadcastPlayerViewModel
    @ObservedObject private var settings = SettingsManager.shared

    init(channel: BroadcastChannel) {
        self.channel = channel
        _viewModel = StateObject(wrappedValue: BroadcastPlayerViewModel(channel: channel))
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.top, DeviceLayout.headerTopPadding)
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                tunerSection
                    .padding(.horizontal, 28)

                signalWaveform
                    .padding(.horizontal, 28)
                    .padding(.top, 34)

                Spacer(minLength: 0)

                consoleSection
                    .padding(.horizontal, 28)
                    .padding(.bottom, 46)
            }
        }
        .onAppear { viewModel.loadAndPlay() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            MonologueBackButton(style: .dismiss)

            Spacer()

            if viewModel.isPlaying {
                HStack(spacing: 6) {
                    BroadcastBlinkingDot(color: liveTint)

                    Text("LIVE")
                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .semibold) : .system(size: 10.5, weight: .heavy, design: .rounded))
                        .tracking(1.6)
                        .foregroundColor(liveTint)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .overlay(
                    Capsule().stroke(liveTint.opacity(0.4), lineWidth: 0.8)
                )
            }
        }
    }

    // MARK: - 调谐区：眉题 + 大号频率 + 刻度尺
    private var tunerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(accentTint)
                    .frame(width: 18, height: 3)

                Text("FM BROADCAST")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundColor(broadcastSecondary.opacity(0.75))
                    .fixedSize()

                Rectangle()
                    .fill(hairlineTint)
                    .frame(height: 0.5)
            }
            .padding(.bottom, 20)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.frequencyText)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundColor(broadcastPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("MHz")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(broadcastSecondary.opacity(0.8))

                Spacer(minLength: 0)
            }

            frequencyRuler
                .frame(height: 26)
                .padding(.top, 14)
        }
    }

    private var frequencyRuler: some View {
        GeometryReader { geo in
            let needlePosition = geo.size.width * needleFraction

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(0..<37, id: \.self) { i in
                        let isMajor = i % 6 == 0
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(broadcastSecondary.opacity(isMajor ? 0.45 : 0.18))
                                .frame(width: isMajor ? 1.2 : 0.6, height: isMajor ? 15 : 8)
                            Spacer(minLength: 0)
                        }
                        if i < 36 { Spacer(minLength: 0) }
                    }
                }

                Rectangle()
                    .fill(hairlineTint)
                    .frame(height: 0.5)
                    .offset(y: 20)

                // 调谐指针
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(accentTint)
                        .frame(width: 1.6, height: 17)

                    BroadcastTriangle()
                        .fill(accentTint)
                        .frame(width: 7, height: 5)
                        .rotationEffect(.degrees(180))
                }
                .offset(x: needlePosition - 3.5)
            }
        }
    }

    /// 依据频率把指针钉在 87.5–108 的相对位置
    private var needleFraction: CGFloat {
        let value = Double(viewModel.frequencyText) ?? 87.5
        let fraction = (value - 87.5) / (108.0 - 87.5)
        return CGFloat(min(max(fraction, 0.02), 0.98))
    }

    // MARK: - 信号波形
    private var signalWaveform: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<viewModel.waveHeights.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            viewModel.isPlaying
                                ? broadcastPrimary.opacity(0.35 + viewModel.waveHeights[i] * 0.55)
                                : broadcastSecondary.opacity(0.18)
                        )
                        .frame(width: 2.4, height: viewModel.isPlaying ? CGFloat(viewModel.waveHeights[i]) * 22 + 3 : 3)
                        .animation(.easeInOut(duration: 0.15).delay(Double(i) * 0.015), value: viewModel.waveHeights[i])
                }
            }
            .frame(height: 26, alignment: .center)

            Spacer(minLength: 12)

            Text(viewModel.isPlaying ? "STEREO" : "STANDBY")
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .tracking(1.8)
                .foregroundColor(viewModel.isPlaying ? accentTint : broadcastSecondary.opacity(0.55))
        }
    }

    // MARK: - 底部控制台：电台信息 + 播放键
    private var consoleSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(hairlineTint)
                .frame(height: 0.5)

            HStack(spacing: 14) {
                stationCover

                VStack(alignment: .leading, spacing: 5) {
                    Text(channel.displayName)
                        .font(stationTitleFont)
                        .foregroundColor(broadcastPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let program = viewModel.currentProgram, !program.isEmpty {
                        HStack(spacing: 6) {
                            Circle().fill(programLiveTint).frame(width: 5, height: 5)
                            Text(program)
                                .font(stationSubtitleFont)
                                .foregroundColor(broadcastSecondary)
                                .lineLimit(1)
                        }
                    } else if viewModel.isPlaying {
                        HStack(spacing: 6) {
                            Circle().fill(programLiveTint).frame(width: 5, height: 5)
                            Text("直播中")
                                .font(stationSubtitleFont)
                                .foregroundColor(broadcastSecondary)
                        }
                    }
                }

                Spacer(minLength: 12)

                playButton
            }
            .padding(.vertical, 18)

            Rectangle()
                .fill(hairlineTint)
                .frame(height: 0.5)
        }
    }

    private var stationCover: some View {
        Group {
            if let url = channel.coverImageUrl {
                CachedAsyncImage(url: url) {
                    coverPlaceholder
                }
                .aspectRatio(contentMode: .fill)
            } else {
                coverPlaceholder
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(broadcastPrimary.opacity(0.1), lineWidth: 0.8)
        )
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(broadcastSurfaceFill)
            .overlay(MonologueIcon(icon: .radio, size: 24, color: broadcastSecondary, lineWidth: 1.4))
    }

    private var playButton: some View {
        Button { viewModel.togglePlay() } label: {
            ZStack {
                Circle()
                    .fill(broadcastButtonFill)
                    .frame(width: 58, height: 58)

                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: broadcastButtonForeground))
                } else {
                    MonologueIcon(
                        icon: viewModel.isPlaying ? .pause : .play,
                        size: 22, color: broadcastButtonForeground, lineWidth: 2.0
                    )
                    .offset(x: viewModel.isPlaying ? 0 : 1.5)
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
    }

    private var broadcastPrimary: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var broadcastSecondary: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var broadcastSurfaceFill: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList }
        return Color.monologueGlassTint
    }

    private var broadcastButtonFill: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return Color.monologueIconBackground
    }

    private var broadcastButtonForeground: Color {
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        return .monologueIconForeground
    }

    private var accentTint: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return .monologueAccent
    }

    private var hairlineTint: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.6) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.75) }
        return Color.monologueSeparator.opacity(0.55)
    }

    private var liveTint: Color {
        SequoiaStyle.isActive ? SequoiaStyle.red : .monologueAccentRed
    }

    private var programLiveTint: Color {
        SequoiaStyle.isActive ? SequoiaStyle.green : .monologueAccentGreen
    }

    private var stationTitleFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(17, weight: .semibold) }
        return .system(size: 17, weight: .heavy, design: .rounded)
    }

    private var stationSubtitleFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12.5, weight: .regular) }
        return .system(size: 12.5, weight: .medium, design: .rounded)
    }
}

/// LIVE 呼吸圆点
private struct BroadcastBlinkingDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .opacity(dimmed ? 0.35 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

// MARK: - 三角形指针
private struct BroadcastTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - ViewModel
@MainActor
class BroadcastPlayerViewModel: ObservableObject {
    let channel: BroadcastChannel
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentProgram: String?
    @Published var frequencyText: String = "87.5"
    @Published var waveHeights: [Double] = Array(repeating: 0, count: 24)

    private var avPlayer: AVPlayer?
    private var waveTimer: Timer?
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()

    init(channel: BroadcastChannel) {
        self.channel = channel
        self.currentProgram = channel.displayProgram
        let freq = 87.5 + Double(channel.id % 200) * 0.1
        self.frequencyText = String(format: "%.1f", freq)
    }

    func loadAndPlay() {
        isLoading = true
        apiService.fetchBroadcastChannelInfo(id: String(channel.id))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("获取广播频道信息失败: \(error)")
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] info in
                guard let self = self else { return }
                if let p = info["programName"] as? String, !(p as AnyObject).isEqual(NSNull()) {
                    self.currentProgram = p
                }
                if let n = info["channelName"] as? String, self.currentProgram == nil {
                    self.currentProgram = n
                }
                if let url = info["playUrl"] as? String, !url.isEmpty, let u = URL(string: url) {
                    self.playStream(url: u)
                } else if let url = info["url"] as? String, !url.isEmpty, let u = URL(string: url) {
                    self.playStream(url: u)
                } else {
                    AppLogger.error("广播频道无可用播放流")
                    self.isLoading = false
                }
            })
            .store(in: &cancellables)
    }

    func togglePlay() {
        if isPlaying { stop() } else { loadAndPlay() }
    }

    func stop() {
        avPlayer?.pause()
        avPlayer = nil
        isPlaying = false
        isLoading = false
        stopWave()
    }

    private func playStream(url: URL) {
        PlayerManager.shared.stopAndClear()
        let item = AVPlayerItem(url: url)
        avPlayer = AVPlayer(playerItem: item)
        avPlayer?.play()
        isPlaying = true
        isLoading = false
        startWave()
    }

    private func startWave() {
        stopWave()
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.waveHeights = (0..<24).map { _ in Double.random(in: 0.15...1.0) }
                }
            }
        }
    }

    private func stopWave() {
        waveTimer?.invalidate()
        waveTimer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            waveHeights = Array(repeating: 0, count: 24)
        }
    }

    deinit {
        MainActor.assumeIsolated {
            avPlayer?.pause()
            avPlayer = nil
            waveTimer?.invalidate()
        }
    }
}
