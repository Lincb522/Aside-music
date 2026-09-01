import UIKit
import SwiftUI

@MainActor
struct DeviceLayout {
    private static var cachedSafeAreaInsets: [ObjectIdentifier: UIEdgeInsets] = [:]
    private static var resolvingSafeAreaWindows = Set<ObjectIdentifier>()

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

    private static var safeAreaInsets: UIEdgeInsets {
        guard let window = layoutWindow else { return .zero }
        let windowID = ObjectIdentifier(window)

        // UIKit can re-enter SwiftUI status-bar evaluation while resolving window insets.
        guard resolvingSafeAreaWindows.insert(windowID).inserted else {
            return cachedSafeAreaInsets[windowID] ?? .zero
        }
        defer { resolvingSafeAreaWindows.remove(windowID) }

        let insets = window.safeAreaInsets
        cachedSafeAreaInsets[windowID] = insets
        return insets
    }

    /// 获取当前设备的顶部安全区域高度
    static var safeAreaTop: CGFloat {
        safeAreaInsets.top
    }
    
    /// 获取当前设备的底部安全区域高度
    static var safeAreaBottom: CGFloat {
        safeAreaInsets.bottom
    }
    
    /// 是否为刘海屏设备
    static var hasNotch: Bool { safeAreaTop >= 47 }
    
    /// 当前设备是否为 iPad。只用于平台能力判断，界面尺寸使用
    /// `usesExpandedLayout`，避免分屏和窗口化时继续套用全屏 iPad 布局。
    static var isPadDevice: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    /// 当前屏幕宽度
    static var screenWidth: CGFloat {
        layoutWindow?.screen.bounds.width ?? 375
    }

    /// 当前应用窗口宽度，iPad 分屏和窗口化时随窗口变化
    static var viewportWidth: CGFloat {
        max(1, layoutWindow?.bounds.width ?? screenWidth)
    }

    static var screenHeight: CGFloat {
        layoutWindow?.screen.bounds.height ?? 812
    }

    /// 当前应用窗口高度，随旋转、Split View 和 Stage Manager 变化。
    static var viewportHeight: CGFloat {
        max(1, layoutWindow?.bounds.height ?? screenHeight)
    }

    /// 当前窗口是否有足够空间采用 iPad 展开布局。
    static var usesExpandedLayout: Bool {
        isPadDevice && viewportWidth >= 680 && viewportHeight >= 600
    }
    
    /// 动态计算顶部 Padding
    static var headerTopPadding: CGFloat {
        if isPadDevice { return 12 }
        return hasNotch ? 8 : 50
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
