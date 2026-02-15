// AudioLabManager.swift
// AsideMusic
//
// 音频实验室管理器 - 基于音频分析自动优化音效参数
// 使用 FFmpegSwiftSDK 的 AudioAnalyzer 进行专业级音频分析，智能推荐最佳 EQ 和音效设置

import Foundation
import Combine
import FFmpegSwiftSDK
import NeteaseCloudMusicAPI

/// 音频分析结果（基于 SDK 的 AudioAnalyzer 完整分析）
struct AudioAnalysisResult {
    /// BPM（节拍速度）
    let bpm: Float
    /// BPM 置信度
    let bpmConfidence: Float
    /// 响度（LUFS）
    let loudness: Float
    /// 动态范围（dB）
    let dynamicRange: Float
    /// 频谱质心（Hz）- 音色亮度指标
    let spectralCentroid: Float
    /// 低频能量占比（0~1）
    let lowFrequencyRatio: Float
    /// 中频能量占比（0~1）
    let midFrequencyRatio: Float
    /// 高频能量占比（0~1）
    let highFrequencyRatio: Float
    /// 推荐的音乐类型
    let suggestedGenre: SuggestedGenre
    /// 推荐的 EQ 预设 ID
    let recommendedPresetId: String
    /// 推荐的音效参数
    let recommendedEffects: RecommendedEffects
    /// 音色分析
    let timbreAnalysis: TimbreInfo?
    /// 质量评估
    let qualityAssessment: QualityInfo?
}

/// 音色信息
struct TimbreInfo {
    let brightness: Float    // 亮度
    let warmth: Float        // 温暖度
    let clarity: Float       // 清晰度
    let fullness: Float      // 丰满度
    let description: String  // 音色描述
    let eqSuggestion: String // EQ 建议
}

/// 质量信息
struct QualityInfo {
    let overallScore: Int    // 总体评分
    let dynamicScore: Int    // 动态评分
    let frequencyScore: Int  // 频率平衡评分
    let grade: String        // 质量等级
    let issues: [String]     // 问题列表
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
    let bassGain: Float      // 低音增益 (-12~+12)
    let trebleGain: Float    // 高音增益 (-12~+12)
    let surroundLevel: Float // 环绕强度 (0~1)
    let reverbLevel: Float   // 混响强度 (0~1)
    let stereoWidth: Float   // 立体声宽度 (0~2)
    let loudnormEnabled: Bool // 是否启用响度标准化
    /// 智能生成的 10 段 EQ 增益
    let eqGains: [Float]     // 31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
    
    // ═══════════════════════════════════════
    // 新增滤镜参数（v1.1.9）
    // ═══════════════════════════════════════
    
    // 音频修复
    let fftDenoiseEnabled: Bool      // FFT 降噪
    let fftDenoiseAmount: Float      // 降噪量 (0~100)
    let declickEnabled: Bool         // 去脉冲噪声
    let declipEnabled: Bool          // 去削波失真
    
    // 动态处理
    let dynaudnormEnabled: Bool      // 动态标准化（实时友好）
    let speechnormEnabled: Bool      // 语音标准化
    let compandEnabled: Bool         // 压缩/扩展
    
    // 空间音效
    let bs2bEnabled: Bool            // Bauer 立体声转双耳（耳机优化）
    let crossfeedEnabled: Bool       // 耳机交叉馈送
    let crossfeedStrength: Float     // 交叉馈送强度 (0~1)
    let haasEnabled: Bool            // Haas 效果（空间感）
    let haasDelay: Float             // Haas 延迟 (0~40ms)
    let virtualbassEnabled: Bool     // 虚拟低音
    let virtualbassCutoff: Float     // 虚拟低音截止频率
    let virtualbassStrength: Float   // 虚拟低音强度
    
    // 音色处理
    let exciterEnabled: Bool         // 激励器（高频泛音）
    let exciterAmount: Float         // 激励量 (dB)
    let exciterFreq: Float           // 激励起始频率
    let softclipEnabled: Bool        // 软削波（温暖失真）
    let softclipType: Int            // 软削波类型 (0~7)
    let dialogueEnhanceEnabled: Bool // 对话增强
    
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
    
    /// 分析结果缓存（歌曲 ID -> 分析结果）
    private var analysisCache: [Int: AudioAnalysisResult] = [:]
    
    /// 分析模式
    enum AnalysisMode: String, CaseIterable {
        case realtime = "实时"      // 使用频谱分析器（快速但不太准确）
        case file = "文件"          // 使用 AudioAnalyzer.analyzeFile（准确但需要时间）
    }
    
    @Published var analysisMode: AnalysisMode = .file
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        restoreState()
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
        
        // 监听歌曲播放完毕（currentSong 变为 nil），重置 EQ
        PlayerManager.shared.$currentSong
            .dropFirst()
            .sink { [weak self] song in
                guard let self = self else { return }
                // 当歌曲变为 nil（播放完毕或停止）且智能音效开启时，重置 EQ
                if song == nil && self.isSmartEffectsEnabled {
                    self.currentAnalysis = nil
                    self.lastAnalyzedSongId = nil
                    self.resetEQToDefault()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 音频分析（使用 SDK 的 AudioAnalyzer）
    
    /// 分析当前播放的歌曲（只分析，不自动应用）
    func analyzeCurrentSong() async {
        guard let song = PlayerManager.shared.currentSong else { return }
        guard !isAnalyzing else { return }
        
        // 检查缓存（同一首歌不重复分析）
        if let cached = analysisCache[song.id] {
            currentAnalysis = cached
            lastAnalyzedSongId = song.id
            AppLogger.info("使用缓存的分析结果: \(song.name)")
            return
        }
        
        isAnalyzing = true
        analysisProgress = 0
        
        do {
            let analysis: AudioAnalysisResult
            
            if analysisMode == .file {
                // 文件分析模式：下载歌曲源文件进行分析
                analysis = try await analyzeByDownloading(song: song)
            } else {
                // 回退到实时频谱分析（快速但不太准确）
                let spectrumData = try await collectSpectrumData()
                guard !spectrumData.isEmpty else {
                    isAnalyzing = false
                    return
                }
                analysis = analyzeFromSpectrum(spectrumData: spectrumData)
            }
            
            // 缓存结果
            analysisCache[song.id] = analysis
            
            // 限制缓存大小（最多保留 50 首歌的分析结果）
            if analysisCache.count > 50 {
                // 移除最早的缓存
                if let firstKey = analysisCache.keys.first {
                    analysisCache.removeValue(forKey: firstKey)
                }
            }
            
            // 更新结果（不自动应用，等用户手动点击）
            currentAnalysis = analysis
            lastAnalyzedSongId = song.id
            
            analysisProgress = 1.0
            try? await Task.sleep(nanoseconds: 500_000_000)
            analysisProgress = 0
            
        } catch {
            AppLogger.error("音频分析失败: \(error)")
        }
        
        isAnalyzing = false
    }
    
    // MARK: - 下载并分析
    
    /// 下载歌曲源文件进行分析，分析完成后自动删除临时文件
    private func analyzeByDownloading(song: Song) async throws -> AudioAnalysisResult {
        AppLogger.info("开始下载歌曲进行分析: \(song.name)")
        
        // 1. 获取歌曲 URL
        let songUrl = try await fetchSongUrlAsync(songId: song.id)
        guard let url = URL(string: songUrl) else {
            throw AnalysisError.invalidUrl
        }
        
        analysisProgress = 0.1
        
        // 2. 下载到临时目录
        let tempFileURL = try await downloadToTemp(url: url, songId: song.id)
        
        analysisProgress = 0.4
        
        // 3. 分析文件
        defer {
            // 分析完成后自动删除临时文件
            cleanupTempFile(tempFileURL)
        }
        
        let analysis = try await analyzeFromFile(url: tempFileURL.path)
        
        return analysis
    }
    
    /// 异步获取歌曲 URL
    private func fetchSongUrlAsync(songId: Int) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.fetchSongUrl(id: songId, level: "exhigh")
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                }, receiveValue: { result in
                    if result.url.isEmpty {
                        continuation.resume(throwing: AnalysisError.urlNotAvailable)
                    } else {
                        continuation.resume(returning: result.url)
                    }
                })
        }
    }
    
    /// 下载文件到临时目录
    private func downloadToTemp(url: URL, songId: Int) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("analysis_\(songId)_\(UUID().uuidString).tmp")
        
        AppLogger.info("下载音频文件到临时目录: \(tempFileURL.lastPathComponent)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AnalysisError.downloadFailed
        }
        
        try data.write(to: tempFileURL)
        
        let fileSize = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        AppLogger.info("音频文件下载完成: \(fileSize)")
        
        return tempFileURL
    }
    
    /// 清理临时文件
    private func cleanupTempFile(_ url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                AppLogger.info("已删除分析临时文件: \(url.lastPathComponent)")
            }
        } catch {
            AppLogger.warning("删除临时文件失败: \(error.localizedDescription)")
        }
    }
    
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
    
    /// 强制重新分析（忽略缓存）
    func forceReanalyze() async {
        guard let song = PlayerManager.shared.currentSong else { return }
        // 清除该歌曲的缓存
        analysisCache.removeValue(forKey: song.id)
        lastAnalyzedSongId = nil
        await analyzeCurrentSong()
    }

    // MARK: - 文件分析（使用 SDK 的 AudioAnalyzer.analyzeFile）
    
    /// 从音频文件进行完整分析
    private func analyzeFromFile(url: String) async throws -> AudioAnalysisResult {
        AppLogger.info("开始文件分析: \(url)")
        
        // 使用 SDK 的 AudioAnalyzer 进行完整分析
        // 分析前 60 秒以获得更准确的结果
        let sdkResult = try await AudioAnalyzer.analyzeFile(
            url: url,
            maxDuration: 60,
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    // 分析阶段占 0.4~0.9 的进度（下载已占 0~0.4）
                    self?.analysisProgress = 0.4 + progress * 0.45
                }
            }
        )
        
        analysisProgress = 0.9
        
        // 转换 SDK 结果为我们的格式
        let genre = inferGenreFromSDKResult(sdkResult)
        let timbre = convertTimbreAnalysis(sdkResult.timbre)
        let quality = convertQualityAssessment(sdkResult)
        
        analysisProgress = 0.92
        
        // 生成推荐设置
        let recommendedEffects = generateRecommendedEffectsFromSDK(
            sdkResult: sdkResult,
            genre: genre
        )
        
        analysisProgress = 0.95
        
        return AudioAnalysisResult(
            bpm: sdkResult.bpm.bpm,
            bpmConfidence: sdkResult.bpm.confidence,
            loudness: sdkResult.loudness.integratedLUFS,
            dynamicRange: Float(sdkResult.dynamicRange.drValue),
            spectralCentroid: sdkResult.frequency.spectralCentroid,
            lowFrequencyRatio: sdkResult.frequency.lowEnergyRatio,
            midFrequencyRatio: sdkResult.frequency.midEnergyRatio,
            highFrequencyRatio: sdkResult.frequency.highEnergyRatio,
            suggestedGenre: genre,
            recommendedPresetId: getRecommendedPreset(for: genre),
            recommendedEffects: recommendedEffects,
            timbreAnalysis: timbre,
            qualityAssessment: quality
        )
    }

    /// 从 SDK 分析结果推断音乐类型
    private func inferGenreFromSDKResult(_ result: AudioAnalyzer.FullAnalysisResult) -> SuggestedGenre {
        let bpm = result.bpm.bpm
        let freq = result.frequency
        let dynamic = result.dynamicRange
        
        // 高低频能量，中频凹陷 → 电子/嘻哈
        if freq.lowEnergyRatio > 0.4 && freq.midEnergyRatio < 0.35 {
            return bpm > 120 ? .electronic : .hiphop
        }
        
        // 中频突出 → 人声/民谣
        if freq.midEnergyRatio > 0.45 {
            return freq.spectralCentroid > 2000 ? .vocal : .acoustic
        }
        
        // 高频突出 + 大动态范围 → 古典/爵士
        if freq.highEnergyRatio > 0.35 && dynamic.drValue >= 10 {
            return freq.spectralCentroid > 3000 ? .classical : .jazz
        }
        
        // 高 BPM + 低频重 → 金属/摇滚
        if bpm > 130 && freq.lowEnergyRatio > 0.35 {
            return dynamic.drValue < 8 ? .metal : .rock
        }
        
        // 均衡分布 → 流行/摇滚
        if bpm > 110 {
            return freq.lowEnergyRatio > 0.35 ? .rock : .pop
        }
        
        // 低频突出，慢节奏 → R&B
        if freq.lowEnergyRatio > 0.35 && bpm < 100 {
            return .rnb
        }
        
        return .pop
    }
    
    /// 转换 SDK 的音色分析结果
    private func convertTimbreAnalysis(_ sdkTimbre: AudioAnalyzer.TimbreAnalysis) -> TimbreInfo {
        return TimbreInfo(
            brightness: sdkTimbre.brightness,
            warmth: sdkTimbre.warmth,
            clarity: sdkTimbre.clarity,
            fullness: sdkTimbre.fullness,
            description: sdkTimbre.description,
            eqSuggestion: sdkTimbre.eqSuggestion
        )
    }
    
    /// 转换 SDK 的质量评估结果
    private func convertQualityAssessment(_ sdkResult: AudioAnalyzer.FullAnalysisResult) -> QualityInfo {
        let dynamic = sdkResult.dynamicRange
        let clipping = sdkResult.clipping
        
        var issues: [String] = []
        var dynamicScore = 100
        var frequencyScore = 100
        
        // 动态范围评估
        if dynamic.drValue < 6 {
            dynamicScore -= 40
            issues.append("动态范围过窄（DR\(dynamic.drValue)）")
        } else if dynamic.drValue < 10 {
            dynamicScore -= 20
        }
        
        // 削波检测
        if clipping.hasSevereClipping {
            dynamicScore -= 30
            issues.append("存在严重削波")
        }
        
        // 频率平衡评估
        let freq = sdkResult.frequency
        if freq.lowEnergyRatio > 0.6 {
            frequencyScore -= 20
            issues.append("低频过重")
        } else if freq.lowEnergyRatio < 0.1 {
            frequencyScore -= 15
            issues.append("低频不足")
        }
        
        if freq.highEnergyRatio > 0.5 {
            frequencyScore -= 15
            issues.append("高频过亮")
        }
        
        let overallScore = (dynamicScore + frequencyScore) / 2
        let grade: String
        if overallScore >= 90 { grade = "优秀" }
        else if overallScore >= 75 { grade = "良好" }
        else if overallScore >= 60 { grade = "一般" }
        else { grade = "较差" }
        
        return QualityInfo(
            overallScore: overallScore,
            dynamicScore: dynamicScore,
            frequencyScore: frequencyScore,
            grade: grade,
            issues: issues
        )
    }

    /// 基于 SDK 完整分析结果生成推荐音效参数
    private func generateRecommendedEffectsFromSDK(
        sdkResult: AudioAnalyzer.FullAnalysisResult,
        genre: SuggestedGenre
    ) -> RecommendedEffects {
        let freq = sdkResult.frequency
        let timbre = sdkResult.timbre
        let dynamic = sdkResult.dynamicRange
        let loudness = sdkResult.loudness
        
        // ═══════════════════════════════════════
        // 智能 EQ 生成算法（基于完整频率分析）
        // ═══════════════════════════════════════
        
        var eqGains: [Float] = Array(repeating: 0, count: 10)
        // 频段: 31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
        
        // 理想分布：低频 30%，中频 40%，高频 30%
        let idealLow: Float = 0.30
        let idealMid: Float = 0.40
        let idealHigh: Float = 0.30
        
        let lowDiff = idealLow - freq.lowEnergyRatio
        let midDiff = idealMid - freq.midEnergyRatio
        let highDiff = idealHigh - freq.highEnergyRatio
        
        // 低频段调整（基于实际频率分析）
        let lowBoost = lowDiff * 18  // 更精确的补偿
        eqGains[0] = clampGain(lowBoost * 0.7)   // 31Hz - 次低频
        eqGains[1] = clampGain(lowBoost * 1.0)   // 62Hz - 低频核心
        eqGains[2] = clampGain(lowBoost * 0.85)  // 125Hz - 低频上段
        eqGains[3] = clampGain(lowBoost * 0.3 + midDiff * 0.4)  // 250Hz - 过渡区
        
        // 中频段调整
        let midBoost = midDiff * 14
        eqGains[4] = clampGain(midBoost * 0.6)   // 500Hz - 中低频
        eqGains[5] = clampGain(midBoost * 1.0)   // 1kHz - 中频核心
        eqGains[6] = clampGain(midBoost * 0.85)  // 2kHz - 临场感
        
        // 高频段调整
        let highBoost = highDiff * 18
        eqGains[7] = clampGain(highBoost * 0.6 + midBoost * 0.2)  // 4kHz - 清晰度
        eqGains[8] = clampGain(highBoost * 1.0)   // 8kHz - 高频核心
        eqGains[9] = clampGain(highBoost * 0.75)  // 16kHz - 空气感
        
        // 基于音色亮度微调高频
        let centroidTarget: Float = 2200  // 理想频谱质心
        let brightnessAdjust = clampGain((centroidTarget - freq.spectralCentroid) / 400)
        eqGains[7] += brightnessAdjust * 0.25
        eqGains[8] += brightnessAdjust * 0.4
        eqGains[9] += brightnessAdjust * 0.3
        
        // 重新 clamp
        for i in 0..<10 {
            eqGains[i] = clampGain(eqGains[i])
        }

        // ═══════════════════════════════════════
        // 智能音效参数生成（基于完整分析）
        // ═══════════════════════════════════════
        
        var bassGain: Float = lowDiff * 10
        var trebleGain: Float = highDiff * 10
        
        // 环绕强度：基于立体声宽度和频率分布
        var surroundLevel: Float = 0.2 + freq.lowEnergyRatio * 0.3
        if let phase = sdkResult.phase {
            // 如果立体声宽度较窄，增加环绕效果
            if phase.stereoWidth < 0.3 {
                surroundLevel += 0.2
            }
        }
        
        // 混响强度：基于动态范围和高频能量
        var reverbLevel: Float = 0.1 + freq.highEnergyRatio * 0.25
        if dynamic.drValue >= 12 {
            // 高动态范围的音乐（古典/爵士）适合更多混响
            reverbLevel += 0.15
        }
        
        // 立体声宽度：基于频率平衡
        let balance = 1.0 - abs(freq.lowEnergyRatio - freq.highEnergyRatio)
        var stereoWidth: Float = 1.0 + balance * 0.4
        
        // 响度标准化：禁用（可能导致音质问题）
        let loudnormEnabled = false
        
        // 根据风格微调
        switch genre {
        case .electronic, .hiphop:
            bassGain += 2.5
            surroundLevel = min(1.0, surroundLevel + 0.15)
            
        case .classical, .jazz:
            surroundLevel = max(0.1, surroundLevel - 0.1)
            reverbLevel = min(0.6, reverbLevel + 0.2)
            stereoWidth = min(1.4, stereoWidth)
            
        case .rock, .metal:
            trebleGain += 2.0
            surroundLevel = min(1.0, surroundLevel + 0.1)
            
        case .vocal, .acoustic:
            surroundLevel = max(0.1, surroundLevel - 0.15)
            reverbLevel = max(0.05, reverbLevel - 0.1)
            // 人声增强：提升中频
            eqGains[5] += 1.5
            eqGains[6] += 1.0
            
        case .rnb:
            bassGain += 1.5
            reverbLevel = min(0.4, reverbLevel + 0.1)
            
        default:
            break
        }
        
        // ═══════════════════════════════════════
        // 新增滤镜智能推荐（v1.1.9）
        // 暂时全部禁用，避免滤镜图重建导致没声音
        // ═══════════════════════════════════════
        
        // 音频修复：全部禁用
        let declipEnabled = false
        let fftDenoiseEnabled = false
        let fftDenoiseAmount: Float = 10.0
        
        // 动态标准化：禁用
        let dynaudnormEnabled = false
        
        // 语音标准化：禁用
        let speechnormEnabled = false
        
        // 耳机优化：禁用（BS2B 可能导致问题）
        let bs2bEnabled = false
        
        // 交叉馈送：禁用
        let crossfeedEnabled = false
        let crossfeedStrength: Float = 0.3
        
        // Haas 效果：禁用
        let haasEnabled = false
        let haasDelay: Float = 20.0
        
        // 虚拟低音：禁用
        let virtualbassEnabled = false
        let virtualbassCutoff: Float = 250.0
        let virtualbassStrength: Float = 3.0
        
        // 激励器：禁用
        let exciterEnabled = false
        let exciterAmount: Float = 3.0
        let exciterFreq: Float = 7500.0
        
        // 软削波：禁用
        let softclipEnabled = false
        let softclipType = 0
        
        // 对话增强：禁用
        let dialogueEnhanceEnabled = false
        
        return RecommendedEffects(
            bassGain: clampGain(bassGain),
            trebleGain: clampGain(trebleGain),
            surroundLevel: max(0, min(1, surroundLevel)),
            reverbLevel: max(0, min(1, reverbLevel)),
            stereoWidth: max(0.5, min(2, stereoWidth)),
            loudnormEnabled: loudnormEnabled,
            eqGains: eqGains,
            fftDenoiseEnabled: fftDenoiseEnabled,
            fftDenoiseAmount: fftDenoiseAmount,
            declickEnabled: false,  // 仅手动启用（黑胶场景）
            declipEnabled: declipEnabled,
            dynaudnormEnabled: dynaudnormEnabled,
            speechnormEnabled: speechnormEnabled,
            compandEnabled: false,  // 高级功能，仅手动启用
            bs2bEnabled: bs2bEnabled,
            crossfeedEnabled: crossfeedEnabled,
            crossfeedStrength: crossfeedStrength,
            haasEnabled: haasEnabled,
            haasDelay: haasDelay,
            virtualbassEnabled: virtualbassEnabled,
            virtualbassCutoff: virtualbassCutoff,
            virtualbassStrength: virtualbassStrength,
            exciterEnabled: exciterEnabled,
            exciterAmount: exciterAmount,
            exciterFreq: exciterFreq,
            softclipEnabled: softclipEnabled,
            softclipType: softclipType,
            dialogueEnhanceEnabled: dialogueEnhanceEnabled
        )
    }

    // MARK: - 实时频谱分析（回退方案）
    
    /// 收集频谱数据（收集更多帧以获得稳定结果）
    private func collectSpectrumData() async throws -> [Float] {
        let analyzer = PlayerManager.shared.spectrumAnalyzer
        analyzer.isEnabled = true
        
        var collectedSpectrums: [[Float]] = []
        let targetFrames = 100  // 收集 100 帧数据（约 2-3 秒）以获得更稳定的平均值
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var frameCount = 0
            var hasResumed = false
            
            analyzer.onSpectrum = { magnitudes in
                collectedSpectrums.append(magnitudes)
                frameCount += 1
                if frameCount >= targetFrames && !hasResumed {
                    hasResumed = true
                    analyzer.onSpectrum = nil
                    continuation.resume()
                }
            }
            
            // 超时保护（5秒）
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !hasResumed {
                    hasResumed = true
                    analyzer.onSpectrum = nil
                    continuation.resume()
                }
            }
        }
        
        analyzer.isEnabled = false
        
        guard !collectedSpectrums.isEmpty else { return [] }
        
        // 计算平均频谱（去除最高和最低 10% 的异常值）
        let bandCount = collectedSpectrums[0].count
        var averageSpectrum = [Float](repeating: 0, count: bandCount)
        
        for bandIndex in 0..<bandCount {
            // 收集该频段的所有值
            var bandValues: [Float] = []
            for spectrum in collectedSpectrums {
                if bandIndex < spectrum.count {
                    bandValues.append(spectrum[bandIndex])
                }
            }
            
            // 排序并去除异常值
            bandValues.sort()
            let trimCount = max(1, bandValues.count / 10)  // 去除 10%
            let trimmedValues = Array(bandValues.dropFirst(trimCount).dropLast(trimCount))
            
            // 计算平均值
            if !trimmedValues.isEmpty {
                averageSpectrum[bandIndex] = trimmedValues.reduce(0, +) / Float(trimmedValues.count)
            }
        }
        
        return averageSpectrum
    }
    
    /// 基于频谱数据分析音频特征（回退方案）
    private func analyzeFromSpectrum(spectrumData: [Float]) -> AudioAnalysisResult {
        // 计算频段能量分布
        let (lowRatio, midRatio, highRatio) = calculateFrequencyRatios(spectrum: spectrumData)
        
        // 计算频谱质心
        let centroid = calculateSpectralCentroid(spectrum: spectrumData)
        
        // 估算 BPM
        let bpm = estimateBPMFromSpectrum(spectrum: spectrumData)
        
        // 推断音乐类型
        let genre = inferGenre(lowRatio: lowRatio, midRatio: midRatio, highRatio: highRatio, centroid: centroid, bpm: bpm)
        
        // 生成音色分析
        let timbre = analyzeTimbreFromSpectrum(lowRatio: lowRatio, midRatio: midRatio, highRatio: highRatio, centroid: centroid)
        
        // 生成推荐设置
        let recommendedEffects = generateRecommendedEffects(
            genre: genre,
            lowRatio: lowRatio,
            midRatio: midRatio,
            highRatio: highRatio,
            centroid: centroid,
            timbre: timbre
        )
        
        return AudioAnalysisResult(
            bpm: bpm,
            bpmConfidence: 0.6,  // 实时分析置信度较低
            loudness: -14.0,
            dynamicRange: 10.0,
            spectralCentroid: centroid,
            lowFrequencyRatio: lowRatio,
            midFrequencyRatio: midRatio,
            highFrequencyRatio: highRatio,
            suggestedGenre: genre,
            recommendedPresetId: getRecommendedPreset(for: genre),
            recommendedEffects: recommendedEffects,
            timbreAnalysis: timbre,
            qualityAssessment: nil
        )
    }

    /// 计算频段能量分布
    private func calculateFrequencyRatios(spectrum: [Float]) -> (low: Float, mid: Float, high: Float) {
        guard !spectrum.isEmpty else { return (0.33, 0.34, 0.33) }
        
        let count = spectrum.count
        let lowEnd = count / 4
        let midEnd = count * 3 / 4
        
        var lowSum: Float = 0
        var midSum: Float = 0
        var highSum: Float = 0
        
        for i in 0..<count {
            let mag = spectrum[i] * spectrum[i]
            if i < lowEnd {
                lowSum += mag
            } else if i < midEnd {
                midSum += mag
            } else {
                highSum += mag
            }
        }
        
        let total = lowSum + midSum + highSum
        guard total > 0 else { return (0.33, 0.34, 0.33) }
        
        return (lowSum / total, midSum / total, highSum / total)
    }
    
    /// 计算频谱质心
    private func calculateSpectralCentroid(spectrum: [Float]) -> Float {
        guard !spectrum.isEmpty else { return 1000 }
        
        let nyquist: Float = 22050
        let binWidth = nyquist / Float(spectrum.count)
        
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for (i, mag) in spectrum.enumerated() {
            let freq = Float(i) * binWidth
            weightedSum += freq * mag
            magnitudeSum += mag
        }
        
        guard magnitudeSum > 0 else { return 1000 }
        return weightedSum / magnitudeSum
    }
    
    /// 基于频谱估算 BPM（基于低频能量特征）
    private func estimateBPMFromSpectrum(spectrum: [Float]) -> Float {
        let lowEnergy = spectrum.prefix(spectrum.count / 4).reduce(0, +)
        let totalEnergy = spectrum.reduce(0, +)
        let lowRatio = totalEnergy > 0 ? lowEnergy / totalEnergy : 0.3
        
        // 基于低频能量比例估算典型 BPM 范围的中值
        // 低频能量高 → 电子/嘻哈风格 → 较高 BPM
        // 低频能量低 → 古典/民谣风格 → 较低 BPM
        if lowRatio > 0.4 {
            return 128  // 电子/嘻哈典型 BPM
        } else if lowRatio > 0.3 {
            return 110  // 流行/摇滚典型 BPM
        } else {
            return 85   // 慢歌/古典典型 BPM
        }
    }
    
    /// 推断音乐类型
    private func inferGenre(lowRatio: Float, midRatio: Float, highRatio: Float, centroid: Float, bpm: Float) -> SuggestedGenre {
        if lowRatio > 0.4 && midRatio < 0.35 {
            return bpm > 120 ? .electronic : .hiphop
        }
        if midRatio > 0.45 {
            return centroid > 2000 ? .vocal : .acoustic
        }
        if highRatio > 0.35 {
            return centroid > 3000 ? .classical : .jazz
        }
        if bpm > 110 {
            return lowRatio > 0.35 ? .rock : .pop
        }
        if lowRatio > 0.35 && bpm < 100 {
            return .rnb
        }
        return .pop
    }

    /// 分析音色特征
    private func analyzeTimbreFromSpectrum(lowRatio: Float, midRatio: Float, highRatio: Float, centroid: Float) -> TimbreInfo {
        let brightness = min(1.0, centroid / 4000.0)
        let warmth = min(1.0, lowRatio * 2.5)
        let clarity = min(1.0, highRatio * 3.0)
        let fullness = min(1.0, midRatio * 1.5)
        
        var descriptions: [String] = []
        if brightness > 0.7 { descriptions.append("明亮") }
        else if brightness < 0.3 { descriptions.append("暗淡") }
        if warmth > 0.6 { descriptions.append("温暖") }
        else if warmth < 0.3 { descriptions.append("单薄") }
        if clarity > 0.5 { descriptions.append("清晰") }
        if fullness > 0.6 { descriptions.append("丰满") }
        else if fullness < 0.3 { descriptions.append("空洞") }
        
        let description = descriptions.isEmpty ? "均衡" : descriptions.joined(separator: "、")
        
        var suggestions: [String] = []
        if warmth < 0.3 { suggestions.append("增加低频") }
        else if warmth > 0.7 { suggestions.append("降低低频") }
        if brightness < 0.3 { suggestions.append("增加高频") }
        else if brightness > 0.8 { suggestions.append("降低高频") }
        if fullness < 0.4 { suggestions.append("增加中频") }
        
        let eqSuggestion = suggestions.isEmpty ? "音色均衡" : suggestions.joined(separator: "；")
        
        return TimbreInfo(
            brightness: brightness,
            warmth: warmth,
            clarity: clarity,
            fullness: fullness,
            description: description,
            eqSuggestion: eqSuggestion
        )
    }
    
    /// 获取推荐的 EQ 预设
    private func getRecommendedPreset(for genre: SuggestedGenre) -> String {
        switch genre {
        case .pop: return "pop"
        case .rock: return "rock"
        case .electronic: return "electronic"
        case .hiphop: return "hiphop"
        case .classical: return "classical"
        case .jazz: return "jazz"
        case .rnb: return "rnb"
        case .acoustic: return "acoustic"
        case .vocal: return "vocal_enhance"
        case .metal: return "metal"
        case .unknown: return "flat"
        }
    }

    /// 生成推荐的音效参数（实时分析版本）
    private func generateRecommendedEffects(
        genre: SuggestedGenre,
        lowRatio: Float,
        midRatio: Float,
        highRatio: Float,
        centroid: Float,
        timbre: TimbreInfo
    ) -> RecommendedEffects {
        var eqGains: [Float] = Array(repeating: 0, count: 10)
        
        let idealLow: Float = 0.30
        let idealMid: Float = 0.40
        let idealHigh: Float = 0.30
        
        let lowDiff = idealLow - lowRatio
        let midDiff = idealMid - midRatio
        let highDiff = idealHigh - highRatio
        
        let lowBoost = lowDiff * 15
        eqGains[0] = clampGain(lowBoost * 0.8)
        eqGains[1] = clampGain(lowBoost * 1.0)
        eqGains[2] = clampGain(lowBoost * 0.9)
        eqGains[3] = clampGain(lowBoost * 0.3 + midDiff * 0.3)
        
        let midBoost = midDiff * 12
        eqGains[4] = clampGain(midBoost * 0.7)
        eqGains[5] = clampGain(midBoost * 1.0)
        eqGains[6] = clampGain(midBoost * 0.8)
        
        let highBoost = highDiff * 15
        eqGains[7] = clampGain(highBoost * 0.7)
        eqGains[8] = clampGain(highBoost * 1.0)
        eqGains[9] = clampGain(highBoost * 0.8)
        
        let centroidTarget: Float = 2000
        let brightnessAdjust = clampGain((centroidTarget - centroid) / 500)
        eqGains[7] += brightnessAdjust * 0.3
        eqGains[8] += brightnessAdjust * 0.5
        eqGains[9] += brightnessAdjust * 0.4
        
        for i in 0..<10 {
            eqGains[i] = clampGain(eqGains[i])
        }
        
        var bassGain: Float = lowDiff * 8
        var trebleGain: Float = highDiff * 8
        var surroundLevel: Float = 0.2 + lowRatio * 0.4
        var reverbLevel: Float = 0.1 + highRatio * 0.3
        let balance = 1.0 - abs(lowRatio - highRatio)
        var stereoWidth: Float = 1.0 + balance * 0.5
        let loudnormEnabled = false
        
        switch genre {
        case .electronic, .hiphop:
            bassGain += 2.0
            surroundLevel = min(1.0, surroundLevel + 0.15)
        case .classical, .jazz:
            surroundLevel = max(0.1, surroundLevel - 0.1)
            reverbLevel = min(0.5, reverbLevel + 0.15)
            stereoWidth = min(1.5, stereoWidth)
        case .rock, .metal:
            trebleGain += 1.5
            surroundLevel = min(1.0, surroundLevel + 0.1)
        case .vocal, .acoustic:
            surroundLevel = max(0.1, surroundLevel - 0.15)
            reverbLevel = max(0.05, reverbLevel - 0.1)
        default:
            break
        }
        
        return RecommendedEffects.defaultNewFilters(
            bassGain: clampGain(bassGain),
            trebleGain: clampGain(trebleGain),
            surroundLevel: max(0, min(1, surroundLevel)),
            reverbLevel: max(0, min(1, reverbLevel)),
            stereoWidth: max(0.5, min(2, stereoWidth)),
            loudnormEnabled: loudnormEnabled,
            eqGains: eqGains
        )
    }
    
    /// 限制增益范围
    private func clampGain(_ gain: Float) -> Float {
        return max(-12, min(12, gain))
    }

    // MARK: - 应用推荐设置
    
    /// 应用推荐的音效设置
    func applyRecommendedSettings(_ analysis: AudioAnalysisResult) {
        let effects = PlayerManager.shared.audioEffects
        let recommended = analysis.recommendedEffects
        
        // 应用基础音效参数
        effects.setBassGain(recommended.bassGain)
        effects.setTrebleGain(recommended.trebleGain)
        effects.setSurroundLevel(recommended.surroundLevel)
        effects.setReverbLevel(recommended.reverbLevel)
        effects.setStereoWidth(recommended.stereoWidth)
        effects.setLoudnormEnabled(recommended.loudnormEnabled)
        
        // 应用智能 EQ 曲线
        let equalizer = PlayerManager.shared.equalizer
        for (index, band) in EQBand.allCases.enumerated() {
            if index < recommended.eqGains.count {
                equalizer.setGain(recommended.eqGains[index], for: band)
            }
        }
        
        // 启用 EQ
        if !EQManager.shared.isEnabled {
            EQManager.shared.isEnabled = true
        }
        
        // 更新自定义增益
        EQManager.shared.customGains = recommended.eqGains
        
        // 设置为智能预设
        EQManager.shared.currentPreset = EQPreset(
            id: "smart_auto",
            name: "智能",
            category: .custom,
            description: "基于音频分析自动生成",
            gains: recommended.eqGains,
            isCustom: true
        )
        
        EQManager.shared.saveAudioEffectsState()
        
        let modeText = analysisMode == .file ? "文件分析" : "实时分析"
        AppLogger.info("智能音效已应用（\(modeText)）: \(analysis.suggestedGenre.rawValue) 风格")
    }
    
    // MARK: - 音频修复引擎配置
    
    /// 根据分析结果和推荐音效智能配置修复引擎
    ///
    /// 修复引擎处理两类问题：
    /// 1. 歌曲本身的音频瑕疵（削波、爆音、直流偏移等）
    /// 2. 智能适配 EQ/音效后可能引入的问题（过度增益导致削波、响度标准化引入量化噪声等）
    private func configureRepairEngine(analysis: AudioAnalysisResult, recommendedEffects: RecommendedEffects) {
        // 修复引擎和新滤镜暂时禁用
    }
    
    /// 手动应用当前分析结果
    func applyCurrentAnalysis() {
        guard let analysis = currentAnalysis else { return }
        applyRecommendedSettings(analysis)
    }
    
    /// 重置为手动模式（关闭智能分析时调用）
    private func resetToManualMode() {
        currentAnalysis = nil
        lastAnalyzedSongId = nil
        
        // 重置 EQ 和音效参数到默认值
        resetEQToDefault()
    }
    
    /// 重置 EQ 和音效参数到默认值
    func resetEQToDefault() {
        // 重置基础音效参数
        let effects = PlayerManager.shared.audioEffects
        effects.setBassGain(0)
        effects.setTrebleGain(0)
        effects.setSurroundLevel(0)
        effects.setReverbLevel(0)
        effects.setStereoWidth(1.0)
        effects.setLoudnormEnabled(false)
        
        // 重置 EQ 均衡器
        EQManager.shared.applyFlat()
        EQManager.shared.saveAudioEffectsState()
        
        AppLogger.info("智能音效已关闭，EQ 和所有滤镜已重置为默认值")
    }
    
    // MARK: - 持久化
    
    private func saveState() {
        UserDefaults.standard.set(isSmartEffectsEnabled, forKey: "audio_lab_smart_effects_enabled")
        UserDefaults.standard.set(analysisMode.rawValue, forKey: "audio_lab_analysis_mode")
    }
    
    private func restoreState() {
        isSmartEffectsEnabled = UserDefaults.standard.bool(forKey: "audio_lab_smart_effects_enabled")
        if let modeRaw = UserDefaults.standard.string(forKey: "audio_lab_analysis_mode"),
           let mode = AnalysisMode(rawValue: modeRaw) {
            analysisMode = mode
        }
    }
}
