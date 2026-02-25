import SwiftUI
import AVFoundation
import Combine

/// 广播电台播放器 — FM 电台风格
struct BroadcastPlayerView: View {
    let channel: BroadcastChannel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BroadcastPlayerViewModel

    init(channel: BroadcastChannel) {
        self.channel = channel
        _viewModel = StateObject(wrappedValue: BroadcastPlayerViewModel(channel: channel))
    }

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, DeviceLayout.headerTopPadding)

                Spacer()

                frequencyDisplay
                    .padding(.bottom, 32)

                signalWaveform
                    .padding(.bottom, 40)

                stationInfo
                    .padding(.bottom, 36)

                controlBar
                    .padding(.bottom, 56)
            }
        }
        .onAppear { viewModel.loadAndPlay() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            AsideBackButton(style: .dismiss)
            Spacer()
            if viewModel.isPlaying {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.asideAccentRed)
                        .frame(width: 8, height: 8)
                        .shadow(color: .asideAccentRed.opacity(0.6), radius: 4)
                    Text("LIVE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.asideAccentRed)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.asideAccentRed.opacity(0.1))
                .clipShape(Capsule())
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - FM 频率显示
    private var frequencyDisplay: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("FM")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.asideTextSecondary)
                Text(viewModel.frequencyText)
                    .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .monospacedDigit()
                Text("MHz")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.asideTextSecondary)
            }
            frequencyRuler
                .frame(height: 24)
                .padding(.horizontal, 32)
        }
    }

    private var frequencyRuler: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 0) {
                    ForEach(0..<30, id: \.self) { i in
                        let isMajor = i % 5 == 0
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.asideTextSecondary.opacity(isMajor ? 0.4 : 0.15))
                                .frame(width: 1, height: isMajor ? 14 : 7)
                            Spacer()
                        }
                        if i < 29 { Spacer() }
                    }
                }
                VStack(spacing: 0) {
                    Spacer()
                    BroadcastTriangle()
                        .fill(Color.asideAccentRed)
                        .frame(width: 10, height: 6)
                        .shadow(color: .asideAccentRed.opacity(0.4), radius: 3)
                }
            }
        }
    }

    // MARK: - 信号波形
    private var signalWaveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        viewModel.isPlaying
                            ? Color.asideAccentBlue.opacity(0.6 + viewModel.waveHeights[i] * 0.4)
                            : Color.asideTextSecondary.opacity(0.15)
                    )
                    .frame(width: 3, height: viewModel.isPlaying ? CGFloat(viewModel.waveHeights[i]) * 28 + 4 : 4)
                    .animation(.easeInOut(duration: 0.15).delay(Double(i) * 0.02), value: viewModel.waveHeights[i])
            }
        }
        .frame(height: 32)
    }

    // MARK: - 电台信息
    private var stationInfo: some View {
        VStack(spacing: 14) {
            if let url = channel.coverImageUrl {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 16).fill(Color.asideGlassTint).glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.asideGlassTint)
                    .frame(width: 80, height: 80)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .overlay(AsideIcon(icon: .radio, size: 32, color: .asideTextSecondary, lineWidth: 1.4))
            }

            Text(channel.displayName)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .lineLimit(1)

            if let program = viewModel.currentProgram, !program.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(Color.asideAccentGreen).frame(width: 6, height: 6)
                    Text(program)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
            } else if viewModel.isPlaying {
                Text("直播中")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
        }
    }

    // MARK: - 播放控制
    private var controlBar: some View {
        Button { viewModel.togglePlay() } label: {
            ZStack {
                Circle()
                    .fill(Color.asideGlassTint)
                    .frame(width: 72, height: 72)
                    .glassEffect(.regular, in: .circle)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .asideIconForeground))
                        .scaleEffect(1.2)
                } else {
                    AsideIcon(
                        icon: viewModel.isPlaying ? .pause : .play,
                        size: 28, color: .asideIconForeground, lineWidth: 2.0
                    )
                    .offset(x: viewModel.isPlaying ? 0 : 2)
                }
            }
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
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
    @Published var waveHeights: [Double] = Array(repeating: 0, count: 20)

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
                    self.waveHeights = (0..<20).map { _ in Double.random(in: 0.15...1.0) }
                }
            }
        }
    }

    private func stopWave() {
        waveTimer?.invalidate()
        waveTimer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            waveHeights = Array(repeating: 0, count: 20)
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

