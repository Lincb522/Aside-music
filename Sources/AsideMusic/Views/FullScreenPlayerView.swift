import SwiftUI
import FFmpegSwiftSDK

/// 全屏播放器 - 路由层，根据主题切换不同布局
struct FullScreenPlayerView: View {
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared
    
    // PlayerThemeManager 使用 @Observable，需要用 @State 或直接访问
    private var themeManager: PlayerThemeManager { PlayerThemeManager.shared }

    var body: some View {
        Group {
            switch themeManager.currentTheme {
            case .classic:
                ClassicPlayerLayout()
            case .vinyl:
                VinylPlayerLayout()
            case .lyricFocus:
                MinimalPlayerLayout()
            case .card:
                CardPlayerLayout()
            case .neumorphic:
                NeumorphicPlayerLayout()
            case .poster:
                PosterPlayerLayout()
            case .motoPager:
                MotoPagerLayout()
            case .pixel:
                PixelPlayerLayout()
            case .aqua:
                AquaPlayerLayout()
            case .cassette:
                CassettePlayerLayout()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                player.isTabBarHidden = true
            }
            // 确保歌词已加载（包括之前加载失败的情况）
            if let song = player.currentSong {
                if lyricVM.currentSongId != song.id || (!lyricVM.hasLyrics && !lyricVM.isLoading) {
                    if song.isQQMusic, let mid = song.qqMid {
                        lyricVM.fetchQQLyrics(mid: mid, songId: song.id)
                    } else {
                        lyricVM.fetchLyrics(for: song.id)
                    }
                }
            }
        }
        .onDisappear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    player.isTabBarHidden = false
                }
            }
        }
    }

    // MARK: - 波形进度条组件（供各布局复用）

    struct WaveformProgressBar: View {
        @Binding var currentTime: Double
        let duration: Double
        var color: Color = .asideTextPrimary
        var isAnimating: Bool = true
        var chorusStart: TimeInterval? = nil
        var chorusEnd: TimeInterval? = nil
        let onSeek: (Double) -> Void
        let onCommit: (Double) -> Void

        let barCount = 60
        let barSpacing: CGFloat = 2
        let minHeight: CGFloat = 3

        /// 真实波形数据（从 WaveformGenerator 获取）
        @State private var realAmplitudes: [CGFloat]?
        /// 随机波形（加载前的占位）
        @State private var fallbackAmplitudes: [CGFloat] = []
        /// 当前歌曲 URL（用于检测切歌）
        @State private var loadedSongId: Int?

        private var amplitudes: [CGFloat] {
            realAmplitudes ?? fallbackAmplitudes
        }

        var body: some View {
            TimelineView(.animation(minimumInterval: 0.12, paused: !isAnimating)) { timeline in
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let barWidth = (totalWidth - (CGFloat(barCount - 1) * barSpacing)) / CGFloat(barCount)
                    let progress = duration > 0 ? currentTime / duration : 0
                    let phase = isAnimating ? timeline.date.timeIntervalSinceReferenceDate * 1.8 : 0

                    HStack(alignment: .center, spacing: barSpacing) {
                        ForEach(0..<barCount, id: \.self) { index in
                            let barProgress = Double(index) / Double(barCount - 1)
                            let isPlayed = barProgress <= progress
                            let baseAmplitude = index < amplitudes.count ? amplitudes[index] : 0.5
                            let isChorus = isInChorus(barProgress: barProgress)

                            let height = barHeight(
                                index: index,
                                isPlayed: isPlayed,
                                base: baseAmplitude,
                                phase: phase,
                                maxH: geometry.size.height
                            )

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(isPlayed ? color : (isChorus ? color.opacity(0.35) : color.opacity(0.2)))
                                .frame(width: max(2, barWidth), height: height)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let p = min(max(value.location.x / totalWidth, 0), 1)
                                onSeek(p * duration)
                            }
                            .onEnded { value in
                                let p = min(max(value.location.x / totalWidth, 0), 1)
                                onCommit(p * duration)
                            }
                    )
                }
            }
            .onAppear { generateFallback(); loadRealWaveform() }
            .onChange(of: duration) { generateFallback(); loadRealWaveform() }
            .onChange(of: PlayerManager.shared.currentSong?.id) { _, _ in
                realAmplitudes = nil
                loadedSongId = nil
                generateFallback()
                loadRealWaveform()
            }
        }

        private func barHeight(index: Int, isPlayed: Bool, base: CGFloat, phase: Double, maxH: CGFloat) -> CGFloat {
            var factor: CGFloat = 1.0
            if isPlayed && realAmplitudes == nil {
                // 只有占位波形才做呼吸动画，真实波形保持静态
                let wave = sin(Double(index) * 0.6 + phase)
                factor = 1.0 + CGFloat(wave) * 0.25
            }
            let amp = min(max(base * factor, 0), 1.0)
            return minHeight + amp * (maxH - minHeight)
        }

        private func generateFallback() {
            fallbackAmplitudes = (0..<barCount).map { index in
                let n = Double(index) / Double(barCount - 1)
                let envelope = sin(n * .pi)
                let random = Double.random(in: 0.25...1.0)
                return CGFloat(envelope * random)
            }
        }

        /// 从 WaveformGenerator 加载真实波形
        private func loadRealWaveform() {
            guard let songId = PlayerManager.shared.currentSong?.id,
                  songId != loadedSongId else { return }

            // 优先使用本地文件
            let url: String?
            if let localURL = DownloadManager.shared.localFileURL(songId: songId) {
                url = localURL.absoluteString
            } else {
                // 网络流暂不支持波形生成（需要完整解码），保持占位波形
                url = nil
            }

            guard let fileURL = url else { return }

            loadedSongId = songId
            Task {
                do {
                    let samples = try await PlayerManager.shared.waveformGenerator.generate(
                        url: fileURL, samplesCount: barCount
                    )
                    let amps = samples.map { CGFloat(max($0.positive, -$0.negative)) }
                    // 归一化
                    let maxVal = amps.max() ?? 1.0
                    let normalized = maxVal > 0 ? amps.map { $0 / maxVal } : amps
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.3)) {
                            realAmplitudes = normalized
                        }
                    }
                } catch {
                    // 波形生成失败，保持占位
                }
            }
        }
        
        /// 判断某个进度位置是否在副歌区间内
        private func isInChorus(barProgress: Double) -> Bool {
            guard let start = chorusStart, let end = chorusEnd, duration > 0 else { return false }
            let startP = start / duration
            let endP = end / duration
            return barProgress >= startP && barProgress <= endP
        }
    }
}
