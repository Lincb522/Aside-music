// AudioLabManager+Analysis.swift
// AsideMusic
//
// 音频分析入口：analyzeCurrentSong, forceReanalyze, 下载分析流程

import Foundation
import Combine
import FFmpegSwiftSDK

extension AudioLabManager {
    
    // MARK: - 音频分析（使用 SDK 的 AudioAnalyzer）
    
    /// 分析当前播放的歌曲（只分析，不自动应用）
    func analyzeCurrentSong() async {
        guard let song = PlayerManager.shared.currentSong else { return }
        guard !isAnalyzing else { return }
        
        // 检查内存缓存（同一首歌不重复分析）
        if let cached = analysisCache[song.id] {
            currentAnalysis = cached
            lastAnalyzedSongId = song.id
            AppLogger.info("使用内存缓存的分析结果: \(song.name)")
            return
        }
        
        // 检查磁盘持久化缓存
        if let persisted = loadPersistedAnalysis(songId: song.id) {
            analysisCache[song.id] = persisted
            currentAnalysis = persisted
            lastAnalyzedSongId = song.id
            AppLogger.info("使用持久化缓存的分析结果: \(song.name)")
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
            
            // 缓存结果到内存
            analysisCache[song.id] = analysis
            
            // 持久化到磁盘（文件分析结果更有价值，优先持久化）
            if analysisMode == .file {
                persistAnalysis(analysis, songId: song.id)
            }
            
            // 智能淘汰：超过上限时移除最早的缓存
            if analysisCache.count > maxAnalysisCacheCount {
                let keysToRemove = analysisCache.keys.prefix(analysisCache.count - maxAnalysisCacheCount)
                for key in keysToRemove {
                    analysisCache.removeValue(forKey: key)
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
    
    /// 强制重新分析（忽略缓存）
    func forceReanalyze() async {
        guard let song = PlayerManager.shared.currentSong else { return }
        analysisCache.removeValue(forKey: song.id)
        removePersistedAnalysis(songId: song.id)
        lastAnalyzedSongId = nil
        await analyzeCurrentSong()
    }
    
    // MARK: - 分析结果持久化
    
    /// 将分析结果持久化到 UserDefaults（轻量级，适合结构化数据）
    private func persistAnalysis(_ analysis: AudioAnalysisResult, songId: Int) {
        let key = "\(analysisCachePrefix)\(songId)"
        let dict: [String: Any] = [
            "bpm": analysis.bpm,
            "bpmConfidence": analysis.bpmConfidence,
            "loudness": analysis.loudness,
            "dynamicRange": analysis.dynamicRange,
            "spectralCentroid": analysis.spectralCentroid,
            "lowFrequencyRatio": analysis.lowFrequencyRatio,
            "midFrequencyRatio": analysis.midFrequencyRatio,
            "highFrequencyRatio": analysis.highFrequencyRatio,
            "genre": analysis.suggestedGenre.rawValue,
            "presetId": analysis.recommendedPresetId,
            "eqGains": analysis.recommendedEffects.eqGains,
            "bassGain": analysis.recommendedEffects.bassGain,
            "trebleGain": analysis.recommendedEffects.trebleGain,
            "surroundLevel": analysis.recommendedEffects.surroundLevel,
            "reverbLevel": analysis.recommendedEffects.reverbLevel,
            "stereoWidth": analysis.recommendedEffects.stereoWidth,
            "timestamp": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(dict, forKey: key)
        
        // 维护持久化索引
        var index = UserDefaults.standard.array(forKey: "\(analysisCachePrefix)index") as? [Int] ?? []
        if !index.contains(songId) {
            index.append(songId)
            // 超过上限时清理最旧的
            if index.count > maxAnalysisCacheCount {
                let toRemove = index.prefix(index.count - maxAnalysisCacheCount)
                for id in toRemove {
                    UserDefaults.standard.removeObject(forKey: "\(analysisCachePrefix)\(id)")
                }
                index = Array(index.suffix(maxAnalysisCacheCount))
            }
            UserDefaults.standard.set(index, forKey: "\(analysisCachePrefix)index")
        }
    }
    
    /// 从持久化缓存加载分析结果
    private func loadPersistedAnalysis(songId: Int) -> AudioAnalysisResult? {
        let key = "\(analysisCachePrefix)\(songId)"
        guard let dict = UserDefaults.standard.dictionary(forKey: key) else { return nil }
        
        // 检查是否过期（7天）
        if let timestamp = dict["timestamp"] as? TimeInterval {
            let age = Date().timeIntervalSince1970 - timestamp
            if age > 7 * 24 * 3600 {
                UserDefaults.standard.removeObject(forKey: key)
                return nil
            }
        }
        
        guard let bpm = dict["bpm"] as? Float,
              let genreRaw = dict["genre"] as? String,
              let genre = SuggestedGenre(rawValue: genreRaw),
              let eqGains = dict["eqGains"] as? [Float] else {
            return nil
        }
        
        let effects = RecommendedEffects.defaultNewFilters(
            bassGain: dict["bassGain"] as? Float ?? 0,
            trebleGain: dict["trebleGain"] as? Float ?? 0,
            surroundLevel: dict["surroundLevel"] as? Float ?? 0.2,
            reverbLevel: dict["reverbLevel"] as? Float ?? 0.1,
            stereoWidth: dict["stereoWidth"] as? Float ?? 1.0,
            loudnormEnabled: false,
            eqGains: eqGains
        )
        
        return AudioAnalysisResult(
            bpm: bpm,
            bpmConfidence: dict["bpmConfidence"] as? Float ?? 0.6,
            loudness: dict["loudness"] as? Float ?? -14,
            dynamicRange: dict["dynamicRange"] as? Float ?? 10,
            spectralCentroid: dict["spectralCentroid"] as? Float ?? 1000,
            lowFrequencyRatio: dict["lowFrequencyRatio"] as? Float ?? 0.33,
            midFrequencyRatio: dict["midFrequencyRatio"] as? Float ?? 0.34,
            highFrequencyRatio: dict["highFrequencyRatio"] as? Float ?? 0.33,
            suggestedGenre: genre,
            recommendedPresetId: dict["presetId"] as? String ?? "flat",
            recommendedEffects: effects,
            timbreAnalysis: nil,
            qualityAssessment: nil
        )
    }
    
    /// 删除持久化的分析结果
    private func removePersistedAnalysis(songId: Int) {
        let key = "\(analysisCachePrefix)\(songId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - 下载并分析
    
    /// 下载歌曲源文件进行分析，分析完成后自动删除临时文件
    func analyzeByDownloading(song: Song) async throws -> AudioAnalysisResult {
        AppLogger.info("开始下载歌曲进行分析: \(song.name)")
        
        let songUrl = try await fetchSongUrlAsync(songId: song.id)
        guard let url = URL(string: songUrl) else {
            throw AnalysisError.invalidUrl
        }
        
        analysisProgress = 0.1
        
        let tempFileURL = try await downloadToTemp(url: url, songId: song.id)
        
        analysisProgress = 0.4
        
        defer {
            cleanupTempFile(tempFileURL)
        }
        
        let analysis = try await analyzeFromFile(url: tempFileURL.path)
        
        return analysis
    }
    
    /// 异步获取歌曲 URL
    func fetchSongUrlAsync(songId: Int) async throws -> String {
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
    func downloadToTemp(url: URL, songId: Int) async throws -> URL {
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
    func cleanupTempFile(_ url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                AppLogger.info("已删除分析临时文件: \(url.lastPathComponent)")
            }
        } catch {
            AppLogger.warning("删除临时文件失败: \(error.localizedDescription)")
        }
    }
}
