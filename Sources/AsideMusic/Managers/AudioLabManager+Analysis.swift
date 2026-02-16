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
    
    /// 强制重新分析（忽略缓存）
    func forceReanalyze() async {
        guard let song = PlayerManager.shared.currentSong else { return }
        analysisCache.removeValue(forKey: song.id)
        lastAnalyzedSongId = nil
        await analyzeCurrentSong()
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
