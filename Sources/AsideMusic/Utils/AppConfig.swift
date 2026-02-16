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
        /// 最大连续失败次数（超过后停止自动播放下一首）
        static let maxConsecutiveFailures = 3
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
        static let cookie = "aside_music_cookie"
        static let userId = "aside_music_uid"
        static let soundQuality = "aside_sound_quality"
        static let kugouQuality = "aside_kugou_quality"
        static let playerState = "player_state_v3"
        static let playerTheme = "playerTheme"
        static let lastDailyRefresh = "last_daily_refresh_date"
        static let lastFullSync = "last_full_sync_time"
        static let isLoggedIn = "isLoggedIn"
        static let pitchSemitones = "aside_pitch_semitones"
        static let defaultPlaybackQuality = "defaultPlaybackQuality"
        static let audioLabSmartEffects = "audio_lab_smart_effects_enabled"
        static let audioLabAnalysisMode = "audio_lab_analysis_mode"
        
        // 缓存同步相关
        static let dailyCacheTimestamp = "daily_cache_timestamp"
        static let lastSyncTimestamp = "last_sync_timestamp"
        static let syncInterval = "sync_interval_timestamp"
        
        // 风格偏好
        static let selectedStylePreference = "selected_style_preference"
        
        // QQ 音乐相关
        static let qqMusicBaseURL = "qq_music_base_url"
        static let qqMusicEnabled = "qq_music_enabled"
        static let qqMusicLoggedIn = "qq_music_logged_in"
        static let qqMusicQuality = "aside_qq_music_quality"
        
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
