// AudioMatchView.swift
// 听歌识曲 - 使用 ShazamKit 识别音乐

import SwiftUI
import ShazamKit
import AVFoundation

// MARK: - AudioMatchViewModel

@MainActor
final class AudioMatchViewModel: ObservableObject {
    enum MatchState: Equatable {
        case idle
        case listening
        case matching
        case found
        case notFound
        case error(String)
        
        static func == (lhs: MatchState, rhs: MatchState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.listening, .listening), (.matching, .matching),
                 (.found, .found), (.notFound, .notFound):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }
    
    @Published var state: MatchState = .idle
    @Published var matchedSongs: [Song] = []
    @Published var shazamTitle: String?
    @Published var shazamArtist: String?
    @Published var shazamArtworkURL: URL?
    @Published var listenProgress: CGFloat = 0
    
    private var session: SHSession?
    private var audioEngine: AVAudioEngine?
    private var listenTimer: Timer?
    private var listenDuration: TimeInterval = 0
    private let maxListenDuration: TimeInterval = 15
    
    func startListening() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.beginShazamSession()
                } else {
                    self.state = .error(NSLocalizedString("audio_match_mic_denied", comment: ""))
                }
            }
        }
    }
    
    func stopListening() {
        stopAudioEngine()
        listenTimer?.invalidate()
        listenTimer = nil
        listenDuration = 0
        listenProgress = 0
        if state == .listening {
            state = .idle
        }
    }
    
    func reset() {
        stopListening()
        state = .idle
        matchedSongs = []
        shazamTitle = nil
        shazamArtist = nil
        shazamArtworkURL = nil
    }
    
    // MARK: - ShazamKit
    
    private func beginShazamSession() {
        state = .listening
        listenDuration = 0
        listenProgress = 0
        
        session = SHSession()
        session?.delegate = ShazamDelegate(viewModel: self)
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            let audioEngine = AVAudioEngine()
            self.audioEngine = audioEngine
            
            let inputNode = audioEngine.inputNode
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
                self?.session?.matchStreamingBuffer(buffer, at: nil)
            }
            
            try audioEngine.start()
            
            listenTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.state == .listening else { return }
                    self.listenDuration += 0.1
                    self.listenProgress = min(CGFloat(self.listenDuration / self.maxListenDuration), 1.0)
                    
                    if self.listenDuration >= self.maxListenDuration {
                        self.stopListening()
                        if self.state == .listening {
                            self.state = .notFound
                        }
                    }
                }
            }
        } catch {
            AppLogger.error("AudioMatch: 启动录音失败 - \(error)")
            state = .error(NSLocalizedString("audio_match_error", comment: ""))
        }
    }
    
    private func stopAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    fileprivate func handleMatch(_ match: SHMatch) {
        stopListening()
        guard let item = match.mediaItems.first else {
            state = .notFound
            return
        }
        state = .matching
        shazamTitle = item.title
        shazamArtist = item.artist
        shazamArtworkURL = item.artworkURL
        AppLogger.info("AudioMatch: Shazam 识别成功 - \(item.title ?? "") by \(item.artist ?? "")")
        searchMatchedSong(title: item.title, artist: item.artist)
    }
    
    fileprivate func handleNoMatch() {}
    
    fileprivate func handleError(_ error: Error) {
        stopListening()
        AppLogger.error("AudioMatch: Shazam 错误 - \(error)")
        state = .error(NSLocalizedString("audio_match_error", comment: ""))
    }
    
    private func searchMatchedSong(title: String?, artist: String?) {
        guard let title, !title.isEmpty else {
            state = .notFound
            return
        }
        let query = artist != nil ? "\(title) \(artist!)" : title
        Task {
            do {
                let songs = try await APIService.shared.searchSongs(keyword: query).async()
                let topSongs = Array(songs.prefix(5))
                if topSongs.isEmpty {
                    state = .notFound
                } else {
                    matchedSongs = topSongs
                    state = .found
                }
            } catch {
                AppLogger.error("AudioMatch: 搜索匹配失败 - \(error)")
                state = .found
            }
        }
    }
}

// MARK: - SHSessionDelegate

private class ShazamDelegate: NSObject, SHSessionDelegate {
    weak var viewModel: AudioMatchViewModel?
    init(viewModel: AudioMatchViewModel) { self.viewModel = viewModel }
    
    func session(_ session: SHSession, didFind match: SHMatch) {
        Task { @MainActor in viewModel?.handleMatch(match) }
    }
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: (any Error)?) {
        Task { @MainActor in
            if let error { viewModel?.handleError(error) }
            else { viewModel?.handleNoMatch() }
        }
    }
}


// MARK: - AudioMatchView

struct AudioMatchView: View {
    @StateObject private var viewModel = AudioMatchViewModel()
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var pulsePhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 40)
                        
                        // 中心识别区域
                        centerContent
                            .frame(minHeight: 360)
                        
                        // 结果区域
                        if viewModel.state == .found && !viewModel.matchedSongs.isEmpty {
                            resultsSection
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        Spacer().frame(height: 100)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .onDisappear { viewModel.stopListening() }
    }
    
    // MARK: - 顶部栏
    
    private var headerBar: some View {
        HStack {
            AsideBackButton()
            Spacer()
            Text(LocalizedStringKey("audio_match_title"))
                .font(.rounded(size: 18, weight: .bold))
                .foregroundColor(.asideTextPrimary)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, DeviceLayout.headerTopPadding)
    }
    
    // MARK: - 中心内容
    
    @ViewBuilder
    private var centerContent: some View {
        switch viewModel.state {
        case .idle:         idleView
        case .listening:    listeningView
        case .matching:     matchingView
        case .found:        foundView
        case .notFound:     notFoundView
        case .error(let m): errorView(message: m)
        }
    }
    
    // MARK: - 空闲状态
    
    private var idleView: some View {
        VStack(spacing: 36) {
            // 主按钮
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.startListening()
            }) {
                ZStack {
                    // 装饰环
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.asideTextPrimary.opacity(0.05), .asideTextPrimary.opacity(0.15), .asideTextPrimary.opacity(0.05)],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 190, height: 190)
                    
                    // 主圆
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 150, height: 150)
                        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 10)
                    
                    // 图标
                    AsideIcon(icon: .audioWave, size: 52, color: .asideTextPrimary, lineWidth: 1.8)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("audio_match_tap_to_start"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                
                Text(LocalizedStringKey("audio_match_hint"))
                    .font(.rounded(size: 14))
                    .foregroundColor(.asideTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
        }
    }
    
    // MARK: - 监听中
    
    private var listeningView: some View {
        VStack(spacing: 36) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.stopListening()
            }) {
                ZStack {
                    // 脉冲波纹
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.asideTextPrimary.opacity(0.12), lineWidth: 1.5)
                            .frame(width: 190 + CGFloat(i) * 44, height: 190 + CGFloat(i) * 44)
                            .scaleEffect(pulsePhase > 0 ? 1.08 : 0.92)
                            .opacity(pulsePhase > 0 ? 0.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 1.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.35),
                                value: pulsePhase
                            )
                    }
                    
                    // 进度环
                    Circle()
                        .trim(from: 0, to: viewModel.listenProgress)
                        .stroke(
                            Color.asideTextPrimary,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: viewModel.listenProgress)
                    
                    // 主圆
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 150, height: 150)
                        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 10)
                    
                    // 音纹动画
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { i in
                            AudioWaveBar(index: i)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear { pulsePhase = 1 }
            .onDisappear { pulsePhase = 0 }
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("audio_match_listening"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                
                Text(LocalizedStringKey("audio_match_listening_hint"))
                    .font(.rounded(size: 14))
                    .foregroundColor(.asideTextSecondary)
            }
        }
    }
    
    // MARK: - 匹配中
    
    private var matchingView: some View {
        VStack(spacing: 28) {
            if let artworkURL = viewModel.shazamArtworkURL {
                CachedAsyncImage(url: artworkURL) {
                    RoundedRectangle(cornerRadius: 24).fill(Color.asideCardBackground)
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
            }
            
            VStack(spacing: 6) {
                if let title = viewModel.shazamTitle {
                    Text(title)
                        .font(.rounded(size: 22, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                if let artist = viewModel.shazamArtist {
                    Text(artist)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            .padding(.horizontal, 40)
            
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(LocalizedStringKey("audio_match_searching"))
                    .font(.rounded(size: 14, weight: .medium))
                    .foregroundColor(.asideTextSecondary)
            }
        }
    }
    
    // MARK: - 找到结果
    
    private var foundView: some View {
        VStack(spacing: 24) {
            if let artworkURL = viewModel.shazamArtworkURL {
                CachedAsyncImage(url: artworkURL) {
                    RoundedRectangle(cornerRadius: 24).fill(Color.asideCardBackground)
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
            }
            
            VStack(spacing: 6) {
                if let title = viewModel.shazamTitle {
                    Text(title)
                        .font(.rounded(size: 22, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                if let artist = viewModel.shazamArtist {
                    Text(artist)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            .padding(.horizontal, 40)
            
            // 重新识别
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.reset()
            }) {
                HStack(spacing: 6) {
                    AsideIcon(icon: .refresh, size: 14, color: .asideTextSecondary, lineWidth: 1.4)
                    Text(LocalizedStringKey("audio_match_retry"))
                        .font(.rounded(size: 14, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.asideCardBackground))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - 未找到
    
    private var notFoundView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.asideCardBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
                
                AsideIcon(icon: .audioWave, size: 44, color: .asideTextSecondary.opacity(0.4), lineWidth: 1.6)
            }
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("audio_match_not_found"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                
                Text(LocalizedStringKey("audio_match_not_found_hint"))
                    .font(.rounded(size: 14))
                    .foregroundColor(.asideTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.reset()
                viewModel.startListening()
            }) {
                HStack(spacing: 6) {
                    AsideIcon(icon: .refresh, size: 14, color: .asideIconForeground, lineWidth: 1.4)
                    Text(LocalizedStringKey("audio_match_try_again"))
                        .font(.rounded(size: 15, weight: .bold))
                }
                .foregroundColor(.asideIconForeground)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.asideIconBackground))
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
    }
    
    // MARK: - 错误
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.asideCardBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
                
                AsideIcon(icon: .warning, size: 44, color: .asideTextSecondary.opacity(0.4))
            }
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("audio_match_error"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                
                Text(message)
                    .font(.rounded(size: 14))
                    .foregroundColor(.asideTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
            
            Button(action: {
                viewModel.reset()
                viewModel.startListening()
            }) {
                HStack(spacing: 6) {
                    AsideIcon(icon: .refresh, size: 14, color: .asideIconForeground, lineWidth: 1.4)
                    Text(LocalizedStringKey("audio_match_try_again"))
                        .font(.rounded(size: 15, weight: .bold))
                }
                .foregroundColor(.asideIconForeground)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.asideIconBackground))
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
    }

    
    // MARK: - 搜索结果列表
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 分隔线
            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)
                .padding(.horizontal, 24)
            
            Text(LocalizedStringKey("audio_match_results"))
                .font(.rounded(size: 17, weight: .bold))
                .foregroundColor(.asideTextPrimary)
                .padding(.horizontal, 24)
            
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.matchedSongs.enumerated()), id: \.element.id) { index, song in
                    matchResultRow(song: song, index: index)
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func matchResultRow(song: Song, index: Int) -> some View {
        Button(action: {
            PlayerManager.shared.play(song: song, in: viewModel.matchedSongs)
        }) {
            HStack(spacing: 14) {
                // 封面
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.asideCardBackground)
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    Text(song.artistName)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 匹配度标签（第一个最匹配）
                if index == 0 {
                    Text(LocalizedStringKey("search_best_match"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.asideIconForeground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.asideIconBackground))
                }
                
                AsideIcon(icon: .play, size: 14, color: .asideTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.asideCardBackground)
                    .clipShape(Circle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
        .contextMenu {
            Button(action: {
                selectedSongForDetail = song
                showSongDetail = true
            }) {
                Label(NSLocalizedString("action_details", comment: ""), systemImage: "info.circle")
            }
        }
    }
}

// MARK: - 音纹波形条动画

private struct AudioWaveBar: View {
    let index: Int
    @State private var animating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.asideTextPrimary)
            .frame(width: 4, height: animating ? CGFloat.random(in: 16...38) : 8)
            .animation(
                .easeInOut(duration: Double.random(in: 0.3...0.6))
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.1),
                value: animating
            )
            .onAppear { animating = true }
    }
}
