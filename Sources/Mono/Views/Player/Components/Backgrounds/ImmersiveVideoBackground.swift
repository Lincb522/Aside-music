import SwiftUI
import AVFoundation
import UIKit

/// 现役 Aria 沉浸舞台使用的全屏循环静音视频背景。
/// 进入舞台时播放，退到后台或被设置页遮挡时暂停；离开舞台后释放播放队列。
struct ImmersiveVideoBackground: View {
    @Environment(\.scenePhase) private var scenePhase

    let url: URL
    var isActive: Bool = true

    @StateObject private var model = ImmersiveVideoBackgroundModel()
    @State private var isVisible = false

    var body: some View {
        ImmersiveAVPlayerView(player: model.player)
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
            .onChange(of: url) { newURL in
                model.configure(url: newURL)
                updatePlaybackState()
            }
            .onChange(of: isActive) { _ in
                updatePlaybackState()
            }
            .onChange(of: scenePhase) { _ in
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

/// The immersive background deliberately keeps its own AVPlayer surface.
/// Dynamic artwork uses the separate FFmpeg video-only pipeline instead.
private struct ImmersiveAVPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> ImmersiveAVPlayerUIView {
        let view = ImmersiveAVPlayerUIView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ImmersiveAVPlayerUIView, context: Context) {
        guard uiView.playerLayer.player !== player else { return }
        uiView.playerLayer.player = player
    }

    static func dismantleUIView(_ uiView: ImmersiveAVPlayerUIView, coordinator: Void) {
        uiView.playerLayer.player = nil
    }
}

private final class ImmersiveAVPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

@MainActor
final class ImmersiveVideoBackgroundModel: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var currentURL: URL?
    private var preparationTask: Task<Void, Never>?
    private var wantsPlayback = false

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .advance
        player.automaticallyWaitsToMinimizeStalling = false
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func configure(url: URL) {
        guard url != currentURL else { return }
        preparationTask?.cancel()
        preparationTask = nil
        player.pause()
        releaseCurrentItem()
        currentURL = url

        AppLogger.debug(
            "[ImmersiveVideo] 开始准备无音轨视频背景",
            step: "player.immersive-video",
            category: .playback,
            event: "video_only_preparation_started",
            context: Self.assetContext(for: url)
        )

        preparationTask = Task { @MainActor [weak self] in
            do {
                let item = try await Self.makeVideoOnlyPlayerItem(url: url)
                try Task.checkCancellation()
                guard let self, self.currentURL == url else { return }

                self.preparationTask = nil
                self.looper = AVPlayerLooper(player: self.player, templateItem: item)
                self.player.isMuted = true
                if self.wantsPlayback {
                    self.player.play()
                }
                AppLogger.success(
                    "[ImmersiveVideo] 纯视频背景已就绪",
                    step: "player.immersive-video",
                    category: .playback,
                    event: "video_only_ready",
                    context: Self.assetContext(for: url)
                )
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.currentURL == url else { return }
                self.preparationTask = nil
                AppLogger.error(
                    "[ImmersiveVideo] 无法建立纯视频背景：\(error.localizedDescription)",
                    step: "player.immersive-video",
                    category: .playback,
                    event: "video_only_preparation_failed",
                    context: Self.assetContext(for: url)
                )
            }
        }
    }

    func play() {
        wantsPlayback = true
        guard looper != nil else { return }
        player.play()
    }

    func pause() {
        wantsPlayback = false
        player.pause()
    }

    func teardown() {
        preparationTask?.cancel()
        preparationTask = nil
        wantsPlayback = false
        player.pause()
        releaseCurrentItem()
        currentURL = nil
    }

    private func releaseCurrentItem() {
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }

    /// Build an AVComposition that contains only the source video track. Muting
    /// an AVPlayer is insufficient because an attached audio track can still
    /// activate the app audio session and interrupt MusicKit or Mono playback.
    private static func makeVideoOnlyPlayerItem(url: URL) async throws -> AVPlayerItem {
        let asset = AVURLAsset(url: url)
        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ImmersiveVideoBackgroundError.missingVideoTrack
        }

        let sourceTimeRange = try await sourceVideoTrack.load(.timeRange)
        guard sourceTimeRange.duration.isNumeric,
              sourceTimeRange.duration > .zero else {
            throw ImmersiveVideoBackgroundError.invalidVideoDuration
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ImmersiveVideoBackgroundError.cannotCreateVideoTrack
        }

        try videoTrack.insertTimeRange(
            sourceTimeRange,
            of: sourceVideoTrack,
            at: .zero
        )
        videoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

        // The composition deliberately has no audio track. Keep isMuted as a
        // defensive invariant, but audio-session isolation comes from removal.
        return AVPlayerItem(asset: composition)
    }

    private static func assetContext(for url: URL) -> [String: String] {
        [
            "assetType": url.pathExtension.lowercased(),
            "isLocalFile": String(url.isFileURL),
        ]
    }

    deinit {
        preparationTask?.cancel()
    }
}

private enum ImmersiveVideoBackgroundError: LocalizedError {
    case missingVideoTrack
    case invalidVideoDuration
    case cannotCreateVideoTrack

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            return "The background asset does not contain a video track"
        case .invalidVideoDuration:
            return "The background video duration is invalid"
        case .cannotCreateVideoTrack:
            return "The video-only composition could not create a video track"
        }
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
