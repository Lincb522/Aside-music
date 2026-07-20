import Foundation
import QuartzCore
import Combine
import FFmpegSwiftSDK

/// Aria 沉浸舞台的实时音频视觉引擎（类型名为历史兼容保留）。
///
/// 对应 Mineradio `public/index.html` 中的：
/// - `beatBandRms` / `processRealtimeBeatEngine`（实时节拍引擎：5 频段双包络 + tempo 锁相 + combo 分类）
/// - `scheduleBeatCamera` / `mergeRealtimeBeatCamera` / `updateBeatCamera`（节拍镜头：attack/hold/release 包络）
/// - 渲染主循环的 bass/mid/treble/beatPulse/audioEnergy 包络与动态峰值归一
/// - `updateAriaDynamics` / `cameraDynamicsScale` / `updateAriaTrackProfile`（整曲动态标定）
/// - 歌词阳光溢光 `lyricSunEnergy`（副歌检测）
///
/// 数据源为 StreamPlayer 的 FFT 原始频谱（复刻 WebAudio getByteFrequencyData 语义）。
/// 频谱计算在音频线程完成；镜头包络在主线程 `snapshot()` 中逐帧推进。
final class AriaAudioPulse: ObservableObject {

    struct Snapshot {
        var bass: Double = 0          // uBass
        var mid: Double = 0           // uMid
        var treble: Double = 0        // uTreble
        var energy: Double = 0        // uEnergy
        var beatPulse: Double = 0     // uBeat
        var punch: Double = 0         // beatCam.punch
        var radiusKick: Double = 0    // 镜头 zoom 冲击
        var phiKick: Double = 0       // 镜头俯仰冲击
        var thetaKick: Double = 0     // 镜头偏航冲击
        var rollKick: Double = 0      // 镜头滚转冲击
        var lyricSun: Double = 0      // 副歌溢光 0~1
    }

    // MARK: - Mineradio 状态结构

    /// rtBeat — 实时节拍引擎状态
    private struct RTBeat {
        var subFast = 0.0, subSlow = 0.0, lowFast = 0.0, lowSlow = 0.0
        var bodyFast = 0.0, bodySlow = 0.0, vocalFast = 0.0, vocalSlow = 0.0, snapFast = 0.0, snapSlow = 0.0
        var prevSub = 0.0, prevLow = 0.0, prevBody = 0.0, prevVocal = 0.0, prevSnap = 0.0, prevRms = 0.0
        var onsetAvg = 0.012, onsetPeak = 0.060
        var subPeak = 0.14, lowPeak = 0.18, bodyPeak = 0.16, vocalPeak = 0.16, snapPeak = 0.14
        var lastHitAt = -10.0
        var tempoGap = 0.0
        var tempoConfidence = 0.0
        var beatCount = 0
        var primedFrames = 0
        var pulse = 0.0
    }

    /// beatCam 事件（scheduleBeatCamera 推入）
    private struct BeatCamEvent {
        var start: Double
        var hit: Double
        var amp: Double
        var attack: Double
        var hold: Double
        var release: Double
        var zoomAmp: Double
        var thetaAmp: Double
        var phiAmp: Double
        var rollAmp: Double
        var mode: String
        var combo: String
        var phase: Double
        var low: Double
        var body: Double
        var snap: Double
        var mass: Double
        var source: String
    }

    /// beatCam — 镜头包络状态（常量同 Mineradio）
    private struct BeatCam {
        var events: [BeatCamEvent] = []
        var punch = 0.0
        var lastTriggerAt = -10.0
        var lastRealtimeAt = -10.0
        let realtimeMinInterval = 0.460
        let realtimeMergeWindow = 0.135
        let attack = 0.028
        let hold = 0.030
        let release = 0.185
        var thetaKick = 0.0
        var phiKick = 0.0
        var radiusKick = 0.0
        var rollKick = 0.0
    }

    private struct AriaDynamics {
        var avg = 0.0
        var lowAvg = 0.0
        var peak = 0.30
        var scale = 0.82
    }

    private struct AriaTrackProfile {
        var scale = 1.0
        var target = 1.0
        var frames = 0
        var energyAvg = 0.0
        var lowAvg = 0.0
        var vocalAvg = 0.0
        var melodyAvg = 0.0
        var punchPeak = 0.10
    }

    // MARK: - 内部状态（lock 保护）

    private let lock = NSLock()

    private var rtBeat = RTBeat()
    private var beatCam = BeatCam()
    private var dynamics = AriaDynamics()
    private var trackProfile = AriaTrackProfile()

    // 主循环包络（渲染循环 26644-26806 的变量）
    private var smoothBass = 0.0, smoothMid = 0.0, smoothTreb = 0.0, smoothEnergy = 0.0
    private var bassPeak = 0.030, midPeak = 0.026, treblePeak = 0.018, energyPeak = 0.030
    private var prevEnergy = 0.0
    private var beatPulse = 0.0

    // 歌词阳光溢光
    private var lyricSunAvg = 0.0, lyricSunPeak = 0.48, lyricSunHold = 0.0
    private var lyricSunTarget = 0.0, lyricSunEnergy = 0.0

    private var lastIngestAt = 0.0       // 最近一次频谱帧时间（判定暂停）
    private var lastSnapshotAt = 0.0     // 主线程包络推进时钟
    /// 同一显示帧内背景、歌词、封面可能依次读取快照。缓存极短时间窗内的
    /// 结果，保证各层拿到完全相同的包络，也避免重复加锁和推进镜头状态。
    private var cachedSnapshot = Snapshot()
    private var cachedSnapshotAt = 0.0
    private var isRunning = false
    private var isSuspended = false

    // MARK: - 生命周期

    @MainActor
    func start() {
        guard !isRunning else { return }
        isRunning = true
        isSuspended = false
        resetAll()
        attachAnalyzer()
    }

    @MainActor
    func stop() {
        guard isRunning else { return }
        isRunning = false
        isSuspended = false
        let analyzer = PlayerManager.shared.spectrumAnalyzer
        analyzer.onRawSpectrum = nil
        analyzer.isEnabled = false
        resetAll()
    }

    /// 舞台被系统后台或全屏子页面完全遮挡时，只暂停实时频谱，不清空
    /// 包络状态；重新可见后可以无跳变地继续原有视觉节奏。
    @MainActor
    func suspend() {
        guard isRunning, !isSuspended else { return }
        isSuspended = true
        let analyzer = PlayerManager.shared.spectrumAnalyzer
        analyzer.onRawSpectrum = nil
        analyzer.isEnabled = false
    }

    @MainActor
    func resume() {
        guard isRunning, isSuspended else { return }
        isSuspended = false
        attachAnalyzer()
    }

    /// 切歌时重置整曲标定（对应 resetAriaTrackProfile + resetRealtimeBeatEngine）
    @MainActor
    func resetForNewTrack() {
        lock.lock()
        rtBeat = RTBeat()
        trackProfile = AriaTrackProfile()
        beatCam.events.removeAll()
        cachedSnapshot = Snapshot()
        cachedSnapshotAt = 0
        lock.unlock()
        reattachIfNeeded()
    }

    /// 重新占用频谱分析器：其它消费者（BPM 分析等）可能覆盖过回调或关闭过开关
    @MainActor
    func reattachIfNeeded() {
        guard isRunning, !isSuspended else { return }
        attachAnalyzer()
    }

    @MainActor
    private func attachAnalyzer() {
        let analyzer = PlayerManager.shared.spectrumAnalyzer
        analyzer.onRawSpectrum = { [weak self] magnitudes, sampleRate, rms in
            self?.ingest(magnitudes, sampleRate: sampleRate, rms: Double(rms))
        }
        analyzer.isEnabled = true
    }

    private func resetAll() {
        lock.lock()
        rtBeat = RTBeat()
        beatCam = BeatCam()
        dynamics = AriaDynamics()
        trackProfile = AriaTrackProfile()
        smoothBass = 0; smoothMid = 0; smoothTreb = 0; smoothEnergy = 0
        bassPeak = 0.030; midPeak = 0.026; treblePeak = 0.018; energyPeak = 0.030
        prevEnergy = 0; beatPulse = 0
        lyricSunAvg = 0; lyricSunPeak = 0.48; lyricSunHold = 0; lyricSunTarget = 0; lyricSunEnergy = 0
        lastIngestAt = 0
        lastSnapshotAt = 0
        cachedSnapshot = Snapshot()
        cachedSnapshotAt = 0
        lock.unlock()
    }

    // MARK: - 读取（主线程每帧；同时推进 updateBeatCamera 包络）

    func snapshot() -> Snapshot {
        let now = CACurrentMediaTime()
        lock.lock()
        defer { lock.unlock() }

        // 240Hz 窗口小于当前支持的最短显示帧间隔（120Hz），不会跨帧复用；
        // 只合并同一帧内来自多个 Canvas / TimelineView 的重复读取。
        if cachedSnapshotAt > 0, now - cachedSnapshotAt < 1.0 / 240.0 {
            return cachedSnapshot
        }

        var dt = lastSnapshotAt > 0 ? now - lastSnapshotAt : 0.016
        dt = min(max(dt, 0.001), 0.080)
        lastSnapshotAt = now

        let paused = lastIngestAt == 0 || now - lastIngestAt > 0.30

        if paused {
            // Mineradio 渲染循环暂停分支（26772）
            let f = pow(0.91, dt * 60)
            smoothBass *= f; smoothMid *= f; smoothTreb *= f; smoothEnergy *= f
            beatPulse *= pow(0.82, dt * 60)
            lyricSunTarget = 0
            lyricSunHold *= pow(0.90, dt * 60)
            lyricSunEnergy *= pow(0.92, dt * 60)
            lyricSunAvg *= pow(0.995, dt * 60)
            lyricSunPeak = max(0.48, lyricSunPeak * pow(0.997, dt * 60))
        }

        updateBeatCamera(dt: dt, now: now, paused: paused)

        // 输出（26783-26786，fx.intensity = 1）
        let audioEnergy = max(smoothEnergy, beatPulse * 0.30)
        let bass = min(0.90, smoothBass * 1.05 + beatPulse * 0.18)
        let mid = min(0.72, smoothMid * 1.12)
        let treble = min(0.62, smoothTreb * 1.20)

        let snapshot = Snapshot(
            bass: bass, mid: mid, treble: treble, energy: audioEnergy,
            beatPulse: beatPulse,
            punch: beatCam.punch,
            radiusKick: beatCam.radiusKick,
            phiKick: beatCam.phiKick,
            thetaKick: beatCam.thetaKick,
            rollKick: beatCam.rollKick,
            lyricSun: lyricSunEnergy
        )
        cachedSnapshot = snapshot
        cachedSnapshotAt = now
        return snapshot
    }

    // MARK: - 频谱写入（音频线程） — Mineradio 渲染主循环 26644-26771 的移植

    private func ingest(_ frequencyData: [Float], sampleRate: Double, rms: Double) {
        let now = CACurrentMediaTime()
        lock.lock()
        defer { lock.unlock() }

        var dt = lastIngestAt > 0 ? now - lastIngestAt : 0.046
        dt = min(max(dt, 0.001), 0.080)
        lastIngestAt = now

        let fftSize = Double(frequencyData.count * 2)
        let binHz = sampleRate / fftSize
        let len = frequencyData.count

        // 精确频段（v7.1: 分离 kick 和人声；原始 bin 常量按 44.1k 标定，这里按 Hz 换算）
        let kickEnd = max(1, min(len, Int((150.5 / binHz).rounded())))          // 60-150 Hz kick
        let vocalEnd = max(kickEnd + 1, min(len, Int((3010.0 / binHz).rounded())))  // 200-3000 Hz 人声
        let midEnd = max(vocalEnd + 1, min(len, Int((6020.0 / binHz).rounded())))   // 3-6 kHz 中高乐器

        var bKick = 0.0, mInst = 0.0, tHigh = 0.0, voc = 0.0
        for i in 0..<kickEnd { bKick += Double(frequencyData[i]) }
        for i in kickEnd..<vocalEnd { voc += Double(frequencyData[i]) }
        for i in vocalEnd..<midEnd { mInst += Double(frequencyData[i]) }
        for i in midEnd..<len { tHigh += Double(frequencyData[i]) }
        bKick /= Double(kickEnd)
        voc /= Double(vocalEnd - kickEnd)
        mInst /= Double(max(1, midEnd - vocalEnd))
        tHigh /= Double(max(1, len - midEnd))

        // 动态峰值跟踪
        bassPeak = max(bassPeak * 0.994, bKick, 0.030)
        midPeak = max(midPeak * 0.993, mInst, 0.026)
        treblePeak = max(treblePeak * 0.992, tHigh, 0.018)
        energyPeak = max(energyPeak * 0.995, rms, 0.030)

        let rb = min(1, pow(bKick / max(0.038, bassPeak * 0.66), 0.78))
        let rm = min(1, pow(mInst / max(0.025, midPeak * 0.70), 0.86))
        let rt = min(1, pow(tHigh / max(0.020, treblePeak * 0.74), 0.92))
        let re = min(1, pow(rms / max(0.034, energyPeak * 0.68), 0.82))

        let bassOnset = max(0, rb - smoothBass)
        let energyOnset = max(0, re - prevEnergy)
        prevEnergy = prevEnergy * 0.88 + re * 0.12

        // 实时节拍引擎
        let realtimeBeat = processRealtimeBeatEngine(
            frequencyData: frequencyData, sampleRate: sampleRate, fftSize: fftSize,
            rms: rms, dt: dt, now: now
        )

        if let beat = realtimeBeat, beat.hit {
            // 无预解析 beatmap，始终走 Mineradio 的 live preview 路径（26691-26728）
            let liveKickFrame = beat.low > 0.50 && rb > 0.42 && bassOnset > 0.070 && energyOnset > 0.016
            let liveStrongHit = beat.confidence > 0.76 && beat.strength > 0.70 && beat.score > 0.56 && liveKickFrame
            let liveTempoHit = beat.tempoAssist && beat.confidence > 0.80 && beat.strength > 0.66
                && beat.low > 0.50 && bassOnset > 0.052
            let liveFallbackOk = liveStrongHit || liveTempoHit

            if liveFallbackOk {
                scheduleBeatCamera(beat: beat, now: now)
                let previewPulseScale = 0.68
                let rtPulse = min(0.46, beat.strength * (beat.tempoAssist ? 0.62 : 0.68) * previewPulseScale)
                beatPulse = max(beatPulse, rtPulse)
            }
        } else if bassOnset > 0.075, rb > 0.32, energyOnset > 0.020 {
            beatPulse = max(beatPulse, min(0.12, bassOnset * 0.18))
        }
        beatPulse *= pow(0.36, dt)

        // 包络（不对称 attack/release）
        func env(_ prev: Double, _ next: Double, _ attack: Double, _ release: Double) -> Double {
            let k = next > prev ? attack : release
            return prev + (next - prev) * k
        }
        smoothBass = env(smoothBass, min(0.82, rb * 0.78 + re * 0.025), 0.28, 0.075)
        smoothMid = env(smoothMid, min(0.68, rm * 0.64 + re * 0.025), 0.18, 0.060)
        smoothTreb = env(smoothTreb, min(0.56, rt * 0.54), 0.18, 0.055)
        smoothEnergy = env(smoothEnergy, min(0.72, re), 0.16, 0.055)

        updateAriaDynamics(rawEnergy: re, rawLow: rb)
        updateAriaTrackProfile(energy: re, low: rb, vocal: voc, melody: rm,
                                 lowOnset: bassOnset, energyOnset: energyOnset)

        // 歌词阳光溢光（26757-26771）
        let sunEnergy = clamp01((smoothEnergy - 0.18) / 0.38)
        let sunVoice = clamp01((voc - 0.11) / 0.34)
        let sunMelody = clamp01((smoothMid - 0.16) / 0.27)
        let sunAir = clamp01((smoothTreb - 0.105) / 0.17)
        var sunRaw = clamp01(sunEnergy * 0.36 + sunVoice * 0.18 + sunMelody * 0.26 + sunAir * 0.20)
        sunRaw = sunRaw * sunRaw * (3 - 2 * sunRaw)
        lyricSunAvg += (sunRaw - lyricSunAvg) * 0.006
        lyricSunPeak = max(0.48, max(lyricSunPeak * 0.9985, sunRaw))
        let sunThreshold = max(0.78, max(lyricSunAvg + 0.20, lyricSunPeak * 0.74))
        var sunGate = clamp01((sunRaw - sunThreshold) / max(0.08, 1.0 - sunThreshold))
        sunGate = sunGate * sunGate * (3 - 2 * sunGate)
        lyricSunHold += (sunGate - lyricSunHold) * (sunGate > lyricSunHold ? 0.035 : 0.014)
        lyricSunTarget = lyricSunHold > 0.16 ? clamp01((lyricSunHold - 0.16) / 0.84) : 0
        lyricSunEnergy += (lyricSunTarget - lyricSunEnergy) * (lyricSunTarget > lyricSunEnergy ? 0.075 : 0.030)
    }

    // MARK: - beatBandRms

    private func beatBandRms(_ data: [Float], sampleRate: Double, fftSize: Double, hz0: Double, hz1: Double) -> Double {
        let binHz = sampleRate / fftSize
        let a = max(1, Int(floor(hz0 / binHz)))
        let b = min(data.count - 1, Int(ceil(hz1 / binHz)))
        guard b >= a else { return 0 }
        var sum = 0.0
        for i in a...b {
            let v = Double(data[i])
            sum += v * v
        }
        return sqrt(sum / Double(b - a + 1))
    }

    // MARK: - processRealtimeBeatEngine（4391-4581，非 DJ 路径）

    private struct RealtimeBeat {
        var hit: Bool
        var time: Double = 0
        var strength: Double = 0
        var confidence: Double = 0
        var low: Double = 0
        var body: Double = 0
        var snap: Double = 0
        var mass: Double = 0
        var sharpness: Double = 0
        var tempoAssist: Bool = false
        var combo: String = "downbeat"
        var score: Double = 0
        var lowDominance: Double = 0
    }

    private func processRealtimeBeatEngine(
        frequencyData: [Float], sampleRate: Double, fftSize: Double,
        rms: Double, dt: Double, now: Double
    ) -> RealtimeBeat? {
        let sub = beatBandRms(frequencyData, sampleRate: sampleRate, fftSize: fftSize, hz0: 38, hz1: 74)
        let kick = beatBandRms(frequencyData, sampleRate: sampleRate, fftSize: fftSize, hz0: 52, hz1: 165)
        let body = beatBandRms(frequencyData, sampleRate: sampleRate, fftSize: fftSize, hz0: 165, hz1: 420)
        let vocal = beatBandRms(frequencyData, sampleRate: sampleRate, fftSize: fftSize, hz0: 420, hz1: 2600)
        let snap = beatBandRms(frequencyData, sampleRate: sampleRate, fftSize: fftSize, hz0: 1800, hz1: 9200)
        let low = min(1, kick * 0.86 + sub * 0.42)

        func follow(_ cur: Double, _ next: Double, _ upTau: Double, _ downTau: Double) -> Double {
            let tau = next > cur ? upTau : downTau
            return cur + (next - cur) * (1 - exp(-dt / max(0.001, tau)))
        }
        rtBeat.subFast = follow(rtBeat.subFast, sub, 0.018, 0.064)
        rtBeat.subSlow = follow(rtBeat.subSlow, sub, 0.320, 0.520)
        rtBeat.lowFast = follow(rtBeat.lowFast, low, 0.016, 0.070)
        rtBeat.lowSlow = follow(rtBeat.lowSlow, low, 0.300, 0.540)
        rtBeat.bodyFast = follow(rtBeat.bodyFast, body, 0.020, 0.082)
        rtBeat.bodySlow = follow(rtBeat.bodySlow, body, 0.360, 0.600)
        rtBeat.vocalFast = follow(rtBeat.vocalFast, vocal, 0.026, 0.090)
        rtBeat.vocalSlow = follow(rtBeat.vocalSlow, vocal, 0.340, 0.580)
        rtBeat.snapFast = follow(rtBeat.snapFast, snap, 0.012, 0.060)
        rtBeat.snapSlow = follow(rtBeat.snapSlow, snap, 0.300, 0.520)

        rtBeat.subPeak = max(rtBeat.subPeak * pow(0.990, dt * 60), sub, 0.045)
        rtBeat.lowPeak = max(rtBeat.lowPeak * pow(0.989, dt * 60), low, 0.060)
        rtBeat.bodyPeak = max(rtBeat.bodyPeak * pow(0.990, dt * 60), body, 0.040)
        rtBeat.vocalPeak = max(rtBeat.vocalPeak * pow(0.990, dt * 60), vocal, 0.040)
        rtBeat.snapPeak = max(rtBeat.snapPeak * pow(0.990, dt * 60), snap, 0.035)

        let subFlux = max(0, sub - rtBeat.prevSub)
        let lowFlux = max(0, low - rtBeat.prevLow)
        let bodyFlux = max(0, body - rtBeat.prevBody)
        let vocalFlux = max(0, vocal - rtBeat.prevVocal)
        let snapFlux = max(0, snap - rtBeat.prevSnap)
        let rmsFlux = max(0, rms - rtBeat.prevRms)
        let subRise = max(0, rtBeat.subFast - rtBeat.subSlow)
        let lowRise = max(0, rtBeat.lowFast - rtBeat.lowSlow)
        let bodyRise = max(0, rtBeat.bodyFast - rtBeat.bodySlow)
        let vocalRise = max(0, rtBeat.vocalFast - rtBeat.vocalSlow)
        let snapRise = max(0, rtBeat.snapFast - rtBeat.snapSlow)
        let drumOnset = subRise * 0.88 + subFlux * 0.66 + lowRise * 1.62 + lowFlux * 1.34
        let musicalOnset = bodyRise * 0.34 + bodyFlux * 0.24 + vocalRise * 0.52 + vocalFlux * 0.36
            + snapRise * 0.08 + snapFlux * 0.06 + rmsFlux * 0.20
        let onset = drumOnset + musicalOnset * 0.16

        let avgTau = onset > rtBeat.onsetAvg ? 1.10 : 0.34
        rtBeat.onsetAvg = follow(rtBeat.onsetAvg, onset, avgTau, avgTau)
        rtBeat.onsetPeak = max(rtBeat.onsetPeak * pow(0.988, dt * 60), onset, 0.032)
        let floorVal = rtBeat.onsetAvg * 0.84
        let score = clamp01((onset - floorVal) / max(0.014, rtBeat.onsetPeak - floorVal))
        let subNorm = clamp01(sub / max(0.045, rtBeat.subPeak * 0.70))
        let lowNorm = clamp01(low / max(0.060, rtBeat.lowPeak * 0.72))
        let bodyNorm = clamp01(body / max(0.045, rtBeat.bodyPeak * 0.72))
        let vocalNorm = clamp01(vocal / max(0.045, rtBeat.vocalPeak * 0.72))
        let snapNorm = clamp01(snap / max(0.040, rtBeat.snapPeak * 0.72))

        rtBeat.primedFrames += 1
        let warmingUp = rtBeat.primedFrames < 18
        let gapFromLast = now - rtBeat.lastHitAt
        let expectedGap = rtBeat.tempoGap > 0 ? rtBeat.tempoGap : 0
        let phaseWindow = expectedGap > 0 ? max(0.055, min(0.105, expectedGap * 0.16)) : 0
        let tempoDue = expectedGap > 0 && gapFromLast > expectedGap - phaseWindow && gapFromLast < expectedGap + phaseWindow
        let lowPresence = max(lowNorm, subNorm * 0.74)
        let lowAttack = lowRise + lowFlux * 0.72 + subRise * 0.58 + subFlux * 0.40
        let lowDominance = low / max(0.001, vocal * 0.84 + body * 0.36 + snap * 0.10)
        let lowFluxDominance = (lowFlux + subFlux * 0.58) / max(0.001, vocalFlux * 0.72 + bodyFlux * 0.42 + snapFlux * 0.16)
        let voiceMask = vocalNorm > 0.58 && lowDominance < 0.86 && lowFluxDominance < 1.10
        var drumGate = lowPresence > 0.38 && lowAttack > max(0.014, rtBeat.onsetAvg * 0.34) && !voiceMask
        drumGate = drumGate && (lowDominance > 0.72 || lowFluxDominance > 1.02 || subNorm > 0.56)
        let strongTransient = drumGate && score > 0.54 && drumOnset > rtBeat.onsetAvg * 0.84
        let kickTransient = drumGate && score > 0.40 && lowAttack > max(0.018, rtBeat.onsetAvg * 0.46)
        let tempoAssist = tempoDue && rtBeat.tempoConfidence > 0.42 && drumGate && score > 0.22
            && lowAttack > max(0.016, rtBeat.onsetAvg * 0.34)
        var candidateHit = strongTransient || kickTransient || tempoAssist
        if warmingUp { candidateHit = false }
        let hasTempoLock = expectedGap >= 0.42 && expectedGap <= 0.88 && rtBeat.tempoConfidence > 0.38
        let lockedWindow = hasTempoLock ? max(0.070, min(0.110, expectedGap * 0.16)) : 0
        let gapRaw = now - rtBeat.lastHitAt
        var rhythmAccept = false
        if candidateHit {
            if rtBeat.lastHitAt < 0 {
                rhythmAccept = strongTransient && score > 0.62 && lowPresence > 0.48
            } else if hasTempoLock {
                let oneBeatErr = abs(gapRaw - expectedGap)
                let twoBeatErr = abs(gapRaw - expectedGap * 2)
                rhythmAccept = oneBeatErr <= lockedWindow && (kickTransient || strongTransient)
                rhythmAccept = rhythmAccept || (twoBeatErr <= lockedWindow * 1.35 && strongTransient && score > 0.58)
                rhythmAccept = rhythmAccept || (gapRaw > expectedGap * 1.55 && strongTransient && lowPresence > 0.44)
            } else {
                rhythmAccept = gapRaw >= beatCam.realtimeMinInterval && strongTransient && score > 0.58 && lowPresence > 0.44
            }
        }
        var hit = candidateHit && rhythmAccept
        let minGap = hasTempoLock ? max(0.400, min(0.540, expectedGap * 0.72)) : beatCam.realtimeMinInterval
        if hit, gapRaw < minGap { hit = false }

        rtBeat.prevSub = sub
        rtBeat.prevLow = low
        rtBeat.prevBody = body
        rtBeat.prevVocal = vocal
        rtBeat.prevSnap = snap
        rtBeat.prevRms = rms
        rtBeat.pulse *= pow(0.18, dt)
        rtBeat.tempoConfidence *= pow(0.996, dt * 60)

        if !hit {
            return RealtimeBeat(hit: false, low: lowNorm, body: bodyNorm, snap: snapNorm, score: score)
        }

        if rtBeat.lastHitAt > 0 {
            var gap = now - rtBeat.lastHitAt
            while gap > 0.88 { gap *= 0.5 }
            while gap < 0.42 { gap *= 2.0 }
            if gap >= 0.42, gap <= 0.88 {
                let tempoEase = hasTempoLock ? 0.10 : 0.22
                rtBeat.tempoGap = rtBeat.tempoGap > 0 ? rtBeat.tempoGap * (1 - tempoEase) + gap * tempoEase : gap
                rtBeat.tempoConfidence = min(1, rtBeat.tempoConfidence + (tempoAssist ? 0.04 : 0.18))
            }
        }
        rtBeat.lastHitAt = now
        rtBeat.beatCount += 1
        var strength = clamp01(0.24 + score * 0.36 + lowPresence * 0.34 + min(1.25, lowDominance) * 0.07 + rmsFlux * 0.95)
        if tempoAssist {
            strength = max(strength, 0.48 + rtBeat.tempoConfidence * 0.10 + lowPresence * 0.14)
        }
        let comboSlot = (rtBeat.beatCount - 1) % 4
        var combo = comboSlot == 0 ? "downbeat" : (comboSlot == 1 ? "push" : (comboSlot == 2 ? "drop" : "rebound"))
        if strength > 0.84, comboSlot != 0 { combo = "accent" }
        rtBeat.pulse = max(rtBeat.pulse, strength)

        return RealtimeBeat(
            hit: true,
            time: now,
            strength: strength,
            confidence: clamp01(score * 0.62 + lowPresence * 0.26 + rtBeat.tempoConfidence * 0.12),
            low: max(0.05, lowPresence),
            body: max(0.02, bodyNorm * 0.62),
            snap: max(0.02, snapNorm),
            mass: clamp01(lowPresence * 0.76 + bodyNorm * 0.20),
            sharpness: clamp01(snapNorm * 0.70 + bodyNorm * 0.12),
            tempoAssist: tempoAssist,
            combo: combo,
            score: score,
            lowDominance: lowDominance
        )
    }

    // MARK: - scheduleBeatCamera（4615-4890，live 源 + 非 DJ 路径，preview=true）

    private func scheduleBeatCamera(beat: RealtimeBeat, now: Double) {
        let time = beat.time
        let strength = clamp01(beat.strength)
        let confidence = clamp01(beat.confidence)
        let visualImpact = clamp01(beat.strength * 0.46 + beat.confidence * 0.20 + beat.low * 0.28)
        let trackScale = trackProfile.scale
        if trackScale < 0.50, strength < 0.84, visualImpact < 0.56 { return }

        var lowTone = max(0.0, beat.low)
        var bodyTone = max(0.0, beat.body)
        var snapTone = max(0.0, beat.snap)
        let rawLowTone = lowTone
        let toneSum = max(0.001, lowTone + bodyTone + snapTone)
        lowTone /= toneSum
        bodyTone /= toneSum
        snapTone /= toneSum
        let sharpness = clamp01(beat.sharpness)
        let mass = clamp01(beat.mass)

        var mode = "deep"
        if snapTone > 0.42, snapTone > lowTone * 1.18, snapTone > bodyTone * 1.08 { mode = "snap" }
        else if bodyTone > 0.46, bodyTone > lowTone * 1.12 { mode = "body" }

        var amp = max(0.18, min(0.72, 0.15 + strength * 0.34 + confidence * 0.06 + mass * 0.13 + snapTone * 0.04))
        amp *= 0.78
        if mode == "deep" { amp = min(0.62, amp * 1.12) }
        let dynScale = cameraDynamicsScale(extra: 0.92 + visualImpact * 0.12 + mass * 0.08)
        amp *= dynScale

        let attack = max(0.014, min(0.038, beatCam.attack * (1.18 - sharpness * 0.55)))
        let hold = max(0.014, min(0.052, beatCam.hold * (0.62 + lowTone * 0.55 + bodyTone * 0.25)))
        var release = max(0.110, min(0.255, beatCam.release * (0.76 + mass * 0.56 + bodyTone * 0.18 - sharpness * 0.18)))

        let idx = Int(floor(time * 2.7))
        let combo = beat.combo

        var zoomAmp = 0.070 + mass * 0.190 + (mode == "deep" ? 0.095 : 0.018) + strength * 0.045
        var thetaAmp = 0.00035
        var phiAmp = 0.002 + (mode == "body" ? 0.012 : (mode == "snap" ? 0.005 : 0.002))
        var rollAmp = mode == "snap" ? (0.003 + snapTone * 0.004) : 0.0008
        zoomAmp *= 0.76 + dynScale * 0.28
        phiAmp *= 0.82 + dynScale * 0.20
        rollAmp *= 0.78 + dynScale * 0.24

        // 非 DJ combo 修正（4797-4817）
        switch combo {
        case "downbeat": amp *= 1.10; zoomAmp *= 1.18; phiAmp *= 0.72
        case "push":     amp *= 0.84; zoomAmp *= 0.88; phiAmp *= 0.62
        case "drop":     amp *= 0.96; zoomAmp *= 0.72; phiAmp *= 1.22
        case "rebound":  amp *= 0.74; zoomAmp *= 0.62; phiAmp *= 0.78
        case "accent":   amp *= 1.14; zoomAmp *= 1.08; rollAmp *= 1.35
        default: break
        }

        // 此实现只接收实时预览源，直接应用预览修正。
        let previewTone = clamp01(visualImpact * 0.54 + rawLowTone * 0.22 + confidence * 0.18 + strength * 0.06)
        amp *= 0.72 + previewTone * 0.16
        zoomAmp *= 0.62 + previewTone * 0.18
        phiAmp *= 0.70 + previewTone * 0.12
        thetaAmp *= 0.70 + previewTone * 0.12
        rollAmp *= 0.54 + previewTone * 0.16
        release *= 1.08 + previewTone * 0.08
        amp = max(0.08, min(0.68, amp))

        // live 源最小间隔（4830-4836）
        if time - beatCam.lastRealtimeAt < beatCam.realtimeMinInterval, strength < 0.78 { return }
        beatCam.lastRealtimeAt = time

        // 合并邻近事件（mergeRealtimeBeatCamera，4583-4613）
        if mergeRealtimeBeatCamera(time: time, amp: amp, zoomAmp: zoomAmp, thetaAmp: thetaAmp,
                                   phiAmp: phiAmp, rollAmp: rollAmp, mode: mode,
                                   low: lowTone, body: bodyTone, snap: snapTone, now: now) {
            beatCam.lastTriggerAt = max(beatCam.lastTriggerAt, time)
            return
        }
        beatCam.lastTriggerAt = max(beatCam.lastTriggerAt, time)

        beatCam.events.append(BeatCamEvent(
            start: now - attack * 0.42,
            hit: time,
            amp: amp,
            attack: attack,
            hold: hold,
            release: release,
            zoomAmp: zoomAmp,
            thetaAmp: thetaAmp,
            phiAmp: phiAmp,
            rollAmp: rollAmp,
            mode: mode,
            combo: combo,
            phase: Double(idx) * 2.399963 + (snapTone - lowTone) * 1.4,
            low: lowTone,
            body: bodyTone,
            snap: snapTone,
            mass: mass,
            source: "live"
        ))
        let maxEvents = 8
        if beatCam.events.count > maxEvents {
            beatCam.events.removeFirst(beatCam.events.count - maxEvents)
        }
    }

    private func mergeRealtimeBeatCamera(
        time: Double, amp: Double, zoomAmp: Double, thetaAmp: Double,
        phiAmp: Double, rollAmp: Double, mode: String,
        low: Double, body: Double, snap: Double, now: Double
    ) -> Bool {
        var bestIndex: Int? = nil
        var bestDist = beatCam.realtimeMergeWindow
        for (i, ev) in beatCam.events.enumerated() {
            let dist = abs(ev.hit - time)
            if dist < bestDist {
                bestIndex = i
                bestDist = dist
            }
        }
        guard let i = bestIndex else { return false }
        beatCam.events[i].hit = time
        beatCam.events[i].start = now - beatCam.events[i].attack * 0.42
        beatCam.events[i].amp = min(0.62, max(beatCam.events[i].amp, amp))
        beatCam.events[i].zoomAmp = max(beatCam.events[i].zoomAmp, zoomAmp)
        beatCam.events[i].thetaAmp = max(beatCam.events[i].thetaAmp, thetaAmp)
        beatCam.events[i].phiAmp = max(beatCam.events[i].phiAmp, phiAmp)
        beatCam.events[i].rollAmp = max(beatCam.events[i].rollAmp, rollAmp)
        beatCam.events[i].low = max(beatCam.events[i].low, low)
        beatCam.events[i].body = max(beatCam.events[i].body, body)
        beatCam.events[i].snap = max(beatCam.events[i].snap, snap)
        beatCam.events[i].mode = mode
        beatCam.events[i].source = "hybrid"
        return true
    }

    // MARK: - updateBeatCamera（4893-4988）

    private func updateBeatCamera(dt: Double, now: Double, paused: Bool) {
        if paused {
            beatCam.punch *= pow(0.08, dt)
            beatCam.thetaKick *= pow(0.05, dt)
            beatCam.phiKick *= pow(0.05, dt)
            beatCam.radiusKick *= pow(0.05, dt)
            beatCam.rollKick *= pow(0.05, dt)
            beatCam.events.removeAll()
            return
        }

        func easeBeatCamera(_ x: Double) -> Double {
            let v = min(1, max(0, x))
            return v * v * (3 - 2 * v)
        }

        var punch = 0.0
        let thetaKick = 0.0
        var phiKick = 0.0
        var radiusKick = 0.0
        var rollKick = 0.0
        var leadEvent: BeatCamEvent? = nil
        var leadPunch = 0.0
        var leadVal = 0.0

        var i = beatCam.events.count - 1
        while i >= 0 {
            let ev = beatCam.events[i]
            let local = now - ev.start
            var val = 0.0
            if local < 0 {
                val = 0
            } else if local < ev.attack {
                val = easeBeatCamera(local / ev.attack)
            } else if local < ev.attack + ev.hold {
                val = 1
            } else if local < ev.attack + ev.hold + ev.release {
                let r = (local - ev.attack - ev.hold) / ev.release
                val = 1 - easeBeatCamera(r)
            } else {
                beatCam.events.remove(at: i)
                i -= 1
                continue
            }
            let evPunch = val * ev.amp
            punch = max(punch, evPunch)
            if evPunch > leadPunch {
                leadEvent = ev
                leadPunch = evPunch
                leadVal = val
            }
            i -= 1
        }

        if let lead = leadEvent {
            let sign: Double = sin(lead.phase) >= 0 ? 1 : -1
            let snapFlick = 1.0 - min(1, max(0, leadVal - 0.25) / 0.75)
            switch lead.combo {
            case "downbeat":
                radiusKick = leadPunch * lead.zoomAmp
                phiKick = -leadPunch * 0.0032
            case "push":
                radiusKick = leadPunch * lead.zoomAmp * 0.72
                phiKick = -leadPunch * 0.0014
            case "drop":
                radiusKick = leadPunch * lead.zoomAmp * 0.46
                phiKick = leadPunch * lead.phiAmp * 0.92
            case "rebound":
                radiusKick = leadPunch * lead.zoomAmp * 0.30
                phiKick = -leadPunch * lead.phiAmp * 0.22
            case "accent":
                radiusKick = leadPunch * lead.zoomAmp * 0.90
                phiKick = -leadPunch * 0.0022
                rollKick = sign * leadPunch * lead.rollAmp * (0.45 + snapFlick * 0.30)
            default:
                if lead.mode == "deep" {
                    radiusKick = leadPunch * lead.zoomAmp
                    phiKick = -leadPunch * 0.003
                }
            }
        }

        beatCam.punch += (punch - beatCam.punch) * (punch > beatCam.punch ? 0.72 : 0.38)
        beatCam.thetaKick += (thetaKick - beatCam.thetaKick) * (abs(thetaKick) > abs(beatCam.thetaKick) ? 0.70 : 0.36)
        beatCam.phiKick += (phiKick - beatCam.phiKick) * (abs(phiKick) > abs(beatCam.phiKick) ? 0.70 : 0.36)
        beatCam.radiusKick += (radiusKick - beatCam.radiusKick) * (radiusKick > beatCam.radiusKick ? 0.72 : 0.34)
        beatCam.rollKick += (rollKick - beatCam.rollKick) * (abs(rollKick) > abs(beatCam.rollKick) ? 0.72 : 0.38)
    }

    // MARK: - updateAriaDynamics / cameraDynamicsScale（4116-4150，非 DJ）

    private func updateAriaDynamics(rawEnergy: Double, rawLow: Double) {
        let e = clamp01(rawEnergy)
        let l = clamp01(rawLow)
        let composite = clamp01(e * 0.62 + l * 0.38)
        dynamics.avg += (composite - dynamics.avg) * (composite > dynamics.avg ? 0.010 : 0.004)
        dynamics.lowAvg += (l - dynamics.lowAvg) * (l > dynamics.lowAvg ? 0.012 : 0.005)
        dynamics.peak = max(0.30, max(dynamics.peak * 0.9988, composite))
        let floorVal = max(0.10, dynamics.avg * 0.82)
        let span = max(0.18, dynamics.peak - floorVal)
        var lift = clamp01((composite - floorVal) / span)
        lift = lift * lift * (3 - 2 * lift)
        var target = 0.42 + lift * 0.56 + clamp01((l - dynamics.lowAvg) / 0.36) * 0.12
        if dynamics.avg < 0.18, l < 0.32 { target *= 0.78 }
        if e > 0.48, l > 0.46 { target = max(target, 0.92) }
        target = min(max(target, 0.34), 1.08)
        dynamics.scale += (target - dynamics.scale) * (target > dynamics.scale ? 0.045 : 0.022)
    }

    private func cameraDynamicsScale(extra: Double) -> Double {
        min(max(dynamics.scale * trackProfile.scale * extra, 0.18), 1.18)
    }

    // MARK: - updateAriaTrackProfile（4191-4217，非 DJ）

    private func updateAriaTrackProfile(
        energy: Double, low: Double, vocal: Double, melody: Double,
        lowOnset: Double, energyOnset: Double
    ) {
        trackProfile.frames += 1
        func follow(_ cur: Double, _ next: Double, _ k: Double) -> Double { cur + (next - cur) * k }
        let early = trackProfile.frames < 360
        let k = early ? 0.020 : 0.006
        trackProfile.energyAvg = follow(trackProfile.energyAvg, clamp01(energy), k)
        trackProfile.lowAvg = follow(trackProfile.lowAvg, clamp01(low), k)
        trackProfile.vocalAvg = follow(trackProfile.vocalAvg, clamp01(vocal), k * 0.8)
        trackProfile.melodyAvg = follow(trackProfile.melodyAvg, clamp01(melody), k * 0.8)
        let punchRaw = clamp01(lowOnset * 2.4 + energyOnset * 1.5 + low * 0.16)
        trackProfile.punchPeak = max(0.10, max(trackProfile.punchPeak * 0.9975, punchRaw))
        let lowDrive = clamp01((trackProfile.lowAvg - 0.20) / 0.42)
        let loudDrive = clamp01((trackProfile.energyAvg - 0.18) / 0.40)
        let punchDrive = clamp01((trackProfile.punchPeak - 0.13) / 0.36)
        let vocalSoft = clamp01((trackProfile.vocalAvg * 0.72 + trackProfile.melodyAvg * 0.42
            - trackProfile.lowAvg * 0.34 - 0.08) / 0.42)
        let quietSoft = clamp01((0.24 - trackProfile.energyAvg) / 0.18)
        var target = 0.54 + lowDrive * 0.28 + loudDrive * 0.22 + punchDrive * 0.34 - vocalSoft * 0.34 - quietSoft * 0.18
        target = min(max(target, 0.28), 1.12)
        trackProfile.target = target
        trackProfile.scale += (target - trackProfile.scale) * (target > trackProfile.scale ? 0.030 : 0.045)
    }

    // MARK: - 工具

    private func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
}
