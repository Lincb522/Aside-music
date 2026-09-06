import Combine
import Foundation

/// 播客工具栏的共享状态：订阅播放器的倍速与睡眠定时器，格式化为展示文本。
/// 独立成 Model 是为了避免工具栏直接观察 PlayerManager 导致的频繁重绘。
@MainActor
final class PodcastToolbarModel: ObservableObject {
    static let shared = PodcastToolbarModel()

    @Published private(set) var speedText: String
    @Published private(set) var timerText: String?

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let player = PlayerManager.shared
        speedText = Self.formatSpeed(player.playbackSpeed)
        timerText = Self.formatTimer(
            pendingStopAfterCurrentTrack: player.pendingSleepStopAfterCurrentTrack,
            remaining: player.sleepAndFade.remaining
        )

        player.$playbackSpeed
            .removeDuplicates()
            .map(Self.formatSpeed)
            .removeDuplicates()
            .sink { [weak self] text in
                Task { @MainActor [weak self] in
                    self?.speedText = text
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            player.$pendingSleepStopAfterCurrentTrack.removeDuplicates(),
            player.sleepAndFade.$remaining.removeDuplicates()
        )
        .map(Self.formatTimer)
        .removeDuplicates()
        .sink { [weak self] text in
            Task { @MainActor [weak self] in
                self?.timerText = text
            }
        }
        .store(in: &cancellables)
    }

    private static func formatSpeed(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return String(format: "%.0fx", speed)
        }
        return String(format: "%.1fx", speed)
    }

    /// 定时器文本："播完本集停"优先，其次剩余分秒；未设置时返回 nil（仅显图标）。
    private static func formatTimer(
        pendingStopAfterCurrentTrack: Bool,
        remaining: TimeInterval?
    ) -> String? {
        if pendingStopAfterCurrentTrack {
            return String(localized: "podcast_timer_pending_short")
        }
        guard let remaining else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
