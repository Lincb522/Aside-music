import Combine
import SwiftUI
import UIKit

struct DeviceLayoutMetrics: Equatable {
    let viewportSize: CGSize
    let screenSize: CGSize
    let safeAreaInsets: UIEdgeInsets

    static var fallback: Self {
        let size = CGSize(width: 375, height: 812)
        return Self(viewportSize: size, screenSize: size, safeAreaInsets: .zero)
    }
}

@MainActor
final class DeviceLayoutMetricsStore: ObservableObject {
    static let shared = DeviceLayoutMetricsStore()

    @Published private(set) var revision = 0

    private var metricsBySceneID: [String: DeviceLayoutMetrics] = [:]

    private init() {}

    func metrics(for window: UIWindow?) -> DeviceLayoutMetrics {
        guard let sceneID = window?.windowScene?.session.persistentIdentifier else {
            return .fallback
        }
        return metricsBySceneID[sceneID] ?? .fallback
    }

    func update(_ metrics: DeviceLayoutMetrics, for window: UIWindow) {
        guard let sceneID = window.windowScene?.session.persistentIdentifier,
              metricsBySceneID[sceneID] != metrics else {
            return
        }
        metricsBySceneID[sceneID] = metrics
        revision &+= 1
    }
}

/// Reads geometry only after the current SwiftUI update has unwound, then
/// publishes an immutable snapshot for view-body calculations.
struct DeviceLayoutMetricsProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        DeviceLayoutMetricsProbeView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class DeviceLayoutMetricsProbeView: UIView {
    private var isUpdateScheduled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        scheduleMetricsUpdate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleMetricsUpdate()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        scheduleMetricsUpdate()
    }

    private func scheduleMetricsUpdate() {
        guard window != nil, !isUpdateScheduled else { return }
        isUpdateScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isUpdateScheduled = false
            guard let window = self.window,
                  let windowScene = window.windowScene else { return }

            DeviceLayoutMetricsStore.shared.update(
                DeviceLayoutMetrics(
                    viewportSize: window.bounds.size,
                    screenSize: windowScene.screen.bounds.size,
                    // These insets are already expressed in the probe's local
                    // space, so UIKit does not need a cross-screen conversion.
                    safeAreaInsets: self.safeAreaInsets
                ),
                for: window
            )
        }
    }
}

@MainActor
struct DeviceLayout {
    private static var layoutWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication }
        let foregroundScenes = scenes.filter {
            $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
        }
        let windows = (foregroundScenes.isEmpty ? scenes : foregroundScenes).flatMap(\.windows)

        return windows.first(where: { $0.isKeyWindow && $0.windowLevel == .normal })
            ?? windows.first(where: { !$0.isHidden && $0.windowLevel == .normal })
            ?? windows.first(where: \.isKeyWindow)
    }

    private static var metrics: DeviceLayoutMetrics {
        DeviceLayoutMetricsStore.shared.metrics(for: layoutWindow)
    }

    /// 获取当前设备的顶部安全区域高度
    static var safeAreaTop: CGFloat {
        metrics.safeAreaInsets.top
    }
    
    /// 获取当前设备的底部安全区域高度
    static var safeAreaBottom: CGFloat {
        metrics.safeAreaInsets.bottom
    }
    
    /// 是否为刘海屏设备
    static var hasNotch: Bool { safeAreaTop >= 47 }
    
    /// 当前设备是否为 iPad。只用于平台能力判断，界面尺寸使用
    /// `usesExpandedLayout`，避免分屏和窗口化时继续套用全屏 iPad 布局。
    static var isPadDevice: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    /// 当前屏幕宽度
    static var screenWidth: CGFloat {
        metrics.screenSize.width
    }

    /// 当前应用窗口宽度，iPad 分屏和窗口化时随窗口变化
    static var viewportWidth: CGFloat {
        max(1, metrics.viewportSize.width)
    }

    static var screenHeight: CGFloat {
        metrics.screenSize.height
    }

    /// 当前应用窗口高度，随旋转、Split View 和 Stage Manager 变化。
    static var viewportHeight: CGFloat {
        max(1, metrics.viewportSize.height)
    }

    /// 当前窗口是否有足够空间采用 iPad 展开布局。
    static var usesExpandedLayout: Bool {
        isPadDevice && viewportWidth >= 680 && viewportHeight >= 600
    }
    
    /// 普通页面内容沿用的顶部间距。
    static var headerTopPadding: CGFloat {
        // The container owns the safe area; this is only spacing within its content.
        isPadDevice ? 12 : 8
    }

    /// 全屏播放器由外层容器负责系统安全区，这里只保留视觉间距。
    /// 不依赖异步窗口探针，避免播放器首次出现时因安全区尚未上报而误取 50pt。
    static var playerHeaderTopPadding: CGFloat {
        isPadDevice ? 12 : 8
    }
    
    /// 播放器底部 Padding（考虑安全区域）
    static var playerBottomPadding: CGFloat {
        hasNotch ? 40 : 20
    }
    
    /// 播放器封面最大尺寸（窗口宽度 - 两侧间距）
    static var playerArtworkMaxSize: CGFloat {
        let width = viewportWidth
        return usesExpandedLayout ? min(width * 0.5, 480) : min(width - 64, 360)
    }
    
    /// 播放器水平内边距
    static var playerHorizontalPadding: CGFloat { usesExpandedLayout ? 48 : 32 }
    
    // MARK: - iPad Adaptive Sizes
    
    /// 首页水平内边距
    static var homeHorizontalPadding: CGFloat { usesExpandedLayout ? 32 : 20 }
    
    /// 通用页面水平内边距
    static var viewHorizontalPadding: CGFloat { usesExpandedLayout ? 32 : 24 }

    /// 设置页顶部标题的水平内边距
    static var settingsHeaderHorizontalPadding: CGFloat { usesExpandedLayout ? 40 : 30 }

    /// 设置页类目卡片的水平内边距
    static var settingsSectionHorizontalPadding: CGFloat { usesExpandedLayout ? 32 : 20 }

    /// 旧设置页间距入口，保持给零散页面复用
    static var settingsPageHorizontalPadding: CGFloat { settingsSectionHorizontalPadding }
    
    /// 每日推荐卡片尺寸
    static var dailyCardSize: CGFloat { usesExpandedLayout ? 170 : 120 }
    
    /// NCM 歌单卡片尺寸
    static var playlistCardSize: CGFloat { usesExpandedLayout ? 200 : 160 }
    
    /// QQ 歌单宽卡片尺寸
    static var qqCardWidth: CGFloat { usesExpandedLayout ? 300 : 220 }
    static var qqCardHeight: CGFloat { usesExpandedLayout ? 190 : 140 }
    
    /// 新歌卡片尺寸
    static var newSongCardSize: CGFloat { usesExpandedLayout ? 200 : 160 }
    
    /// Banner 高度
    static var bannerHeight: CGFloat { usesExpandedLayout ? 200 : 120 }
    
    /// 入口卡片高度
    static var entryCardHeight: CGFloat { usesExpandedLayout ? 150 : 120 }
    
    // MARK: - Library
    
    /// 音乐库 header 水平内边距
    static var libraryHorizontalPadding: CGFloat { usesExpandedLayout ? 32 : 20 }
    
    /// 歌手网格列数
    static var artistGridColumns: Int {
        let spacing: CGFloat = 14
        let availableWidth = max(1, viewportWidth - libraryHorizontalPadding * 2)
        let fittingCount = Int((availableWidth + spacing) / (artistAvatarSize + spacing))
        return min(usesExpandedLayout ? 4 : 3, max(2, fittingCount))
    }
    
    /// 歌手头像尺寸
    static var artistAvatarSize: CGFloat { usesExpandedLayout ? 120 : 100 }
    
    /// 排行榜官方卡片尺寸
    static var chartCardSize: CGFloat { usesExpandedLayout ? 240 : 200 }
    
    /// 列表行封面尺寸（小）
    static var listRowCoverSmall: CGFloat { usesExpandedLayout ? 64 : 52 }
    
    /// 列表行封面尺寸（标准）
    static var listRowCoverStandard: CGFloat { usesExpandedLayout ? 68 : 56 }
    
    // MARK: - Player
    
    /// 播放器控制按钮尺寸
    static var playerPlayButtonSize: CGFloat { usesExpandedLayout ? 84 : 72 }
    
    /// 播放器控制图标尺寸
    static var playerControlIconSize: CGFloat { usesExpandedLayout ? 36 : 32 }
    
    /// 播放器底部 padding
    static var playerBottomSafePadding: CGFloat { usesExpandedLayout ? 60 : 50 }
    
    // MARK: - Detail Pages
    
    /// 详情页封面尺寸
    static var detailCoverSize: CGFloat { usesExpandedLayout ? 160 : 120 }
    
    /// Profile 头像尺寸
    static var profileAvatarSize: CGFloat { usesExpandedLayout ? 90 : 72 }
    
    /// 搜索结果网格列数
    static var searchGridColumns: Int {
        let spacing: CGFloat = 14
        let availableWidth = max(1, viewportWidth - viewHorizontalPadding * 2)
        let fittingCount = Int((availableWidth + spacing) / (100 + spacing))
        return min(usesExpandedLayout ? 4 : 3, max(2, fittingCount))
    }
}

// MARK: - iPad Adaptive View Modifier

extension View {
    /// 内容超过目标阅读宽度时收窄；窄窗口保持父容器宽度。
    func iPadContentWidth(_ maxWidth: CGFloat = 700) -> some View {
        self.frame(maxWidth: maxWidth)
    }
}
