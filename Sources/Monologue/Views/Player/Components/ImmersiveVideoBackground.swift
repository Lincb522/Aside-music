import SwiftUI
import AVFoundation

/// 全屏循环、静音的本地视频背景（影院沉浸播放器专用）。
/// 进入布局时播放，离开时暂停；静音以不干扰音乐播放（与动态封面同一策略）。
struct ImmersiveVideoBackground: View {
    let url: URL
    var isActive: Bool = true

    @StateObject private var model = ImmersiveVideoBackgroundModel()

    var body: some View {
        // 复用 DynamicCoverView.swift 中的 AVPlayerLayer 包装（videoGravity = .resizeAspectFill）
        PlayerVideoView(player: model.player)
            .allowsHitTesting(false)
            .onAppear {
                model.configure(url: url)
                if isActive { model.play() }
            }
            .onDisappear {
                model.pause()
            }
            .onChange(of: url) { _, newURL in
                model.configure(url: newURL)
                if isActive { model.play() }
            }
            .onChange(of: isActive) { _, active in
                active ? model.play() : model.pause()
            }
    }
}

@MainActor
final class ImmersiveVideoBackgroundModel: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .advance
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func configure(url: URL) {
        guard url != currentURL else { return }
        currentURL = url

        // 用 AVPlayerLooper 实现无缝循环
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true
    }

    func play() { player.play() }

    func pause() { player.pause() }
}
