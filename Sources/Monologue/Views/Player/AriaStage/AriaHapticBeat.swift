//
//  AriaHapticBeat.swift
//  Monologue
//
//  节拍触觉 Mono Haptic Beat —— 把沉浸舞台实时节拍引擎的命中事件
//  映射到 CoreHaptics 瞬态：低频厚拍 → 钝而重，军鼓/镲类 → 短而锐，
//  accent 拍附加一次轻微回弹。事件源自 AriaAudioPulse 的节拍回调
//  （独立高优队列），不触碰音频线程与渲染主线程。
//

import CoreHaptics
import Foundation
import UIKit

final class AriaHapticBeat {

    private let lock = NSLock()
    private var engine: CHHapticEngine?
    private var engineRunning = false
    private var lastPlayedAt: Double = 0
    private var attachedPulse: AriaAudioPulse?

    /// 两次触觉之间的最小间隔：高速连击时马达来不及归位，叠加只会糊成持续震动
    private let minimumInterval: Double = 0.11

    static let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    // MARK: - 生命周期

    /// 挂接到脉冲引擎；重复调用安全（幂等替换回调）。
    func attach(to pulse: AriaAudioPulse) {
        guard Self.supportsHaptics else { return }
        lock.lock()
        attachedPulse = pulse
        lock.unlock()
        startEngineIfNeeded()
        pulse.setBeatHitHandler { [weak self] hit in
            self?.play(hit)
        }
    }

    /// 解除挂接并停止引擎（离开舞台 / 关闭开关 / 进后台）。
    func detach() {
        lock.lock()
        let pulse = attachedPulse
        attachedPulse = nil
        let engine = self.engine
        self.engine = nil
        engineRunning = false
        lock.unlock()
        pulse?.setBeatHitHandler(nil)
        engine?.stop()
    }

    private func startEngineIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            // 系统随时可能回收引擎（来电/后台/资源紧张），标记后按需重启
            engine.stoppedHandler = { [weak self] _ in
                self?.lock.lock()
                self?.engineRunning = false
                self?.lock.unlock()
            }
            engine.resetHandler = { [weak self] in
                self?.lock.lock()
                self?.engineRunning = false
                self?.lock.unlock()
            }
            self.engine = engine
        } catch {
            AppLogger.warning("[AriaHapticBeat] 触觉引擎创建失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 播放

    private func play(_ hit: AriaAudioPulse.BeatHit) {
        // 省电模式下不值得为触觉唤醒马达
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }

        let now = CACurrentMediaTime()
        lock.lock()
        guard let engine, now - lastPlayedAt >= minimumInterval else {
            lock.unlock()
            return
        }
        lastPlayedAt = now
        let needsStart = !engineRunning
        engineRunning = true
        lock.unlock()

        if needsStart {
            do {
                try engine.start()
            } catch {
                lock.lock()
                engineRunning = false
                lock.unlock()
                return
            }
        }

        // 强度：跟随节拍强度与体量；锐度：高频瞬态占比越高越"脆"
        let intensity = Float(min(1, 0.32 + hit.strength * 0.52 + hit.mass * 0.16))
        let sharpness = Float(min(1, max(0, hit.snap * 0.85 + hit.sharpness * 0.35 - hit.low * 0.22)))

        var events: [CHHapticEvent] = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
        ]
        // 重音拍补一次轻回弹，形成"咚-哒"的双段质感
        if hit.combo == "accent" || hit.combo == "downbeat", hit.strength > 0.62 {
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.42),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: min(1, sharpness + 0.25))
                    ],
                    relativeTime: 0.052
                )
            )
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 单次失败静默；引擎级失效由 stopped/reset handler 兜底重启
        }
    }
}
