//
//  AriaTensionEngine.swift
//  Monologue
//
//  副歌预判张力系统 —— 先使用歌词引擎的副歌标记，再补充归一化
//  重复句与段落结构识别，据此换算出每段副歌的"命中时刻"，
//  在命中前数秒生成蓄力窗口：张力值 0→1 缓慢抬升，命中瞬间
//  通过 AriaAudioPulse 释放一次大振幅镜头冲击 + 节拍触觉。
//  纯几何计算，逐帧开销可忽略；由歌词时间轴驱动，不新增任何时钟。
//

import Foundation

final class AriaTensionEngine {

    private struct Window {
        let buildStart: Double
        let hitTime: Double
    }

    /// 蓄力提前量：命中前多少秒开始抬升
    private let leadTime: Double = 4.8
    /// 命中后允许触发释放的宽限窗（超过视为 seek 跳过，不补触发）
    private let releaseGrace: Double = 0.9

    private var windows: [Window] = []
    private var releasedWindows: Set<Int> = []
    private var linesSignature: Int = 0
    private var lastTime: Double = -1

    // MARK: - 窗口构建

    /// 从歌词行重建蓄力窗口；行内容未变化时是纯签名比较，可逐帧调用。
    func syncWindows(lines: [AriaLine]) {
        var hasher = Hasher()
        hasher.combine(lines.count)
        hasher.combine(lines.first?.id ?? 0)
        hasher.combine(lines.last?.id ?? 0)
        hasher.combine(lines.first?.startTime ?? 0)
        hasher.combine(lines.last?.endTime ?? 0)
        hasher.combine(lines.first?.fullText ?? "")
        hasher.combine(lines.last?.fullText ?? "")
        let signature = hasher.finalize()
        guard signature != linesSignature else { return }
        linesSignature = signature
        releasedWindows.removeAll()
        lastTime = -1

        let eligible = lines.filter { !$0.isInterlude && !$0.isCredit }
        var normalizedCounts: [String: Int] = [:]
        for line in eligible {
            let key = normalizedText(line.fullText)
            if key.count >= 4 {
                normalizedCounts[key, default: 0] += 1
            }
        }

        var result: [Window] = []
        var previousWasCandidate = false
        for line in eligible {
            let key = normalizedText(line.fullText)
            let repeatedHook = key.count >= 4 && normalizedCounts[key, default: 0] >= 2
            let isCandidate = line.isChorus || repeatedHook
            if isCandidate, !previousWasCandidate {
                appendWindow(hitTime: line.startTime, to: &result)
            }
            previousWasCandidate = isCandidate
        }

        // 没有逐字歌词或副歌句并不完全重复时，旧逻辑会得到零个窗口。
        // 以歌曲中后段的段落入口作为保守兜底，保证功能不会静默失效。
        if result.isEmpty, eligible.count >= 8,
           let first = eligible.first, let last = eligible.last {
            let duration = max(0, last.endTime - first.startTime)
            if duration >= 36 {
                for fraction in [0.38, 0.70] {
                    let target = first.startTime + duration * fraction
                    if let line = eligible.min(by: {
                        abs($0.startTime - target) < abs($1.startTime - target)
                    }) {
                        appendWindow(hitTime: line.startTime, to: &result)
                    }
                }
            }
        }
        windows = result
    }

    private func appendWindow(hitTime: Double, to result: inout [Window]) {
        guard hitTime > 1.4 else { return }
        guard result.last.map({ hitTime - $0.hitTime >= 10 }) ?? true else { return }
        let start = max(0, hitTime - leadTime)
        guard hitTime - start > 1.2 else { return }
        result.append(Window(buildStart: start, hitTime: hitTime))
    }

    private func normalizedText(_ text: String) -> String {
        text.lowercased().unicodeScalars.reduce(into: "") { result, scalar in
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
            }
        }
    }

    /// 歌曲切换后清空全部状态。
    func reset() {
        windows = []
        releasedWindows.removeAll()
        linesSignature = 0
        lastTime = -1
    }

    // MARK: - 逐帧推进

    /// 由歌词时间轴逐帧调用；写入张力并在命中瞬间触发释放。
    func update(time: Double, pulse: AriaAudioPulse) {
        defer { lastTime = time }

        // seek 回退超过 2 秒：允许已释放的副歌重新蓄力/释放
        if lastTime >= 0, time < lastTime - 2 {
            releasedWindows = releasedWindows.filter { index in
                windows.indices.contains(index) && windows[index].hitTime < time
            }
        }

        var build = 0.0
        for (index, window) in windows.enumerated() {
            if time >= window.buildStart, time < window.hitTime {
                let linear = (time - window.buildStart) / max(0.6, window.hitTime - window.buildStart)
                // 保留后段加速，但让前半程也有可感知的镜头与光场收紧。
                build = max(build, pow(min(1, max(0, linear)), 1.32))
            } else if time >= window.hitTime,
                      time <= window.hitTime + releaseGrace,
                      !releasedWindows.contains(index) {
                // 只有真的经历过蓄力（上一帧在窗口内或刚跨过）才释放，
                // 直接 seek 到副歌中间不该有爆点
                if lastTime >= window.buildStart, lastTime < window.hitTime {
                    releasedWindows.insert(index)
                    pulse.triggerTensionRelease(strength: 0.96)
                } else {
                    releasedWindows.insert(index)
                }
            }
        }
        pulse.setExternalTension(build)
    }

    /// 关闭功能或暂停时清零张力（不清除窗口）。
    func clearTension(pulse: AriaAudioPulse) {
        pulse.setExternalTension(0)
    }
}
