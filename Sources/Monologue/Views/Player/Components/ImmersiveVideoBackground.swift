import SwiftUI
import AVFoundation

/// 现役 Aria 沉浸舞台使用的全屏循环静音视频背景。
/// 进入舞台时播放，退到后台或被设置页遮挡时暂停；离开舞台后释放播放队列。
struct ImmersiveVideoBackground: View {
    @Environment(\.scenePhase) private var scenePhase

    let url: URL
    var isActive: Bool = true

    @StateObject private var model = ImmersiveVideoBackgroundModel()
    @State private var isVisible = false

    var body: some View {
        // 复用 DynamicCoverView.swift 中的 AVPlayerLayer 包装（videoGravity = .resizeAspectFill）
        PlayerVideoView(player: model.player)
            .allowsHitTesting(false)
            .onAppear {
                isVisible = true
                model.configure(url: url)
                updatePlaybackState()
            }
            .onDisappear {
                isVisible = false
                model.teardown()
            }
            .onChange(of: url) { _, newURL in
                model.configure(url: newURL)
                updatePlaybackState()
            }
            .onChange(of: isActive) { _, _ in
                updatePlaybackState()
            }
            .onChange(of: scenePhase) { _, _ in
                updatePlaybackState()
            }
    }

    private func updatePlaybackState() {
        if isVisible, isActive, scenePhase == .active {
            model.play()
        } else {
            model.pause()
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
        player.automaticallyWaitsToMinimizeStalling = false
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func configure(url: URL) {
        guard url != currentURL else { return }
        player.pause()
        releaseCurrentItem()
        currentURL = url

        // 用 AVPlayerLooper 实现无缝循环
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true
    }

    func play() { player.play() }

    func pause() { player.pause() }

    func teardown() {
        pause()
        releaseCurrentItem()
        currentURL = nil
    }

    private func releaseCurrentItem() {
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }
}
