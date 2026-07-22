import SwiftUI
import AVKit

/// 动态封面视频播放器 — 叠加在静态封面上方，循环播放
struct DynamicCoverView: View {
    let urlString: String
    let cornerRadius: CGFloat
    
    @StateObject private var viewModel = DynamicCoverViewModel()
    
    var body: some View {
        Group {
            if viewModel.isReady {
                PlayerVideoView(player: viewModel.player)
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeIn(duration: 0.5)))
            }
        }
        .onAppear {
            viewModel.load(urlString: urlString)
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: urlString) { _, newUrl in
            viewModel.load(urlString: newUrl)
        }
    }
}

@MainActor
private class DynamicCoverViewModel: ObservableObject {
    @Published var isReady = false
    let player = AVPlayer()
    private var loopObserver: NSObjectProtocol?
    private var currentUrl: String?
    
    func load(urlString: String) {
        guard urlString != currentUrl else { return }
        currentUrl = urlString
        isReady = false
        
        guard let url = URL(string: urlString) else { return }
        
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        player.play()
        
        removeObserver()
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isReady = true
        }
    }
    
    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeObserver()
        currentUrl = nil
        isReady = false
    }
    
    private func removeObserver() {
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
    }
    
    deinit {
        player.pause()
    }
}

/// UIKit AVPlayerLayer wrapper for better video rendering
struct PlayerVideoView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        guard uiView.playerLayer.player !== player else { return }
        uiView.playerLayer.player = player
    }
    
    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
