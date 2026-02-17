import SwiftUI
import AVKit
import Combine

// MARK: - Mlog 播放器

struct MlogPlayerView: View {
    let mlog: MlogItem
    
    @StateObject private var viewModel = MlogPlayerViewModel()
    @ObservedObject private var playerManager = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Button(action: { dismiss() }) {
                        AsideIcon(icon: .close, size: 18, color: .white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, DeviceLayout.headerTopPadding)
                
                Spacer()
                
                // 视频播放区域
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 24)
                } else if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text(LocalizedStringKey("mlog_loading"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else if viewModel.errorMessage != nil {
                    VStack(spacing: 12) {
                        AsideIcon(icon: .warning, size: 32, color: .white.opacity(0.4))
                        Text(LocalizedStringKey("mlog_load_failed"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Button(action: { viewModel.fetchUrl(id: mlog.id) }) {
                            Text(LocalizedStringKey("action_retry"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                }
                
                Spacer()
                
                // 底部信息
                VStack(alignment: .leading, spacing: 12) {
                    if !mlog.text.isEmpty {
                        Text(mlog.text)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(3)
                    }
                    
                    // 关联歌曲
                    if let song = mlog.song {
                        Button(action: {
                            playerManager.playSingle(song: song)
                        }) {
                            HStack(spacing: 10) {
                                CachedAsyncImage(url: song.coverUrl) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.1))
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(song.artistName)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                AsideIcon(icon: .play, size: 14, color: .white)
                                    .frame(width: 28, height: 28)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            viewModel.fetchUrl(id: mlog.id)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - ViewModel

@MainActor
class MlogPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchUrl(id: String) {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.fetchMlogUrl(id: id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] urlString in
                guard let self, let urlString, let url = URL(string: urlString) else {
                    self?.errorMessage = "No URL"
                    return
                }
                let avPlayer = AVPlayer(url: url)
                self.player = avPlayer
                avPlayer.play()
            })
            .store(in: &cancellables)
    }
    
    func cleanup() {
        player?.pause()
        player = nil
    }
}
