// PlayerViewModel.swift
// FFmpegDemo

import Foundation
import FFmpegSwiftSDK
import AVFoundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {

    // MARK: - 播放状态

    @Published var urlText: String = ""
    @Published var state: String = "空闲"
    @Published var errorMessage: String?
    @Published var duration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published var streamInfoText: String = ""
    @Published var hifiInfoText: String = ""
    @Published var videoInfoText: String = ""
    @Published var hasVideo: Bool = false

    // MARK: - 10 段 EQ

    @Published var eqGains: [EQBand: Float] = {
        var g = [EQBand: Float]()
        for band in EQBand.allCases { g[band] = 0.0 }
        return g
    }()
    @Published var clampMessage: String?

    // MARK: - 音频效果

    @Published var volume: Float = 0          // dB
    @Published var tempo: Float = 1.0         // 倍速
    @Published var pitch: Float = 0           // 半音
    @Published var bassGain: Float = 0        // dB
    @Published var trebleGain: Float = 0      // dB
    @Published var surroundLevel: Float = 0   // 0~1
    @Published var reverbLevel: Float = 0     // 0~1
    @Published var stereoWidth: Float = 1.0   // 0~2
    @Published var channelBalance: Float = 0  // -1~1
    @Published var vocalRemoval: Float = 0    // 0~1
    @Published var fadeInDuration: Float = 0  // 秒
    @Published var delayMs: Float = 0         // 毫秒
    
    // 开关效果
    @Published var loudnormEnabled: Bool = false
    @Published var nightModeEnabled: Bool = false
    @Published var limiterEnabled: Bool = false
    @Published var gateEnabled: Bool = false
    @Published var autoGainEnabled: Bool = false
    @Published var subboostEnabled: Bool = false
    @Published var monoEnabled: Bool = false
    @Published var channelSwapEnabled: Bool = false
    @Published var chorusEnabled: Bool = false
    @Published var flangerEnabled: Bool = false
    @Published var tremoloEnabled: Bool = false
    @Published var vibratoEnabled: Bool = false
    @Published var lofiEnabled: Bool = false
    @Published var telephoneEnabled: Bool = false
    @Published var underwaterEnabled: Bool = false
    @Published var radioEnabled: Bool = false

    // MARK: - 频谱

    @Published var spectrumData: [Float] = Array(repeating: 0, count: 32)
    @Published var spectrumEnabled: Bool = false {
        didSet { player.spectrumAnalyzer.isEnabled = spectrumEnabled }
    }

    // MARK: - 波形

    @Published var waveformSamples: [WaveformSample] = []
    @Published var waveformLoading: Bool = false

    // MARK: - 元数据

    @Published var metaTitle: String?
    @Published var metaArtist: String?
    @Published var metaAlbum: String?
    @Published var artworkData: Data?

    // MARK: - A-B 循环

    @Published var abLoopEnabled: Bool = false
    @Published var abPointA: TimeInterval = 0
    @Published var abPointB: TimeInterval = 0

    // MARK: - 歌词

    @Published var currentLyricLine: String = ""
    @Published var currentLyricTranslation: String?
    @Published var lyricProgress: Float = 0
    @Published var nearbyLyrics: [(index: Int, text: String, isCurrent: Bool)] = []
    @Published var lyricOffset: Double = 0 {
        didSet { player.lyricSyncer.offset = lyricOffset }
    }
    @Published var hasLyrics: Bool = false

    // MARK: - EQ 预设

    @Published var selectedPreset: EQPreset? = nil
    @Published var presetsByCategory: [(category: String, presets: [EQPreset])] = EQPresets.byCategory

    // MARK: - 音频分析

    @Published var isAnalyzing: Bool = false
    @Published var analysisProgress: Float = 0
    @Published var analysisResult: AnalysisResult?

    struct AnalysisResult {
        // BPM
        let bpm: Float
        let bpmConfidence: Float
        let bpmStability: Float
        
        // 响度
        let loudnessLUFS: Float
        let shortTermLUFS: Float
        let loudnessRange: Float
        
        // 动态
        let dynamicRange: Float
        let drValue: Int
        let peakDB: Float
        let rmsDB: Float
        let crestFactor: Float
        let compressionDesc: String
        
        // 频率
        let spectralCentroid: Float
        let dominantFreq: Float
        let lowEnergyRatio: Float
        let midEnergyRatio: Float
        let highEnergyRatio: Float
        
        // 音色
        let brightness: Float
        let warmth: Float
        let timbreDesc: String
        let eqSuggestion: String
        
        // 音调
        let pitchNote: String
        let pitchFreq: Float
        
        // 质量
        let qualityScore: Int
        let qualityGrade: String
        let hasClipping: Bool
        let issues: [String]
        
        // 相位（立体声）
        let phaseCorrelation: Float
        let stereoWidth: Float
        let phaseDescription: String
        
        // 节拍数
        let beatCount: Int
    }

    // MARK: - 歌曲识别

    @Published var isRecognizing: Bool = false
    @Published var recognitionResult: RecognitionResult?
    @Published var recognitionMessage: String?
    @Published var fingerprintDBCount: Int = 0

    struct RecognitionResult {
        let title: String
        let artist: String
        let score: Float
    }

    private let fingerprintDB = FingerprintDatabase()

    // MARK: - 语音识别歌词

    @Published var isRecognizingLyrics: Bool = false
    @Published var lyricRecognitionProgress: Float = 0
    @Published var recognizedLyricResult: RecognizedLyric?
    @Published var recognizedLyricMessage: String?
    @Published var isPreparingRecognizer: Bool = false
    @Published var recognizerReady: Bool = false

    private let lyricRecognizer = LyricRecognizer()

    // MARK: - 内部

    let player = StreamPlayer()
    private let delegateAdapter = PlayerDelegateAdapter()
    private var timer: Timer?

    var videoLayer: AVSampleBufferDisplayLayer {
        player.videoDisplayLayer
    }

    init() {
        delegateAdapter.viewModel = self
        player.delegate = delegateAdapter
        player.equalizer.delegate = delegateAdapter

        // 频谱回调
        player.spectrumAnalyzer.onSpectrum = { [weak self] magnitudes in
            // 降采样到 32 段
            let target = 32
            let step = max(magnitudes.count / target, 1)
            var reduced = [Float]()
            for i in stride(from: 0, to: min(magnitudes.count, target * step), by: step) {
                let end = min(i + step, magnitudes.count)
                let avg = magnitudes[i..<end].reduce(0, +) / Float(end - i)
                reduced.append(avg)
            }
            while reduced.count < target { reduced.append(0) }
            Task { @MainActor [weak self] in
                self?.spectrumData = Array(reduced.prefix(target))
            }
        }

        // 歌词回调
        player.lyricSyncer.onSync = { [weak self] lineIndex, line, wordIndex, progress in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentLyricLine = line.text
                self.currentLyricTranslation = line.translation
                self.lyricProgress = progress
                // 附近歌词
                let nearby = self.player.lyricSyncer.nearbyLines(range: 3)
                self.nearbyLyrics = nearby.map { item in
                    (index: item.index, text: item.line.text, isCurrent: item.index == lineIndex)
                }
            }
        }
    }

    // MARK: - 播放控制

    func play() {
        errorMessage = nil
        clampMessage = nil
        player.play(url: urlText)
        startTimeUpdater()
        loadMetadata()
        loadWaveform()
    }

    func pause() { player.pause() }
    func resume() { player.resume() }

    func stop() {
        player.stop()
        stopTimeUpdater()
        currentTime = 0
        hasVideo = false
        videoInfoText = ""
        spectrumData = Array(repeating: 0, count: 32)
        waveformSamples = []
        currentLyricLine = ""
        nearbyLyrics = []
    }

    func seek(to time: TimeInterval) {
        player.seek(to: time)
        currentTime = time
    }

    // MARK: - EQ

    func updateGain(_ value: Float, for band: EQBand) {
        player.equalizer.setGain(value, for: band)
        eqGains[band] = player.equalizer.gain(for: band)
    }

    func resetEQ() {
        player.equalizer.reset()
        for band in EQBand.allCases { eqGains[band] = 0.0 }
        clampMessage = nil
        selectedPreset = nil
    }

    // MARK: - EQ 预设

    func applyPreset(_ preset: EQPreset) {
        player.equalizer.applyPreset(preset)
        // 更新 UI 状态
        for band in EQBand.allCases {
            eqGains[band] = preset.gains[band] ?? 0.0
        }
        selectedPreset = preset
        // 同步效果参数到 UI
        if preset.surroundLevel > 0 {
            surroundLevel = preset.surroundLevel
        }
        if preset.stereoWidth != 1.0 {
            stereoWidth = preset.stereoWidth
        }
        if preset.bassBoost != 0 {
            bassGain = preset.bassBoost
        }
        if preset.trebleBoost != 0 {
            trebleGain = preset.trebleBoost
        }
    }

    func clearPreset() {
        resetEQ()
        resetEffects()
    }

    // MARK: - 音频效果

    func updateVolume(_ db: Float) {
        volume = db
        player.audioEffects.setVolume(db)
    }

    func updateTempo(_ rate: Float) {
        tempo = rate
        player.audioEffects.setTempo(rate)
    }

    func updatePitch(_ semitones: Float) {
        pitch = semitones
        player.audioEffects.setPitch(semitones)
    }

    func updateBass(_ db: Float) {
        bassGain = db
        player.audioEffects.setBassGain(db)
    }

    func updateTreble(_ db: Float) {
        trebleGain = db
        player.audioEffects.setTrebleGain(db)
    }

    func updateSurround(_ level: Float) {
        surroundLevel = level
        player.audioEffects.setSurroundLevel(level)
    }

    func updateReverb(_ level: Float) {
        reverbLevel = level
        player.audioEffects.setReverbLevel(level)
    }

    func updateStereoWidth(_ width: Float) {
        stereoWidth = width
        player.audioEffects.setStereoWidth(width)
    }

    func updateChannelBalance(_ balance: Float) {
        channelBalance = balance
        player.audioEffects.setChannelBalance(balance)
    }

    func updateVocalRemoval(_ level: Float) {
        vocalRemoval = level
        player.audioEffects.setVocalRemoval(level)
    }

    func updateFadeIn(_ duration: Float) {
        fadeInDuration = duration
        player.audioEffects.setFadeIn(duration: duration)
    }

    func updateDelay(_ ms: Float) {
        delayMs = ms
        player.audioEffects.setDelay(ms)
    }

    func toggleLoudnorm() {
        loudnormEnabled.toggle()
        player.audioEffects.setLoudnormEnabled(loudnormEnabled)
    }

    func toggleNightMode() {
        nightModeEnabled.toggle()
        player.audioEffects.setNightModeEnabled(nightModeEnabled)
    }

    func toggleLimiter() {
        limiterEnabled.toggle()
        player.audioEffects.setLimiterEnabled(limiterEnabled)
    }

    func toggleGate() {
        gateEnabled.toggle()
        player.audioEffects.setGateEnabled(gateEnabled)
    }

    func toggleAutoGain() {
        autoGainEnabled.toggle()
        player.audioEffects.setAutoGainEnabled(autoGainEnabled)
    }

    func toggleSubboost() {
        subboostEnabled.toggle()
        player.audioEffects.setSubboostEnabled(subboostEnabled)
    }

    func toggleMono() {
        monoEnabled.toggle()
        player.audioEffects.setMonoEnabled(monoEnabled)
    }

    func toggleChannelSwap() {
        channelSwapEnabled.toggle()
        player.audioEffects.setChannelSwapEnabled(channelSwapEnabled)
    }

    func toggleChorus() {
        chorusEnabled.toggle()
        player.audioEffects.setChorusEnabled(chorusEnabled)
    }

    func toggleFlanger() {
        flangerEnabled.toggle()
        player.audioEffects.setFlangerEnabled(flangerEnabled)
    }

    func toggleTremolo() {
        tremoloEnabled.toggle()
        player.audioEffects.setTremoloEnabled(tremoloEnabled)
    }

    func toggleVibrato() {
        vibratoEnabled.toggle()
        player.audioEffects.setVibratoEnabled(vibratoEnabled)
    }

    func toggleLoFi() {
        lofiEnabled.toggle()
        player.audioEffects.setLoFiEnabled(lofiEnabled)
    }

    func toggleTelephone() {
        telephoneEnabled.toggle()
        player.audioEffects.setTelephoneEnabled(telephoneEnabled)
    }

    func toggleUnderwater() {
        underwaterEnabled.toggle()
        player.audioEffects.setUnderwaterEnabled(underwaterEnabled)
    }

    func toggleRadio() {
        radioEnabled.toggle()
        player.audioEffects.setRadioEnabled(radioEnabled)
    }

    func resetEffects() {
        player.audioEffects.reset()
        volume = 0; tempo = 1.0; pitch = 0
        bassGain = 0; trebleGain = 0
        surroundLevel = 0; reverbLevel = 0
        stereoWidth = 1.0; channelBalance = 0
        vocalRemoval = 0
        fadeInDuration = 0; delayMs = 0
        loudnormEnabled = false; nightModeEnabled = false
        limiterEnabled = false; gateEnabled = false
        autoGainEnabled = false; subboostEnabled = false
        monoEnabled = false; channelSwapEnabled = false
        chorusEnabled = false; flangerEnabled = false
        tremoloEnabled = false; vibratoEnabled = false
        lofiEnabled = false; telephoneEnabled = false
        underwaterEnabled = false; radioEnabled = false
    }

    // MARK: - A-B 循环

    func setABLoop() {
        guard abPointB > abPointA else { return }
        player.setABLoop(pointA: abPointA, pointB: abPointB)
        abLoopEnabled = true
    }

    func clearABLoop() {
        player.clearABLoop()
        abLoopEnabled = false
    }

    func setPointA() {
        abPointA = currentTime
    }

    func setPointB() {
        abPointB = currentTime
        if abPointB > abPointA {
            setABLoop()
        }
    }

    // MARK: - 歌词

    /// 加载示例歌词（实际使用时从文件或网络获取 LRC）
    func loadLyrics(_ lrcContent: String) {
        player.lyricSyncer.load(lrcContent: lrcContent)
        hasLyrics = player.lyricSyncer.isLoaded
    }

    func clearLyrics() {
        player.lyricSyncer.clear()
        hasLyrics = false
        currentLyricLine = ""
        currentLyricTranslation = nil
        nearbyLyrics = []
    }

    func adjustLyricOffset(_ delta: Double) {
        lyricOffset += delta
    }

    // MARK: - 语音识别歌词

    /// 准备语音识别引擎（下载并加载模型）
    func prepareRecognizer() {
        guard !recognizerReady && !isPreparingRecognizer else { return }
        
        isPreparingRecognizer = true
        recognizedLyricMessage = "正在下载模型（首次需要从网络下载，约 75MB）..."
        
        Task {
            do {
                // 设置超时时间更长，并添加重试逻辑
                try await lyricRecognizer.prepare()
                await MainActor.run {
                    self.recognizerReady = true
                    self.isPreparingRecognizer = false
                    self.recognizedLyricMessage = "识别引擎已就绪"
                }
            } catch {
                await MainActor.run {
                    self.isPreparingRecognizer = false
                    let errorMsg = error.localizedDescription
                    
                    // 针对网络错误给出更友好的提示
                    if errorMsg.contains("超时") || errorMsg.contains("timeout") || errorMsg.contains("timed out") {
                        self.recognizedLyricMessage = "模型下载超时。请检查网络连接后重试。\n提示：首次下载需要从 Hugging Face 获取模型文件（约 75MB），国内网络可能较慢。"
                    } else if errorMsg.contains("网络") || errorMsg.contains("network") || errorMsg.contains("connection") {
                        self.recognizedLyricMessage = "网络连接失败。请检查网络后重试。"
                    } else {
                        self.recognizedLyricMessage = "模型加载失败: \(errorMsg)"
                    }
                }
            }
        }
    }

    /// 识别当前音频的歌词
    func recognizeLyrics() {
        guard !urlText.isEmpty else {
            recognizedLyricMessage = "请先输入音频地址"
            return
        }

        // 如果引擎未就绪，先准备
        if !recognizerReady {
            prepareRecognizer()
            recognizedLyricMessage = "正在准备识别引擎，请稍后重试..."
            return
        }

        isRecognizingLyrics = true
        lyricRecognitionProgress = 0
        recognizedLyricResult = nil
        recognizedLyricMessage = nil

        let url = urlText

        Task {
            do {
                // 配置识别参数
                var config = LyricRecognizerConfig()
                config.onProgress = { [weak self] progress in
                    Task { @MainActor in
                        self?.lyricRecognitionProgress = progress
                    }
                }

                // 执行识别
                let result = try await lyricRecognizer.recognize(url: url, config: config)

                await MainActor.run {
                    self.recognizedLyricResult = result
                    self.isRecognizingLyrics = false
                    self.recognizedLyricMessage = "识别完成！共 \(result.segments.count) 行，耗时 \(String(format: "%.1f", result.processingTime))秒"
                }
            } catch {
                await MainActor.run {
                    self.isRecognizingLyrics = false
                    self.recognizedLyricMessage = "识别失败: \(error.localizedDescription)"
                }
            }
        }
    }

    /// 应用识别结果到歌词同步器
    func applyRecognizedLyrics() {
        guard let result = recognizedLyricResult else { return }

        let lines = result.toLyricLines()
        player.lyricSyncer.load(lines: lines)
        hasLyrics = player.lyricSyncer.isLoaded
        recognizedLyricMessage = "已加载 \(lines.count) 行歌词"
    }

    /// 导出识别结果为 LRC 格式
    func exportRecognizedLyrics() -> String? {
        return recognizedLyricResult?.toEnhancedLRC()
    }

    /// 清理识别引擎资源
    func cleanupLyricRecognizer() {
        lyricRecognizer.cleanup()
        recognizerReady = false
    }

    // MARK: - 音频分析

    func runAnalysis() {
        guard !urlText.isEmpty else {
            return
        }

        isAnalyzing = true
        analysisProgress = 0
        analysisResult = nil
        
        let url = urlText

        Task {
            do {
                // 使用真正的音频解码分析（支持本地文件和流媒体）
                let result = try await AudioAnalyzer.analyzeFile(
                    url: url,
                    maxDuration: 30,  // 分析前 30 秒
                    onProgress: { [weak self] progress in
                        Task { @MainActor in
                            self?.analysisProgress = progress
                        }
                    }
                )
                
                await MainActor.run {
                    self.analysisResult = AnalysisResult(
                        // BPM
                        bpm: result.bpm.bpm,
                        bpmConfidence: result.bpm.confidence,
                        bpmStability: result.bpm.stability,
                        
                        // 响度
                        loudnessLUFS: result.loudness.integratedLUFS,
                        shortTermLUFS: result.loudness.shortTermLUFS,
                        loudnessRange: result.loudness.loudnessRange,
                        
                        // 动态
                        dynamicRange: result.dynamicRange.dynamicRange,
                        drValue: result.dynamicRange.drValue,
                        peakDB: result.dynamicRange.peakLevel,
                        rmsDB: result.dynamicRange.rmsLevel,
                        crestFactor: result.dynamicRange.crestFactor,
                        compressionDesc: result.dynamicRange.compressionDescription,
                        
                        // 频率
                        spectralCentroid: result.frequency.spectralCentroid,
                        dominantFreq: result.frequency.dominantFrequency,
                        lowEnergyRatio: result.frequency.lowEnergyRatio,
                        midEnergyRatio: result.frequency.midEnergyRatio,
                        highEnergyRatio: result.frequency.highEnergyRatio,
                        
                        // 音色
                        brightness: result.timbre.brightness,
                        warmth: result.timbre.warmth,
                        timbreDesc: result.timbre.description,
                        eqSuggestion: result.timbre.eqSuggestion,
                        
                        // 音调
                        pitchNote: result.pitch.noteName,
                        pitchFreq: result.pitch.fundamentalFrequency,
                        
                        // 质量
                        qualityScore: result.clipping.hasSevereClipping ? 60 : 85,
                        qualityGrade: result.clipping.hasSevereClipping ? "一般" : "良好",
                        hasClipping: result.clipping.hasSevereClipping,
                        issues: result.clipping.hasSevereClipping ? ["检测到削波"] : [],
                        
                        // 相位
                        phaseCorrelation: result.phase?.correlation ?? 0,
                        stereoWidth: result.phase?.stereoWidth ?? 0,
                        phaseDescription: result.phase?.description ?? "单声道",
                        
                        // 节拍
                        beatCount: result.beatPositions.count
                    )
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.errorMessage = "分析失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 歌曲识别

    func addToFingerprintDB() {
        guard !waveformSamples.isEmpty else {
            recognitionMessage = "请先播放音频"
            return
        }

        let title = metaTitle ?? "未知歌曲"
        let artist = metaArtist ?? "未知艺术家"

        // 从波形生成简化采样（在主线程获取数据）
        let samples = waveformSamples.flatMap { [$0.positive, $0.negative] }
        let fingerprint = AudioFingerprint.generate(samples: samples, sampleRate: 44100)

        let entry = FingerprintDatabase.Entry(
            id: UUID().uuidString,
            title: title,
            artist: artist,
            fingerprint: fingerprint
        )

        fingerprintDB.add(entry: entry)
        fingerprintDBCount = fingerprintDB.count
        recognitionMessage = "已添加: \(title)"
    }

    func recognizeSong() {
        guard !waveformSamples.isEmpty else {
            recognitionMessage = "请先播放音频"
            return
        }

        guard fingerprintDBCount > 0 else {
            recognitionMessage = "数据库为空，请先添加歌曲"
            return
        }

        isRecognizing = true
        recognitionResult = nil
        recognitionMessage = nil
        
        // 在主线程获取数据
        let samples = waveformSamples.flatMap { [$0.positive, $0.negative] }
        let db = fingerprintDB

        Task.detached { [weak self] in
            guard let self else { return }

            if let result = db.recognize(samples: samples, sampleRate: 44100) {
                await MainActor.run {
                    self.recognitionResult = RecognitionResult(
                        title: result.title,
                        artist: result.artist,
                        score: result.score
                    )
                    self.isRecognizing = false
                }
            } else {
                await MainActor.run {
                    self.recognitionMessage = "未能识别，请尝试其他片段"
                    self.isRecognizing = false
                }
            }
        }
    }

    // MARK: - 元数据

    private func loadMetadata() {
        let url = urlText
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let meta = try self.player.metadataReader.read(url: url)
                await MainActor.run {
                    self.metaTitle = meta.title
                    self.metaArtist = meta.artist
                    self.metaAlbum = meta.album
                    self.artworkData = meta.artworkData
                }
            } catch {
                // 元数据读取失败，静默处理（网络流可能不支持）
            }
        }
    }

    // MARK: - 波形

    private func loadWaveform() {
        let url = urlText
        waveformLoading = true
        waveformSamples = []
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let samples = try await self.player.waveformGenerator.generate(
                    url: url, samplesCount: 150
                )
                await MainActor.run {
                    self.waveformSamples = samples
                    self.waveformLoading = false
                }
            } catch {
                await MainActor.run {
                    self.waveformLoading = false
                }
            }
        }
    }

    // MARK: - 状态更新

    func updateState(_ playbackState: PlaybackState) {
        switch playbackState {
        case .idle:       state = "空闲"
        case .connecting: state = "连接中..."
        case .playing:    state = "播放中"
        case .paused:     state = "已暂停"
        case .stopped:    state = "已停止"
        case .error(let err):
            state = "错误"
            errorMessage = err.description
        }
    }

    func updateStreamInfo(_ info: StreamInfo?) {
        guard let info = info else {
            streamInfoText = ""; hifiInfoText = ""; videoInfoText = ""; hasVideo = false
            return
        }
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sr = info.sampleRate {
            parts.append(sr >= 1000 ? "\(sr / 1000).\(sr % 1000 / 100)kHz" : "\(sr)Hz")
        }
        if let bits = info.bitDepth { parts.append("\(bits)bit") }
        if let ch = info.channelCount {
            parts.append(ch == 1 ? "Mono" : ch == 2 ? "Stereo" : "\(ch)ch")
        }
        streamInfoText = parts.joined(separator: " / ")

        hasVideo = info.hasVideo
        if info.hasVideo {
            var vp: [String] = []
            if let vc = info.videoCodec { vp.append(vc.uppercased()) }
            if let w = info.width, let h = info.height { vp.append("\(w)×\(h)") }
            videoInfoText = vp.joined(separator: " / ")
        } else { videoInfoText = "" }

        hifiInfoText = info.isHiRes ? "Hi-Res 无损" : info.isLossless ? "无损音质" : ""
    }

    // MARK: - 定时器

    private func startTimeUpdater() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = self.player.currentTime
                self.updateStreamInfo(self.player.streamInfo)
            }
        }
    }

    private func stopTimeUpdater() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Delegate Adapter

private final class PlayerDelegateAdapter: StreamPlayerDelegate, AudioEqualizerDelegate {
    weak var viewModel: PlayerViewModel?

    func player(_ player: StreamPlayer, didChangeState state: PlaybackState) {
        Task { @MainActor [weak self] in self?.viewModel?.updateState(state) }
    }
    func player(_ player: StreamPlayer, didEncounterError error: FFmpegError) {
        Task { @MainActor [weak self] in self?.viewModel?.errorMessage = error.description }
    }
    func player(_ player: StreamPlayer, didUpdateDuration duration: TimeInterval) {
        Task { @MainActor [weak self] in self?.viewModel?.duration = duration }
    }
    func playerDidTransitionToNextTrack(_ player: StreamPlayer) {}
    func equalizer(_ eq: AudioEqualizer, didClampGain original: Float, to clamped: Float, for band: EQBand) {
        Task { @MainActor [weak self] in
            self?.viewModel?.clampMessage = "\(band.label)Hz: \(String(format: "%.1f", original)) → \(String(format: "%.1f", clamped)) dB"
        }
    }
}
