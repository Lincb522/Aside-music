import Combine
import Foundation
import FFmpegSwiftSDK

struct MonoAudioMeterSnapshot: Sendable {
    var inputRMSDBFS: Float = -80
    var momentaryLUFS: Float = -70
    var shortTermLUFS: Float = -70
    var integratedLUFS: Float = -70
    var samplePeakDBFS: Float = -80
    var estimatedTruePeakDBTP: Float = -80
    var phaseCorrelation: Float = 1
    var monoCompatibility: Float = 1
    var stereoWidth: Float = 0
    var clippingRatio: Float = 0
}

struct MonoDSPChainSnapshot: Sendable {
    let mode: GraphicEQMode
    let userCurve: [Float]
    let deviceCurve: [Float]
    let adaptiveCurve: [Float]
    let combinedCurve: [Float]
    let preampDB: Float
    let loudnessGainDB: Float
    let deviceName: String
    let activeStages: [String]
    let estimatedHeadroomDB: Float
}

private final class MonoMonitorAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var energySum: Double = 0
    private var sampleCount: Int = 0
    private var shortEnergy: Double = 0
    private var momentaryEnergy: Double = 0
    private var peak: Float = 0
    private var clipped: Int = 0
    private var stereoPairs: Int = 0
    private var sumLR: Double = 0
    private var sumLL: Double = 0
    private var sumRR: Double = 0
    private var midEnergy: Double = 0
    private var sideEnergy: Double = 0
    private var lastPublishUptime: TimeInterval = 0

    func ingest(left: [Float], right: [Float]?, sampleRate: Double) -> MonoAudioMeterSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        let count = min(left.count, right?.count ?? left.count)
        guard count > 0 else { return nil }
        var blockEnergy: Double = 0
        var blockPeak: Float = 0

        for index in 0..<count {
            let l = left[index]
            let r = right?[index] ?? l
            guard l.isFinite, r.isFinite else { continue }
            let l2 = Double(l * l)
            let r2 = Double(r * r)
            blockEnergy += (l2 + r2) * 0.5
            blockPeak = max(blockPeak, abs(l), abs(r))
            if abs(l) >= 0.999 { clipped += 1 }
            if right != nil, abs(r) >= 0.999 { clipped += 1 }
            if right != nil {
                stereoPairs += 1
                sumLR += Double(l * r)
                sumLL += l2
                sumRR += r2
                let mid = Double((l + r) * 0.5)
                let side = Double((l - r) * 0.5)
                midEnergy += mid * mid
                sideEnergy += side * side
            }
        }

        let blockMean = blockEnergy / Double(max(count, 1))
        energySum += blockEnergy
        sampleCount += count
        peak = max(peak, blockPeak)
        let blockDuration = Double(count) / max(1, sampleRate)
        let momentaryAlpha = 1 - exp(-blockDuration / 0.4)
        let shortAlpha = 1 - exp(-blockDuration / 3)
        momentaryEnergy += (blockMean - momentaryEnergy) * momentaryAlpha
        shortEnergy += (blockMean - shortEnergy) * shortAlpha

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPublishUptime >= 0.12 else { return nil }
        lastPublishUptime = now
        let integratedEnergy = energySum / Double(max(sampleCount, 1))
        let correlation = sumLR / sqrt(max(sumLL * sumRR, 0.000_000_000_1))
        let totalStereoEnergy = max(midEnergy + sideEnergy, 0.000_000_000_1)
        let channelMultiplier = right == nil ? 1 : 2
        return MonoAudioMeterSnapshot(
            inputRMSDBFS: Self.db(sqrt(blockMean)),
            momentaryLUFS: Self.lufs(momentaryEnergy),
            shortTermLUFS: Self.lufs(shortEnergy),
            integratedLUFS: Self.lufs(integratedEnergy),
            samplePeakDBFS: Self.db(Double(peak)),
            estimatedTruePeakDBTP: Self.db(Double(min(2, blockPeak * 1.015))),
            phaseCorrelation: Float(min(1, max(-1, correlation))),
            monoCompatibility: Float(min(1, max(0, midEnergy / totalStereoEnergy))),
            stereoWidth: Float(min(2, max(0, sqrt(sideEnergy / max(midEnergy, 0.000_000_000_1))))),
            clippingRatio: Float(clipped) / Float(max(sampleCount * channelMultiplier, 1))
        )
    }

    func reset() {
        lock.lock()
        energySum = 0
        sampleCount = 0
        shortEnergy = 0
        momentaryEnergy = 0
        peak = 0
        clipped = 0
        stereoPairs = 0
        sumLR = 0
        sumLL = 0
        sumRR = 0
        midEnergy = 0
        sideEnergy = 0
        lastPublishUptime = 0
        lock.unlock()
    }

    private static func db(_ amplitude: Double) -> Float {
        Float(20 * log10(max(amplitude, 0.000_1)))
    }

    private static func lufs(_ meanSquare: Double) -> Float {
        Float(-0.691 + 10 * log10(max(meanSquare, 0.000_000_1)))
    }
}

@MainActor
final class MonoAudioMonitorEngine: ObservableObject {
    static let shared = MonoAudioMonitorEngine()

    @Published private(set) var inputSpectrum: [Float] = []
    @Published private(set) var outputSpectrum: [Float] = []
    @Published private(set) var meters = MonoAudioMeterSnapshot()
    @Published private(set) var isMonitoring = false
    @Published private(set) var chain = MonoAudioMonitorEngine.makeChainSnapshot()

    private let accumulator = MonoMonitorAccumulator()
    private var inputSpectrumToken: UUID?
    private var outputSpectrumToken: UUID?
    private var pcmToken: UUID?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        EQManager.shared.objectWillChange
            .debounce(for: .milliseconds(80), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.chain = Self.makeChainSnapshot()
            }
            .store(in: &cancellables)

        PlayerManager.shared.$currentSong
            .sink { [weak self] _ in
                self?.accumulator.reset()
                self?.meters = MonoAudioMeterSnapshot()
                self?.chain = Self.makeChainSnapshot()
            }
            .store(in: &cancellables)
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        let player = PlayerManager.shared
        inputSpectrumToken = player.analysisSpectrumAnalyzer.addAnalysisObserver(minimumInterval: 0.08) { [weak self] values, _, _ in
            let displayValues = Self.downsample(values)
            Task { @MainActor in self?.inputSpectrum = displayValues }
        }
        outputSpectrumToken = player.spectrumAnalyzer.addAnalysisObserver(minimumInterval: 0.08) { [weak self] values, _, _ in
            let displayValues = Self.downsample(values)
            Task { @MainActor in self?.outputSpectrum = displayValues }
        }
        pcmToken = player.analysisSpectrumAnalyzer.addPCMAnalysisObserver(minimumInterval: 0.08) { [weak self] left, right, sampleRate in
            guard let self, let snapshot = self.accumulator.ingest(left: left, right: right, sampleRate: sampleRate) else { return }
            Task { @MainActor in self.meters = snapshot }
        }
        chain = Self.makeChainSnapshot()
    }

    nonisolated private static func downsample(_ source: [Float], targetCount: Int = 96) -> [Float] {
        guard source.count > targetCount else { return source }
        let stride = Double(source.count) / Double(targetCount)
        return (0..<targetCount).map { outputIndex in
            let start = Int(Double(outputIndex) * stride)
            let end = min(source.count, max(start + 1, Int(Double(outputIndex + 1) * stride)))
            return source[start..<end].max() ?? 0
        }
    }

    func stop() {
        guard isMonitoring else { return }
        let player = PlayerManager.shared
        if let inputSpectrumToken { player.analysisSpectrumAnalyzer.removeAnalysisObserver(inputSpectrumToken) }
        if let outputSpectrumToken { player.spectrumAnalyzer.removeAnalysisObserver(outputSpectrumToken) }
        if let pcmToken { player.analysisSpectrumAnalyzer.removePCMAnalysisObserver(pcmToken) }
        self.inputSpectrumToken = nil
        self.outputSpectrumToken = nil
        self.pcmToken = nil
        isMonitoring = false
    }

    func resetMeters() {
        accumulator.reset()
        meters = MonoAudioMeterSnapshot()
    }

    private static func makeChainSnapshot() -> MonoDSPChainSnapshot {
        let manager = EQManager.shared
        let mode = manager.graphicEQMode
        let user = manager.currentPreset?.gains(in: mode) ?? mode.normalizedGains(manager.customGains)
        let selectedProfile = manager.headphoneProfiles.first { $0.id == manager.selectedHeadphoneProfileID }
        let profileMode: GraphicEQMode = selectedProfile?.gains.count == GraphicEQMode.thirtyTwoBand.bandCount
            ? .thirtyTwoBand
            : .tenBand
        let deviceBase = manager.isOutputCalibrationEnabled
            ? mode.resampledGains(manager.currentOutputKind.defaultCalibration, from: .tenBand)
            : Array(repeating: 0, count: mode.bandCount)
        let profileCurve = selectedProfile.map { mode.resampledGains($0.gains, from: profileMode) }
            ?? Array(repeating: 0, count: mode.bandCount)
        let device = zip(deviceBase, profileCurve).map { min(6, max(-6, $0 + $1)) }
        let adaptive = mode.resampledGains(manager.effectiveAdaptiveGains, from: .tenBand)
        let combined = mode.centerFrequencies.indices.map { index in
            (user.indices.contains(index) ? user[index] : 0)
                + (device.indices.contains(index) ? device[index] : 0)
                + (adaptive.indices.contains(index) ? adaptive[index] : 0)
        }
        var stages: [String] = []
        if manager.isOutputCalibrationEnabled { stages.append(String(localized: "sound_chain_device")) }
        stages.append(String(localized: "sound_chain_equalizer"))
        if manager.isParametricEQEnabled { stages.append(String(localized: "sound_chain_parametric")) }
        if manager.isDynamicEQEnabled { stages.append(String(localized: "sound_chain_dynamic")) }
        if manager.isMultibandDynamicsEnabled { stages.append(String(localized: "sound_chain_multiband")) }
        if manager.isEnvironmentCompensationEnabled {
            stages.append(String(localized: "sound_chain_environment"))
        }
        if abs(manager.trackLoudnessGainDB) > 0.05 { stages.append(String(localized: "sound_chain_loudness")) }
        stages.append(String(localized: "sound_chain_limiter"))
        let peak = combined.max() ?? 0
        return MonoDSPChainSnapshot(
            mode: mode,
            userCurve: user,
            deviceCurve: device,
            adaptiveCurve: adaptive,
            combinedCurve: combined,
            preampDB: manager.preampDB,
            loudnessGainDB: manager.trackLoudnessGainDB,
            deviceName: manager.currentOutputName.isEmpty ? manager.currentOutputKind.title : manager.currentOutputName,
            activeStages: stages,
            estimatedHeadroomDB: max(0, -(manager.preampDB + peak))
        )
    }
}
