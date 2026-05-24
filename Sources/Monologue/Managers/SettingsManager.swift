import Combine
import SwiftUI

/// 全局设置管理器
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - 外观设置

    /// 全局主题 ID
    @AppStorage("globalThemeId") var globalThemeIdRaw: String = GlobalThemeId.appDefault.rawValue

    @Published private(set) var globalThemeRevision: Int = 0
    @Published private(set) var globalThemeApplicationRevision: Int = 0

    var globalThemeId: GlobalThemeId {
        get {
            let id = Self.resolveStoredTheme(globalThemeIdRaw)
            return Self.resolveRemovedTheme(id)
        }
        set {
            selectGlobalTheme(newValue)
        }
    }

    func selectGlobalTheme(_ themeId: GlobalThemeId) {
        let resolvedId = Self.resolveRemovedTheme(themeId)
        let previousId = globalThemeId
        let isSameTheme = previousId == resolvedId

        AppLogger.info("[ThemeSwitch] from=\(previousId.rawValue) to=\(resolvedId.rawValue) sameTheme=\(isSameTheme)")
        applyGlobalThemeSelection(
            resolvedId,
            bumpRevision: true,
            bumpApplicationRevision: true,
            applyPreferredIconSet: !isSameTheme
        )
    }

    func synchronizeGlobalThemeAfterLaunch(reason: String) {
        let storedRaw = UserDefaults.standard.string(forKey: GlobalThemeId.storageKey)
        let resolvedId = Self.resolveRemovedTheme(GlobalThemeId.resolvedStoredTheme(storedRaw ?? globalThemeIdRaw))

        AppLogger.info("[ThemeLaunchSync] reason=\(reason) persistedThemeId=\(storedRaw ?? "nil") finalThemeId=\(resolvedId.rawValue)")
        applyGlobalThemeSelection(
            resolvedId,
            bumpRevision: true,
            bumpApplicationRevision: true,
            applyPreferredIconSet: false
        )
    }

    private static func resolveRemovedTheme(_ id: GlobalThemeId) -> GlobalThemeId {
        GlobalThemeId.resolveRemovedTheme(id)
    }

    private static func resolveStoredTheme(_ raw: String) -> GlobalThemeId {
        GlobalThemeId.resolvedStoredTheme(raw)
    }

    /// 悬浮栏样式
    @AppStorage("floatingBarStyle") var floatingBarStyleRaw: String = FloatingBarStyle.unified.rawValue

    /// 悬浮栏样式（类型安全访问）
    var floatingBarStyle: FloatingBarStyle {
        get { FloatingBarStyle(rawValue: floatingBarStyleRaw) ?? .unified }
        set { floatingBarStyleRaw = newValue.rawValue }
    }

    /// 默认主题下自定义 TabBar 是否使用液态玻璃；关闭时使用更稳定的毛玻璃底。
    @AppStorage("defaultThemeUsesLiquidGlassTabBar") var defaultThemeUsesLiquidGlassTabBar: Bool = false

    @AppStorage("petWhiteUsesIllustratedBackground") var petWhiteUsesIllustratedBackground: Bool = false {
        didSet {
            globalThemeRevision &+= 1
        }
    }

    /// 主题模式: "system" 跟随系统, "light" 浅色, "dark" 深色
    @AppStorage("themeMode") var themeMode: String = "system" {
        didSet {
            applyTheme()
        }
    }

    /// 实际生效的 ColorScheme，始终有明确值
    @Published var activeColorScheme: ColorScheme = .light {
        didSet {
            guard activeColorScheme != oldValue else { return }
            UserDefaults.standard.set(activeColorScheme == .dark ? "dark" : "light", forKey: "themeResolvedColorScheme")
            GlobalThemeManager.shared.refreshCurrentThemeTokens()
            globalThemeRevision &+= 1
        }
    }

    /// 根据设置返回对应的 ColorScheme（用于 .preferredColorScheme 修饰符）
    var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // 跟随系统
        }
    }

    /// 返回未被全局封面影响的“真实”系统/用户预设色彩模式
    var nativeColorScheme: ColorScheme {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default:
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        }
    }

    /// 应用主题到所有窗口（确保 fullScreenCover 等独立层级也能实时生效）
    func applyTheme() {
        let style: UIUserInterfaceStyle
        switch themeMode {
        case "light": style = .light
        case "dark": style = .dark
        default: style = .unspecified // 跟随系统
        }

        // 遍历所有窗口场景，强制刷新 overrideUserInterfaceStyle
        var resolvedStyle: UIUserInterfaceStyle = style
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                    // 从窗口的 traitCollection 读取实际生效值（比 UITraitCollection.current 更可靠）
                    if style == .unspecified {
                        resolvedStyle = window.traitCollection.userInterfaceStyle
                    }
                }
            }
        }

        AppFrameRate.lockConnectedScenesToPreferredFrameRate(reason: "apply theme")

        // 更新 activeColorScheme
        if style == .dark {
            activeColorScheme = .dark
        } else if style == .light {
            activeColorScheme = .light
        } else {
            activeColorScheme = (resolvedStyle == .dark) ? .dark : .light
        }
    }

    // MARK: - 播放设置

    /// 音质设置（旧，保留兼容）
    @AppStorage("soundQuality") var soundQuality: String = "standard"

    /// 是否优先请求歌曲支持的最高音质
    @AppStorage(AppConfig.StorageKeys.preferHighestPlaybackQuality)
    var preferHighestPlaybackQuality: Bool = true

    /// 是否启用下一首无缝切歌预加载
    @AppStorage(AppConfig.StorageKeys.gaplessPlaybackEnabled)
    var gaplessPlaybackEnabled: Bool = false

    /// 后台音频策略
    @AppStorage(AppConfig.StorageKeys.backgroundAudioPolicy)
    var backgroundAudioPolicyRaw: String = BackgroundAudioPolicy.automatic.rawValue

    /// 后台音频策略（类型安全访问）
    var backgroundAudioPolicy: BackgroundAudioPolicy {
        get { BackgroundAudioPolicy(rawValue: backgroundAudioPolicyRaw) ?? .automatic }
        set { backgroundAudioPolicyRaw = newValue.rawValue }
    }

    // MARK: - 游戏模式

    /// 游戏模式开关（主开关）
    @AppStorage(AppConfig.StorageKeys.gameModeEnabled)
    var gameModeEnabled: Bool = false

    /// 游戏出枪声等提示时自动降低音乐音量
    @AppStorage(AppConfig.StorageKeys.gameModeAutoDucking)
    var gameModeAutoDucking: Bool = true

    /// 游戏模式下自动降低音质（节省 CPU/电量）
    @AppStorage(AppConfig.StorageKeys.gameModeLowerQuality)
    var gameModeLowerQuality: Bool = true

    /// 检测到游戏退出后自动关闭游戏模式
    @AppStorage(AppConfig.StorageKeys.gameModeAutoExit)
    var gameModeAutoExit: Bool = false

    /// 游戏模式下隐藏锁屏 / 灵动岛的播放信息
    @AppStorage(AppConfig.StorageKeys.gameModeDisableLiveActivity)
    var gameModeSilentNowPlaying: Bool = false

    /// 【实验性】当 `gameModeSilentNowPlaying` 为 true 时，是否保留最小锁屏信息（仅歌名，无封面 / 歌手 / 时间）
    /// - false（默认）→ 完全清空 NowPlayingInfo（iOS 把 App 从锁屏/灵动岛移除）
    /// - true → 保留「歌名」作为唯一 now playing 信息，不提供其他内容也不参与播放控制
    @AppStorage(AppConfig.StorageKeys.gameModeMinimalNowPlaying)
    var gameModeMinimalNowPlaying: Bool = false

    /// 游戏模式自动播放的本地歌单 ID（空字符串表示禁用）
    @AppStorage(AppConfig.StorageKeys.gameModeAutoPlaylistLocalId)
    var gameModeAutoPlaylistLocalId: String = ""

    /// 游戏模式首选音质（空字符串 = 使用"降音质"的默认行为，即 .standard）
    @AppStorage(AppConfig.StorageKeys.gameModePreferredQuality)
    var gameModePreferredQualityRaw: String = ""

    var gameModePreferredQuality: SoundQuality? {
        get { SoundQuality(rawValue: gameModePreferredQualityRaw) }
        set { gameModePreferredQualityRaw = newValue?.rawValue ?? "" }
    }

    /// 应用图标 / Logo 风格。Paw 是新安装默认图标；主 AppIcon 文件名保持不变。
    @AppStorage(AppConfig.StorageKeys.appBrandStyle)
    var appBrandStyleRaw: String = AppBrandStyle.paw.rawValue

    var appBrandStyle: AppBrandStyle {
        get { AppBrandStyle(rawValue: appBrandStyleRaw) ?? .paw }
        set { appBrandStyleRaw = newValue.rawValue }
    }

    @AppStorage(AppConfig.StorageKeys.appBrandAppearance)
    var appBrandAppearanceRaw: String = AppBrandAppearance.light.rawValue

    var appBrandAppearance: AppBrandAppearance {
        get { AppBrandAppearance(rawValue: appBrandAppearanceRaw) ?? .light }
        set { appBrandAppearanceRaw = newValue.rawValue }
    }

    /// 界面图标库风格
    @AppStorage(AppConfig.StorageKeys.interfaceIconSet)
    var interfaceIconSetRaw: String = AppInterfaceIconSet.hicon.rawValue

    var interfaceIconSet: AppInterfaceIconSet {
        get { AppInterfaceIconSet.selectedFromDefaults }
        set {
            setInterfaceIconSet(newValue, bumpRevision: true)
        }
    }

    var appLogoAssetName: String {
        appBrandStyle.logoAssetName(for: appBrandAppearance)
    }

    var supportsAlternateAppIcons: Bool {
        #if os(iOS)
            UIApplication.shared.supportsAlternateIcons
        #else
            false
        #endif
    }

    @AppStorage(AppConfig.StorageKeys.playlistSyncAutoEnabled)
    var playlistSyncAutoEnabled: Bool = true

    @AppStorage(AppConfig.StorageKeys.playlistSyncDeleteCloudSnapshot)
    var playlistSyncDeleteCloudSnapshot: Bool = false

    /// 默认播放音质
    @AppStorage("defaultPlaybackQuality") var defaultPlaybackQuality: String = "standard"

    /// qcm默认播放音质
    @AppStorage(AppConfig.StorageKeys.qqMusicQuality)
    var defaultQQPlaybackQuality: String = QQMusicQuality.mp3_320.rawValue

    /// QSM 默认播放音质
    @AppStorage("monologue_qishui_quality")
    var defaultQishuiPlaybackQuality: String = "highest"

    /// 全部播放时是否将整张列表插入当前播放队列
    @AppStorage(AppConfig.StorageKeys.insertPlaybackContext)
    var insertPlaybackContext: Bool = false

    /// 播客默认播放顺序（false：最新一期优先；true：最早一期优先）
    @AppStorage(AppConfig.StorageKeys.podcastSortAscending)
    var podcastSortAscending: Bool = false

    /// 默认下载音质
    @AppStorage("defaultDownloadQuality") var defaultDownloadQuality: String = "standard"

    // MARK: - 缓存设置

    /// 最大缓存大小 (MB)
    @AppStorage("maxCacheSize") var maxCacheSize: Int = 500

    // MARK: - 每日一言

    /// 每日一言开关
    @AppStorage("hitokotoEnabled") var hitokotoEnabled: Bool = true

    /// 每日一言类型 (a=动画 b=漫画 c=游戏 d=文学 e=原创 f=来自网络 g=其他 h=影视 i=诗词 j=ncm k=哲学 l=抖机灵)
    @AppStorage("hitokotoType") var hitokotoType: String = ""

    // MARK: - 其他设置

    /// 触感反馈
    @AppStorage("hapticFeedback") var hapticFeedback: Bool = true

    /// 喜欢同步到ncm（点喜欢时同时调用ncm API）
    @AppStorage("syncLikeToNetease") var syncLikeToNetease: Bool = true

    /// 喜欢时选择歌单（点喜欢新歌时弹出歌单选择器，而非直接加入「我喜欢」）
    @AppStorage("likeToChoosePlaylist") var likeToChoosePlaylist: Bool = false

    /// 边听边存（播放时自动下载保存）
    @AppStorage("listenAndSave") var listenAndSave: Bool = false

    /// QMC 解密开关（qcm加密流解密，默认关闭）
    @AppStorage("qmcDecryptEnabled") var qmcDecryptEnabled: Bool = false

    @AppStorage("useSystemTabBar") var useSystemTabBar: Bool = false

    // MARK: - 封面背景设置

    /// 全局动态封面背景（首页/资料库/搜索等跟随当前播放歌曲封面）
    @AppStorage("coverBgGlobal") var coverBgGlobal: Bool = false

    /// 歌单/专辑详情页封面模糊背景
    @AppStorage("coverBgPlaylist") var coverBgPlaylist: Bool = true

    /// 播放器封面模糊背景
    @AppStorage("coverBgPlayer") var coverBgPlayer: Bool = true

    /// 全局封面背景是否为深色（由亮度检测自动更新）
    @Published var globalCoverIsDark: Bool = false

    var locksCoverBackgroundSettings: Bool {
        globalThemeId != .default
    }

    // MARK: - 歌词设置

    /// 歌词颜色模式: "default" / "solid" / "gradient"
    @AppStorage("lyricColorMode") var lyricColorMode: String = "default"

    /// 纯色 hex
    @AppStorage("lyricSolidColorHex") var lyricSolidColorHex: String = "007AFF"

    /// 渐变起始色 hex
    @AppStorage("lyricGradientStartHex") var lyricGradientStartHex: String = "FF6B6B"

    /// 渐变结束色 hex
    @AppStorage("lyricGradientEndHex") var lyricGradientEndHex: String = "4ECDC4"

    private init() {
        let storedRaw = UserDefaults.standard.string(forKey: GlobalThemeId.storageKey)
        let restored = GlobalThemeId.resolvedStoredTheme(storedRaw ?? globalThemeIdRaw)
        let resolved = Self.resolveRemovedTheme(restored)
        let hasStoredInterfaceIconSet = UserDefaults.standard.object(forKey: AppConfig.StorageKeys.interfaceIconSet) != nil

        if storedRaw == nil || resolved.rawValue != globalThemeIdRaw {
            UserDefaults.standard.set(resolved.rawValue, forKey: GlobalThemeId.storageKey)
            globalThemeIdRaw = resolved.rawValue
        }

        AppLogger.info("[ThemeInit] persistedThemeId=\(storedRaw ?? "nil") appDefault=\(GlobalThemeId.appDefault.rawValue) finalThemeId=\(resolved.rawValue) hasStoredIconSet=\(hasStoredInterfaceIconSet)")
        applyGlobalThemeSelection(
            resolved,
            bumpRevision: false,
            bumpApplicationRevision: false,
            applyPreferredIconSet: !hasStoredInterfaceIconSet
        )
        enforceCoverBackgroundPolicyForCurrentTheme()
        // 启动时应用一次主题
        applyTheme()
    }

    private func applyGlobalThemeSelection(
        _ themeId: GlobalThemeId,
        bumpRevision: Bool,
        bumpApplicationRevision: Bool,
        applyPreferredIconSet: Bool
    ) {
        let previousThemeId = GlobalThemeManager.shared.currentThemeId

        if globalThemeIdRaw != themeId.rawValue {
            globalThemeIdRaw = themeId.rawValue
        }
        UserDefaults.standard.set(themeId.rawValue, forKey: GlobalThemeId.storageKey)

        GlobalThemeManager.shared.switchTheme(to: themeId)
        if previousThemeId == themeId, bumpRevision {
            GlobalThemeManager.shared.refreshCurrentThemeTokens()
        }
        let iconSetChanged = applyPreferredIconSet
            ? applyPreferredInterfaceIconSet(for: themeId)
            : false
        enforceCoverBackgroundPolicyForCurrentTheme()

        if bumpApplicationRevision {
            globalThemeApplicationRevision &+= 1
        }
        if bumpRevision || iconSetChanged {
            globalThemeRevision &+= 1
        }
        AppLogger.info("[ApplyTheme] themeId=\(themeId.rawValue) savedThemeId=\(UserDefaults.standard.string(forKey: GlobalThemeId.storageKey) ?? "nil") previousManagerThemeId=\(previousThemeId.rawValue) bumpRevision=\(bumpRevision) appRevision=\(globalThemeApplicationRevision) applyPreferredIconSet=\(applyPreferredIconSet) revision=\(globalThemeRevision)")
    }

    @discardableResult
    private func applyPreferredInterfaceIconSet(for themeId: GlobalThemeId) -> Bool {
        setInterfaceIconSet(themeId.preferredInterfaceIconSet, bumpRevision: false)
    }

    @discardableResult
    private func setInterfaceIconSet(_ iconSet: AppInterfaceIconSet, bumpRevision: Bool) -> Bool {
        let storedRaw = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.interfaceIconSet)
        guard storedRaw != iconSet.rawValue else { return false }

        objectWillChange.send()
        interfaceIconSetRaw = iconSet.rawValue

        if bumpRevision {
            globalThemeRevision &+= 1
        }

        return true
    }

    func enforceCoverBackgroundPolicyForCurrentTheme() {
        guard locksCoverBackgroundSettings else { return }
        coverBgGlobal = false
        coverBgPlaylist = false
        coverBgPlayer = false
        globalCoverIsDark = false
    }

    func notifyThemeCustomizationChanged() {
        GlobalThemeManager.shared.refreshCurrentThemeTokens()
        globalThemeRevision &+= 1
    }

    func selectAppBrandStyle(_ style: AppBrandStyle) async {
        guard appBrandStyle != style else { return }

        appBrandStyle = style
        await applySelectedAlternateIcon()
    }

    func selectAppBrandAppearance(_ appearance: AppBrandAppearance) async {
        guard appBrandAppearance != appearance else { return }

        appBrandAppearance = appearance
        await applySelectedAlternateIcon()
    }

    private func applySelectedAlternateIcon() async {
        #if os(iOS)
            guard UIApplication.shared.supportsAlternateIcons else {
                AppLogger.info("[AppBrand] 当前环境不支持桌面图标切换，仅更新应用内 Logo")
                return
            }

            let iconName = appBrandStyle.alternateIconName(for: appBrandAppearance)
            guard UIApplication.shared.alternateIconName != iconName else { return }

            do {
                try await setAlternateIconName(iconName)
                AppLogger.info("[AppBrand] 已切换图标风格: \(appBrandStyle.rawValue)-\(appBrandAppearance.rawValue)")
            } catch {
                AppLogger.warning("[AppBrand] 图标切换失败: \(error.localizedDescription)")
            }
        #endif
    }

    #if os(iOS)
        private func setAlternateIconName(_ iconName: String?) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                UIApplication.shared.setAlternateIconName(iconName) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    #endif
}
