// AudioLabManager.swift
// AsideMusic
//
// 音频实验室管理器 - 模型定义、核心属性和初始化
// 功能实现分布在以下扩展文件中：
//   AudioLabManager+Analysis.swift         - 分析入口（analyzeCurrentSong, 下载分析）
//   AudioLabManager+FileAnalysis.swift     - 文件分析（SDK AudioAnalyzer）
//   AudioLabManager+RealtimeAnalysis.swift - 实时频谱分析（回退方案）
//   AudioLabManager+Application.swift      - 应用推荐设置、重置、EQ 预设

import Foundation
import Combine
import FFmpegSwiftSDK
import NeteaseCloudMusicAPI

// MARK: - 数据模型

/// 音频分析结果（基于 SDK 的 AudioAnalyzer 完整分析）
struct AudioAnalysisResult {
    let bpm: Float
    let bpmConfidence: Float
    let loudness: Float
    let dynamicRange: Float
    let spectralCentroid: Float
    let lowFrequencyRatio: Float
    let midFrequencyRatio: Float
    let highFrequencyRatio: Float
    let suggestedGenre: SuggestedGenre
    let recommendedPresetId: String
    let recommendedEffects: RecommendedEffects
    let timbreAnalysis: TimbreInfo?
    let qualityAssessment: QualityInfo?
}

/// 音色信息
struct TimbreInfo {
    let brightness: Float
    let warmth: Float
    let clarity: Float
    let fullness: Float
    let description: String
    let eqSuggestion: String
}

/// 质量信息
struct QualityInfo {
    let overallScore: Int
    let dynamicScore: Int
    let frequencyScore: Int
    let grade: String
    let issues: [String]
}

/// 推荐的音乐类型
enum SuggestedGenre: String {
    case pop = "流行"
    case rock = "摇滚"
    case electronic = "电子"
    case hiphop = "嘻哈"
    case classical = "古典"
    case jazz = "爵士"
    case rnb = "R&B"
    case acoustic = "民谣"
    case vocal = "人声"
    case metal = "金属"
    case unknown = "未知"
}

/// 推荐的音效参数
struct RecommendedEffects {
    let bassGain: Float
    let trebleGain: Float
    let surroundLevel: Float
    let reverbLevel: Float
    let stereoWidth: Float
    let loudnormEnabled: Bool
    let eqGains: [Float]
    
    // 新增滤镜参数（v1.1.9）
    let fftDenoiseEnabled: Bool
    let fftDenoiseAmount: Float
    let declickEnabled: Bool
    let declipEnabled: Bool
    let dynaudnormEnabled: Bool
    let speechnormEnabled: Bool
    let compandEnabled: Bool
    let bs2bEnabled: Bool
    let crossfeedEnabled: Bool
    let crossfeedStrength: Float
    let haasEnabled: Bool
    let haasDelay: Float
    let virtualbassEnabled: Bool
    let virtualbassCutoff: Float
    let virtualbassStrength: Float
    let exciterEnabled: Bool
    let exciterAmount: Float
    let exciterFreq: Float
    let softclipEnabled: Bool
    let softclipType: Int
    let dialogueEnhanceEnabled: Bool
    
    /// 默认值（所有新滤镜关闭）
    static func defaultNewFilters(
        bassGain: Float, trebleGain: Float,
        surroundLevel: Float, reverbLevel: Float,
        stereoWidth: Float, loudnormEnabled: Bool,
        eqGains: [Float]
    ) -> RecommendedEffects {
        return RecommendedEffects(
            bassGain: bassGain, trebleGain: trebleGain,
            surroundLevel: surroundLevel, reverbLevel: reverbLevel,
            stereoWidth: stereoWidth, loudnormEnabled: loudnormEnabled,
            eqGains: eqGains,
            fftDenoiseEnabled: false, fftDenoiseAmount: 10,
            declickEnabled: false, declipEnabled: false,
            dynaudnormEnabled: false, speechnormEnabled: false, compandEnabled: false,
            bs2bEnabled: false, crossfeedEnabled: false, crossfeedStrength: 0.3,
            haasEnabled: false, haasDelay: 20,
            virtualbassEnabled: false, virtualbassCutoff: 250, virtualbassStrength: 3.0,
            exciterEnabled: false, exciterAmount: 3.0, exciterFreq: 7500,
            softclipEnabled: false, softclipType: 0,
            dialogueEnhanceEnabled: false
        )
    }
}

// MARK: - AudioLabManager 核心

@MainActor
class AudioLabManager: ObservableObject {
    static let shared = AudioLabManager()
    
    // MARK: - Published
    
    /// 是否启用智能音效
    @Published var isSmartEffectsEnabled: Bool = false {
        didSet {
            saveState()
            if !isSmartEffectsEnabled {
                resetToManualMode()
            }
        }
    }
    
    /// 当前分析结果
    @Published var currentAnalysis: AudioAnalysisResult?
    
    /// 是否正在分析
    @Published var isAnalyzing: Bool = false
    
    /// 分析进度（0~1）
    @Published var analysisProgress: Float = 0
    
    /// 上次分析的歌曲 ID
    @Published var lastAnalyzedSongId: Int?
    
    /// 分析结果缓存（歌曲 ID -> 分析结果）— 内存缓存
    var analysisCache: [Int: AudioAnalysisResult] = [:]
    
    /// 分析结果持久化 key 前缀
    let analysisCachePrefix = "audio_analysis_"
    
    /// 最大缓存分析结果数量
    let maxAnalysisCacheCount = 100
    
    /// 分析模式
    enum AnalysisMode: String, CaseIterable {
        case realtime = "实时"
        case file = "文件"
    }
    
    @Published var analysisMode: AnalysisMode = .file
    
    // MARK: - Private
    
    var cancellables = Set<AnyCancellable>()
    
    /// 分析错误类型
    enum AnalysisError: LocalizedError {
        case invalidUrl
        case urlNotAvailable
        case downloadFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidUrl: return "无效的歌曲 URL"
            case .urlNotAvailable: return "无法获取歌曲播放地址"
            case .downloadFailed: return "下载音频文件失败"
            }
        }
    }
    
    private init() {
        restoreStateFromDefaults()
        setupObservers()
    }

    // MARK: - 监听播放状态
    
    private func setupObservers() {
        // 监听歌曲切换，自动分析新歌曲
        PlayerManager.shared.$currentSong
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] song in
                guard let self = self, self.isSmartEffectsEnabled, let song = song else { return }
                if self.lastAnalyzedSongId != song.id {
                    Task {
                        await self.analyzeCurrentSong()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 监听歌曲播放完毕，重置 EQ
        PlayerManager.shared.$currentSong
            .dropFirst()
            .sink { [weak self] song in
                guard let self = self else { return }
                if song == nil && self.isSmartEffectsEnabled {
                    self.currentAnalysis = nil
                    self.lastAnalyzedSongId = nil
                    self.resetEQToDefault()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 持久化
    
    func saveState() {
        UserDefaults.standard.set(isSmartEffectsEnabled, forKey: AppConfig.StorageKeys.audioLabSmartEffects)
        UserDefaults.standard.set(analysisMode.rawValue, forKey: AppConfig.StorageKeys.audioLabAnalysisMode)
    }
    
    private func restoreStateFromDefaults() {
        isSmartEffectsEnabled = UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.audioLabSmartEffects)
        if let modeRaw = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.audioLabAnalysisMode),
           let mode = AnalysisMode(rawValue: modeRaw) {
            analysisMode = mode
        }
    }
}
