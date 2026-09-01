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

actor ImmersiveVideoBrightnessAnalyzer {
    static let shared = ImmersiveVideoBrightnessAnalyzer()

    private var cache: [URL: Bool] = [:]
    private var inFlight: [URL: Task<Bool?, Never>] = [:]

    func isBright(_ url: URL) async -> Bool? {
        if let cached = cache[url] { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task.detached(priority: .utility) {
            await Self.analyze(url)
        }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result { cache[url] = result }
        return result
    }

    private nonisolated static func analyze(_ url: URL) async -> Bool? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.15, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.15, preferredTimescale: 600)

        let duration = (try? await asset.load(.duration).seconds) ?? 0
        let sampleSeconds: [Double]
        if duration.isFinite, duration > 2 {
            sampleSeconds = [duration * 0.12, duration * 0.5, duration * 0.84]
        } else {
            sampleSeconds = [min(max(duration * 0.5, 0), 1)]
        }

        var luminances: [Double] = []
        for seconds in sampleSeconds {
            guard !Task.isCancelled else { return nil }
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            guard let cgImage = try? await generator.image(at: time).image else { continue }
            luminances.append(perceivedLuminance(of: cgImage))
        }

        guard !luminances.isEmpty else { return nil }
        let sorted = luminances.sorted()
        let representative = sorted[sorted.count / 2]
        return representative >= 0.54
    }

    private nonisolated static func perceivedLuminance(of image: CGImage) -> Double {
        let side = 32
        let bytesPerPixel = 4
        var bytes = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &bytes,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * bytesPerPixel,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
              ) else { return 0.5 }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        var total = 0.0
        var count = 0.0
        for y in 3..<(side - 3) {
            for x in 3..<(side - 3) {
                let offset = (y * side + x) * bytesPerPixel
                let alpha = Double(bytes[offset + 3]) / 255
                guard alpha > 0.2 else { continue }
                let red = Double(bytes[offset]) / 255
                let green = Double(bytes[offset + 1]) / 255
                let blue = Double(bytes[offset + 2]) / 255
                total += (red * 0.2126 + green * 0.7152 + blue * 0.0722) * alpha
                count += alpha
            }
        }
        return count > 0 ? total / count : 0.5
    }
}
