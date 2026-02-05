//
//  AudioEQProcessor.swift
//  AsideMusic
//
//  MTAudioProcessingTap 实现 - 对 AVPlayer 音频流进行实时 EQ 处理
//

import AVFoundation
import Accelerate

/// 音频 EQ 处理器
/// 使用 MTAudioProcessingTap 拦截 AVPlayer 音频数据进行实时处理
final class AudioEQProcessor {
    
    // MARK: - Properties
    
    private var filterBank: FilterBank
    private var isEnabled: Bool = true
    private let lock = NSLock()
    
    // 当前采样率
    private var currentSampleRate: Float = 44100
    
    // 智能音频分析器
    let analyzer = AudioAnalyzer()
    
    // 智能降噪器
    let noiseReducer = NoiseReducer()
    
    // 智能模式
    private var smartModeEnabled: Bool = false
    private var lastGenreUpdate: Date = Date.distantPast
    private var lastRecommendedEQ: [Float]?
    
    // MARK: - Init
    
    init(bands: [Float]) {
        self.filterBank = FilterBank(
            frequencies: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
            gains: bands,
            q: 1.41,
            sampleRate: 44100
        )
    }
    
    // MARK: - Public Methods
    
    /// 更新 EQ 频段增益
    func updateBands(_ bands: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        filterBank.updateGains(bands)
    }
    
    /// 设置是否启用 EQ
    func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        isEnabled = enabled
        if !enabled {
            filterBank.reset()
        }
    }
    
    /// 设置智能模式
    func setSmartMode(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        smartModeEnabled = enabled
        
        if enabled {
            // 启用智能模式时，根据分析结果自动调整
            let result = analyzer.currentResult
            if result.needsDenoising {
                noiseReducer.setMode(.adaptive)
                noiseReducer.setEnabled(true)
            }
        } else {
            noiseReducer.setEnabled(false)
        }
    }
    
    /// 设置降噪模式
    func setNoiseReduction(_ mode: NoiseReductionMode) {
        noiseReducer.setMode(mode)
        noiseReducer.setEnabled(mode != .off)
    }
    
    /// 获取当前分析结果
    var analysisResult: AudioAnalysisResult {
        analyzer.currentResult
    }
    
    /// 获取推荐的 EQ 设置
    var recommendedEQ: [Float] {
        analyzer.currentResult.recommendedEQ
    }
    
    /// 为 AVPlayerItem 添加音频处理 Tap
    func attach(to playerItem: AVPlayerItem) {
        guard let track = playerItem.asset.tracks(withMediaType: .audio).first else {
            return
        }
        
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(self).toOpaque(),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )
        
        var tap: Unmanaged<MTAudioProcessingTap>?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )
        
        guard status == noErr, let audioTap = tap else { return }
        
        let params = AVMutableAudioMixInputParameters(track: track)
        params.audioTapProcessor = audioTap.takeRetainedValue()
        
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [params]
        playerItem.audioMix = audioMix
    }
    
    // MARK: - Processing
    
    /// 处理音频数据
    fileprivate func process(
        _ bufferList: UnsafeMutablePointer<AudioBufferList>,
        frameCount: CMItemCount
    ) {
        lock.lock()
        let enabled = isEnabled
        let smartMode = smartModeEnabled
        lock.unlock()
        
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        
        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            
            let floatData = data.assumingMemoryBound(to: Float.self)
            let channelCount = Int(buffer.mNumberChannels)
            let frames = Int(frameCount)
            
            // 0. 智能音频分析 (在所有处理之前，不修改音频)
            analyzer.analyze(floatData, frameCount: frames, channelCount: channelCount)
            
            // 智能模式：自动应用推荐 EQ
            if smartMode {
                let now = Date()
                if now.timeIntervalSince(lastGenreUpdate) > 2.0 {
                    lastGenreUpdate = now
                    let result = analyzer.currentResult
                    
                    // 检查是否需要更新 EQ (仅当检测到明确的音乐类型时)
                    if result.detectedGenre != .unknown {
                        let newEQ = result.recommendedEQ
                        if lastRecommendedEQ == nil || !areEQsEqual(newEQ, lastRecommendedEQ!) {
                            lastRecommendedEQ = newEQ
                            // 通知主线程更新 EQ
                            Task { @MainActor in
                                AudioEQManager.shared.applySmartEQ(newEQ, genre: result.detectedGenre)
                            }
                        }
                    }
                }
            }
            
            // 1. EQ 处理
            if enabled {
                lock.lock()
                filterBank.processBuffer(floatData, frameCount: frames, channelCount: channelCount)
                lock.unlock()
            }
            
            // 2. HiFi 引擎处理
            let hifiEnabled = MainActor.assumeIsolated { HiFiEngine.shared.isEnabled }
            if hifiEnabled, let hifiProcessor = MainActor.assumeIsolated({ HiFiEngine.shared.processor }) {
                hifiProcessor.process(floatData, frameCount: frames, channelCount: channelCount)
            }
        }
    }
    
    private func areEQsEqual(_ a: [Float], _ b: [Float]) -> Bool {
        guard a.count == b.count else { return false }
        for i in 0..<a.count {
            if abs(a[i] - b[i]) > 1.0 { return false }
        }
        return true
    }
    
    /// 更新采样率
    fileprivate func updateSampleRate(_ sampleRate: Float) {
        guard currentSampleRate != sampleRate else { return }
        currentSampleRate = sampleRate
        
        lock.lock()
        filterBank.updateSampleRate(sampleRate)
        lock.unlock()
        
        // 更新分析器采样率
        analyzer.updateSampleRate(sampleRate)
        
        // 更新 HiFi 处理器采样率
        if let hifiProcessor = MainActor.assumeIsolated({ HiFiEngine.shared.processor }) {
            hifiProcessor.updateSampleRate(sampleRate)
        }
        
        print("🎵 EQ: Sample rate updated to \(sampleRate) Hz")
    }
}

// MARK: - MTAudioProcessingTap Callbacks

private func tapInit(
    tap: MTAudioProcessingTap,
    clientInfo: UnsafeMutableRawPointer?,
    tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

private func tapFinalize(tap: MTAudioProcessingTap) {
    // 清理资源
}

private func tapPrepare(
    tap: MTAudioProcessingTap,
    maxFrames: CMItemCount,
    processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    let format = processingFormat.pointee
    print("🎵 EQ Prepare: \(format.mSampleRate) Hz, \(format.mChannelsPerFrame) channels, \(format.mBitsPerChannel) bits")
    
    // 获取处理器并更新采样率
    let storage = MTAudioProcessingTapGetStorage(tap)
    let processor = Unmanaged<AudioEQProcessor>.fromOpaque(storage).takeUnretainedValue()
    processor.updateSampleRate(Float(format.mSampleRate))
}

private func tapUnprepare(tap: MTAudioProcessingTap) {
    // 准备结束
}

private func tapProcess(
    tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    flags: MTAudioProcessingTapFlags,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    // 获取源音频数据
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        flagsOut,
        nil,
        numberFramesOut
    )
    
    guard status == noErr else {
        print("❌ EQ: Failed to get source audio, status: \(status)")
        return
    }
    
    // 获取处理器
    let storage = MTAudioProcessingTapGetStorage(tap)
    let processor = Unmanaged<AudioEQProcessor>.fromOpaque(storage).takeUnretainedValue()
    
    // 处理音频
    processor.process(bufferListInOut, frameCount: numberFramesOut.pointee)
}
