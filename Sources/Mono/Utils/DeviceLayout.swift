import UIKit
import SwiftUI

@MainActor
struct DeviceLayout {
    /// 获取当前设备的顶部安全区域高度
    static var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }
    
    /// 获取当前设备的底部安全区域高度
    static var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
    
    /// 是否为刘海屏设备
    static var hasNotch: Bool { safeAreaTop >= 47 }
    
    /// 是否为 iPad
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    /// 当前屏幕宽度
    static var screenWidth: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            return windowScene.screen.bounds.width
        }
        return 375
    }

    static var screenHeight: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            return windowScene.screen.bounds.height
        }
        return 812
    }
    
    /// 动态计算顶部 Padding
    static var headerTopPadding: CGFloat {
        hasNotch ? 8 : 50
    }
    
    /// 播放器底部 Padding（考虑安全区域）
    static var playerBottomPadding: CGFloat {
        hasNotch ? 40 : 20
    }
    
    /// 播放器封面最大尺寸（屏幕宽度 - 两侧间距）
    static var playerArtworkMaxSize: CGFloat {
        let w = screenWidth
        return isPad ? min(w * 0.5, 480) : min(w - 64, 360)
    }
    
    /// 播放器水平内边距
    static var playerHorizontalPadding: CGFloat { isPad ? 48 : 32 }
    
    // MARK: - iPad Adaptive Sizes
    
    /// 首页水平内边距
    static var homeHorizontalPadding: CGFloat { isPad ? 32 : 20 }
    
    /// 通用页面水平内边距
    static var viewHorizontalPadding: CGFloat { isPad ? 32 : 24 }

    /// 设置页顶部标题的水平内边距
    static var settingsHeaderHorizontalPadding: CGFloat { isPad ? 40 : 30 }

    /// 设置页类目卡片的水平内边距
    static var settingsSectionHorizontalPadding: CGFloat { isPad ? 32 : 20 }

    /// 旧设置页间距入口，保持给零散页面复用
    static var settingsPageHorizontalPadding: CGFloat { settingsSectionHorizontalPadding }
    
    /// 每日推荐卡片尺寸
    static var dailyCardSize: CGFloat { isPad ? 170 : 120 }
    
    /// NCM 歌单卡片尺寸
    static var playlistCardSize: CGFloat { isPad ? 200 : 160 }
    
    /// QQ 歌单宽卡片尺寸
    static var qqCardWidth: CGFloat { isPad ? 300 : 220 }
    static var qqCardHeight: CGFloat { isPad ? 190 : 140 }
    
    /// 新歌卡片尺寸
    static var newSongCardSize: CGFloat { isPad ? 200 : 160 }
    
    /// Banner 高度
    static var bannerHeight: CGFloat { isPad ? 200 : 120 }
    
    /// 入口卡片高度
    static var entryCardHeight: CGFloat { isPad ? 150 : 120 }
    
    // MARK: - Library
    
    /// 音乐库 header 水平内边距
    static var libraryHorizontalPadding: CGFloat { isPad ? 32 : 20 }
    
    /// 歌手网格列数
    static var artistGridColumns: Int { isPad ? 4 : 3 }
    
    /// 歌手头像尺寸
    static var artistAvatarSize: CGFloat { isPad ? 120 : 100 }
    
    /// 排行榜官方卡片尺寸
    static var chartCardSize: CGFloat { isPad ? 240 : 200 }
    
    /// 列表行封面尺寸（小）
    static var listRowCoverSmall: CGFloat { isPad ? 64 : 52 }
    
    /// 列表行封面尺寸（标准）
    static var listRowCoverStandard: CGFloat { isPad ? 68 : 56 }
    
    // MARK: - Player
    
    /// 播放器控制按钮尺寸
    static var playerPlayButtonSize: CGFloat { isPad ? 84 : 72 }
    
    /// 播放器控制图标尺寸
    static var playerControlIconSize: CGFloat { isPad ? 36 : 32 }
    
    /// 播放器底部 padding
    static var playerBottomSafePadding: CGFloat { isPad ? 60 : 50 }
    
    // MARK: - Detail Pages
    
    /// 详情页封面尺寸
    static var detailCoverSize: CGFloat { isPad ? 160 : 120 }
    
    /// Profile 头像尺寸
    static var profileAvatarSize: CGFloat { isPad ? 90 : 72 }
    
    /// 搜索结果网格列数
    static var searchGridColumns: Int { isPad ? 4 : 3 }
}

// MARK: - iPad Adaptive View Modifier

extension View {
    /// 在 iPad 上限制内容最大宽度并居中
    func iPadContentWidth(_ maxWidth: CGFloat = 700) -> some View {
        self.frame(maxWidth: DeviceLayout.isPad ? maxWidth : .infinity)
    }
}
