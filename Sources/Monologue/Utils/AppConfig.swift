import Foundation

/// 应用配置常量
/// 集中管理所有硬编码值，便于维护和调整
enum AppConfig {
    
    // MARK: - 缓存配置
    enum Cache {
        /// 内存缓存限制 (100MB)
        static let memoryLimit = 100 * 1024 * 1024
        /// 磁盘缓存限制 (500MB)
        static let diskLimit = 500 * 1024 * 1024
        /// 默认缓存过期时间 (7天)
        static let defaultTTL: TimeInterval = 60 * 60 * 24 * 7
        /// 图片缓存过期时间 (30天)
        static let imageTTL: TimeInterval = 60 * 60 * 24 * 30
    }
    
    // MARK: - API 配置
    enum API {
        /// 默认分页大小
        static let defaultPageSize = 30
        /// 最大重试次数
        static let maxRetries = 3
        /// 请求超时时间 (秒)
        static let requestTimeout: TimeInterval = 30
    }
    
    // MARK: - 播放器配置
    enum Player {
        /// 时间观察器更新间隔 (秒)
        static let timeObserverInterval: Double = 0.05
        /// 初始重试延迟 (秒)
        static let initialRetryDelay: TimeInterval = 1.0
        /// 最大重试延迟 (秒)
        static let maxRetryDelay: TimeInterval = 10.0
        /// 播放历史最大数量
        static let maxHistoryCount = 50
        /// 状态保存防抖间隔 (秒)
        static let saveStateDebounceInterval: TimeInterval = 2.0
        /// 播放进度心跳持久化间隔 (秒)
        static let playbackProgressPersistenceInterval: TimeInterval = 5.0
    }
    
    // MARK: - UI 配置
    enum UI {
        /// 搜索防抖延迟 (毫秒)
        static let searchDebounceMs = 300
        /// 动画弹簧响应时间
        static let springResponse: Double = 0.3
        /// 动画弹簧阻尼
        static let springDamping: Double = 0.7
        /// 按钮缩放比例
        static let buttonScaleDefault: CGFloat = 0.95
        /// 卡片缩放比例
        static let cardScaleDefault: CGFloat = 0.98
    }
    
    // MARK: - 存储键
    enum StorageKeys {
        static let cookie = "monologue_music_cookie"
        static let userId = "monologue_music_uid"
        static let soundQuality = "monologue_sound_quality"
        static let playerState = "player_state_v3"
        static let playerStateSnapshot = "player_state_snapshot_v1"
        static let playerTheme = "playerTheme"
        static let lastDailyRefresh = "last_daily_refresh_date"
        static let lastPodcastDailyRefresh = "last_podcast_daily_refresh_date"
        static let lastFullSync = "last_full_sync_time"
        static let isLoggedIn = "isLoggedIn"
        static let pitchSemitones = "monologue_pitch_semitones"
        static let preferHighestPlaybackQuality = "monologue_prefer_highest_playback_quality"
        static let gaplessPlaybackEnabled = "monologue_gapless_playback_enabled"
        static let backgroundAudioPolicy = "monologue_background_audio_policy"
        static let appBrandStyle = "monologue_app_brand_style"
        static let appBrandAppearance = "monologue_app_brand_appearance"
        static let interfaceIconSet = "monologue_interface_icon_set"
        static let playlistSyncDeviceId = "monologue_playlist_sync_device_id"
        static let playlistSyncLastSyncedAt = "monologue_playlist_sync_last_synced_at"
        static let playlistSyncLastMessage = "monologue_playlist_sync_last_message"
        static let playlistSyncLastRemoteRevision = "monologue_playlist_sync_last_remote_revision"
        static let playlistSyncLastTokenFingerprint = "monologue_playlist_sync_last_token_fingerprint"
        static let playlistSyncAutoEnabled = "monologue_playlist_sync_auto_enabled"
        static let playlistSyncDeleteCloudSnapshot = "monologue_playlist_sync_delete_cloud_snapshot"
        static let defaultPlaybackQuality = "defaultPlaybackQuality"
        static let insertPlaybackContext = "monologue_insert_playback_context"
        static let podcastSortAscending = "monologue_podcast_sort_ascending"

        // MARK: - 游戏模式
        static let gameModeEnabled = "monologue_game_mode_enabled"
        static let gameModeAutoDucking = "monologue_game_mode_auto_ducking"
        static let gameModeLowerQuality = "monologue_game_mode_lower_quality"
        static let gameModeDisableLiveActivity = "monologue_game_mode_disable_live_activity"
        static let gameModeAutoPlaylistLocalId = "monologue_game_mode_auto_playlist_local_id"
        static let gameModePreferredQuality = "monologue_game_mode_preferred_quality"
        static let gameModeAutoExit = "monologue_game_mode_auto_exit"
        static let gameModeSavedBackgroundPolicy = "monologue_game_mode_saved_background_policy"
        static let gameModeSavedSoundQuality = "monologue_game_mode_saved_sound_quality"
        /// 标记「进入游戏模式时是否替换了用户的 backgroundAudioPolicy」
        /// 只有为 true 时退出游戏模式才会尝试恢复；否则保持现状，避免把用户原本就是 alwaysMix 的偏好改掉。
        static let gameModeSavedPolicyWasManaged = "monologue_game_mode_saved_policy_was_managed"
        /// 标记「进入游戏模式时是否替换了音质」，与上同逻辑
        static let gameModeSavedQualityWasManaged = "monologue_game_mode_saved_quality_was_managed"
        /// 上次应用的游戏模式场景预设 rawValue（用于 UI 高亮）
        static let gameModeLastScenarioPreset = "monologue_game_mode_last_scenario_preset"
        /// 【实验性】游戏模式下隐藏锁屏信息时，是否保留最小锁屏信息（仅歌名）
        static let gameModeMinimalNowPlaying = "monologue_game_mode_minimal_now_playing"
        // [DEPRECATED] 智能分析功能已废弃
        static let audioLabSmartEffects = "audio_lab_smart_effects_enabled"
        static let audioLabAnalysisMode = "audio_lab_analysis_mode"
        
        // 缓存同步相关
        static let dailyCacheTimestamp = "daily_cache_timestamp"
        static let lastSyncTimestamp = "last_sync_timestamp"
        static let syncInterval = "sync_interval_timestamp"
        
        // 风格偏好
        static let selectedStylePreference = "selected_style_preference"
        
        // qcm相关
        static let qqMusicBaseURL = "qq_music_base_url"
        static let qqMusicEnabled = "qq_music_enabled"
        static let qqMusicLoggedIn = "qq_music_logged_in"
        static let qqMusicQuality = "monologue_qq_music_quality"
        
        /// 生成带时间戳的缓存键
        static func timestampKey(for key: String) -> String {
            return "\(key)_timestamp"
        }
    }

    
    // MARK: - 缓存键前缀
    enum CacheKeys {
        static let api = "api_"
        static let dailySongs = "daily_songs"
        static let popularSongs = "popular_songs"
        static let recommendPlaylists = "recommend_playlists"
        static let recentSongs = "recent_songs"
        static let banners = "banners"
        static let userProfile = "user_profile_detail"
        static let userPlaylists = "user_playlists"
        static let playlistCategories = "playlist_categories"
        static let topCharts = "top_charts_lists"
    }
}
