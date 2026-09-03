import AVFoundation
import FFmpegSwiftSDK
import SwiftUI
import UIKit

/// 动态封面视频播放器 — 叠加在静态封面上方，循环播放
struct DynamicCoverView: View {
    let urlString: String
    let cornerRadius: CGFloat

    @StateObject private var viewModel = DynamicCoverViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            SilentVideoSurface(displayLayer: viewModel.player.videoDisplayLayer)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .opacity(viewModel.isReady ? 1 : 0)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .onAppear {
            updatePlayback()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: urlString) { newUrl in
            updatePlayback(urlString: newUrl)
        }
        .onChange(of: reduceMotion) { _ in
            updatePlayback()
        }
    }

    private func updatePlayback(urlString: String? = nil) {
        guard !reduceMotion else {
            AppLogger.info(
                "[DynamicCover] 系统已开启减弱动态效果，保持静态封面",
                step: "player.dynamic-cover",
                category: .playback,
                event: "disabled_by_reduce_motion"
            )
            viewModel.stop()
            return
        }
        viewModel.load(urlString: urlString ?? self.urlString)
    }
}

/// 统一的播放器动态封面层。每个主题只需把它放在静态封面上方，
/// 并由外层封面容器提供确定尺寸，避免视频图层在自定义布局中得到空帧。
struct DynamicArtworkOverlay: View {
    let cornerRadius: CGFloat

    @ObservedObject private var player = PlayerManager.shared

    init(cornerRadius: CGFloat = 0) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let urlString = player.dynamicCoverUrl, !urlString.isEmpty {
                DynamicCoverView(
                    urlString: urlString,
                    cornerRadius: cornerRadius
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
private final class DynamicCoverViewModel: ObservableObject {
    @Published private(set) var isReady = false
    let player: SilentVideoPlayer

    private var currentUrl: String?
    private var assetContext: [String: String] = [:]

    init() {
        let player = SilentVideoPlayer()
        self.player = player
        player.onStateChange = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handle(state)
            }
        }
    }

    func load(urlString: String) {
        guard let url = URL(string: urlString) else {
            stop()
            AppLogger.warning(
                "[DynamicCover] 动态封面地址无效",
                step: "player.dynamic-cover",
                category: .playback,
                event: "invalid_asset_url"
            )
            return
        }

        DynamicCoverSessionCoordinator.shared.activate(
            self,
            urlString: urlString,
            url: url
        )
    }

    func stop() {
        DynamicCoverSessionCoordinator.shared.deactivate(self)
    }

    fileprivate func startPlayback(urlString: String, url: URL) {
        if currentUrl == urlString {
            switch player.state {
            case .loading, .inputResolved, .playing:
                return
            case .idle, .failed:
                break
            }
        }

        player.stop()
        isReady = false
        currentUrl = urlString
        assetContext = Self.assetContext(for: url)
        AppLogger.debug(
            "[DynamicCover] 开始建立独立静音视频解码管线",
            step: "player.dynamic-cover",
            category: .playback,
            event: "silent_video_pipeline_started",
            context: assetContext
        )
        player.play(url: urlString)
    }

    fileprivate func suspendPlayback() {
        currentUrl = nil
        assetContext = [:]
        isReady = false
        player.stop()
    }

    private func handle(_ state: SilentVideoPlaybackState) {
        switch state {
        case .idle, .loading:
            isReady = false

        case .inputResolved(let info):
            guard currentUrl != nil else { return }
            isReady = false
            var resolvedContext = assetContext
            resolvedContext["masterPlaylist"] = String(info.sourceWasMasterPlaylist)
            if let width = info.selectedWidth {
                resolvedContext["selectedWidth"] = String(width)
            }
            if let height = info.selectedHeight {
                resolvedContext["selectedHeight"] = String(height)
            }
            if let codec = info.selectedCodec {
                resolvedContext["selectedCodec"] = codec
            }
            AppLogger.debug(
                "[DynamicCover] 已选定单一动态封面码流",
                step: "player.dynamic-cover",
                category: .playback,
                event: "silent_video_input_resolved",
                context: resolvedContext
            )

        case .playing(let hardwareAccelerated):
            guard currentUrl != nil else { return }
            isReady = true
            AppLogger.success(
                "[DynamicCover] 独立静音视频管线已输出首帧",
                step: "player.dynamic-cover",
                category: .playback,
                event: "silent_video_first_frame_rendered",
                context: assetContext.merging(
                    ["hardwareAccelerated": String(hardwareAccelerated)],
                    uniquingKeysWith: { current, _ in current }
                )
            )

        case .failed(let reason):
            guard currentUrl != nil else { return }
            isReady = false
            AppLogger.error(
                "[DynamicCover] 独立静音视频解码失败，已保持静态封面：\(reason)",
                step: "player.dynamic-cover",
                category: .playback,
                event: "silent_video_pipeline_failed",
                context: assetContext
            )
        }
    }

    private static func assetContext(for url: URL) -> [String: String] {
        [
            "assetHost": url.host ?? "unknown",
            "assetType": url.pathExtension.lowercased(),
        ]
    }

    deinit {
        player.onStateChange = nil
        player.stop()
    }
}

/// Dynamic artwork may be mounted twice while SwiftUI transitions between
/// player layouts. Keep one FFmpeg decoder active and promote the last visible
/// surface when the current one disappears. This coordinator is intentionally
/// unrelated to the immersive-background AVPlayer lifecycle.
@MainActor
private final class DynamicCoverSessionCoordinator {
    static let shared = DynamicCoverSessionCoordinator()

    private final class Entry {
        weak var owner: DynamicCoverViewModel?
        var urlString: String
        var url: URL

        init(owner: DynamicCoverViewModel, urlString: String, url: URL) {
            self.owner = owner
            self.urlString = urlString
            self.url = url
        }
    }

    private var entries: [ObjectIdentifier: Entry] = [:]
    private var visibleOrder: [ObjectIdentifier] = []
    private var activeIdentifier: ObjectIdentifier?
    private var pendingActivation: Task<Void, Never>?

    func activate(_ owner: DynamicCoverViewModel, urlString: String, url: URL) {
        pruneReleasedEntries()

        let identifier = ObjectIdentifier(owner)
        if let entry = entries[identifier] {
            entry.urlString = urlString
            entry.url = url
        } else {
            entries[identifier] = Entry(owner: owner, urlString: urlString, url: url)
        }
        visibleOrder.removeAll { $0 == identifier }
        visibleOrder.append(identifier)

        if activeIdentifier != identifier {
            activeOwner?.suspendPlayback()
            activeIdentifier = identifier
        }
        scheduleActivation(for: identifier)
    }

    func deactivate(_ owner: DynamicCoverViewModel) {
        let identifier = ObjectIdentifier(owner)
        entries.removeValue(forKey: identifier)
        visibleOrder.removeAll { $0 == identifier }
        owner.suspendPlayback()

        guard activeIdentifier == identifier else {
            pruneReleasedEntries()
            return
        }

        pendingActivation?.cancel()
        pendingActivation = nil
        activeIdentifier = nil
        promoteLastVisibleEntry()
    }

    private var activeOwner: DynamicCoverViewModel? {
        guard let activeIdentifier else { return nil }
        return entries[activeIdentifier]?.owner
    }

    private func promoteLastVisibleEntry() {
        pruneReleasedEntries()
        guard let identifier = visibleOrder.last,
              entries[identifier]?.owner != nil else {
            return
        }

        activeIdentifier = identifier
        scheduleActivation(for: identifier)
    }

    private func scheduleActivation(for identifier: ObjectIdentifier) {
        pendingActivation?.cancel()
        pendingActivation = Task { @MainActor [weak self] in
            // SwiftUI can mount the outgoing and incoming player layouts in the
            // same update. Wait one frame so only the final visible surface
            // starts network probing and decoding.
            try? await Task.sleep(nanoseconds: 24_000_000)
            guard !Task.isCancelled,
                  let self,
                  self.activeIdentifier == identifier,
                  let entry = self.entries[identifier],
                  let owner = entry.owner else {
                return
            }
            self.pendingActivation = nil
            owner.startPlayback(urlString: entry.urlString, url: entry.url)
        }
    }

    private func pruneReleasedEntries() {
        let released = entries.compactMap { identifier, entry in
            entry.owner == nil ? identifier : nil
        }
        guard !released.isEmpty else { return }

        let releasedSet = Set(released)
        released.forEach { entries.removeValue(forKey: $0) }
        visibleOrder.removeAll { releasedSet.contains($0) }
        if let activeIdentifier, releasedSet.contains(activeIdentifier) {
            pendingActivation?.cancel()
            pendingActivation = nil
            self.activeIdentifier = nil
        }
    }
}

/// UIKit wrapper for the FFmpeg-backed sample-buffer display layer.
private struct SilentVideoSurface: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> SilentVideoUIView {
        let view = SilentVideoUIView()
        view.attach(displayLayer)
        AppLogger.debug(
            "[DynamicCover] 独立视频图层已挂载",
            step: "player.dynamic-cover",
            category: .playback,
            event: "silent_video_surface_mounted"
        )
        return view
    }

    func updateUIView(_ uiView: SilentVideoUIView, context: Context) {
        uiView.attach(displayLayer)
    }

    static func dismantleUIView(_ uiView: SilentVideoUIView, coordinator: Void) {
        uiView.detach()
    }
}

private final class SilentVideoUIView: UIView {
    private weak var displayLayer: AVSampleBufferDisplayLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer?.frame = bounds
    }

    func attach(_ displayLayer: AVSampleBufferDisplayLayer) {
        guard self.displayLayer !== displayLayer else {
            displayLayer.frame = bounds
            return
        }
        self.displayLayer?.removeFromSuperlayer()
        self.displayLayer = displayLayer
        displayLayer.frame = bounds
        layer.addSublayer(displayLayer)
    }

    func detach() {
        displayLayer?.removeFromSuperlayer()
        displayLayer = nil
    }
}
