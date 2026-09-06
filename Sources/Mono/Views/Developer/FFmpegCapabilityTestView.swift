import FFmpegSwiftSDK
import SwiftUI

private enum FFmpegLiveLabGroup: String, CaseIterable, Identifiable, Sendable {
    case dynamics
    case frequency
    case spatial
    case time
    case effects
    case repair

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dynamics: return "动态"
        case .frequency: return "频率"
        case .spatial: return "空间"
        case .time: return "时间"
        case .effects: return "特效"
        case .repair: return "修复"
        }
    }
}

private struct FFmpegLiveLabParameter: Identifiable, Sendable {
    let id: String
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let initialValue: Double
    let unit: String

    func formatted(_ value: Double) -> String {
        let number: String
        if step >= 1 {
            number = String(Int(value.rounded()))
        } else if step >= 0.1 {
            number = String(format: "%.1f", value)
        } else {
            number = String(format: "%.2f", value)
        }
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

private struct FFmpegLiveLabEffect: Identifiable, Sendable {
    let kind: AudioEffectsDiagnosticKind
    let group: FFmpegLiveLabGroup
    let title: String
    let filterNames: [String]
    let parameters: [FFmpegLiveLabParameter]

    var id: String { kind.rawValue }
    var filterLabel: String { filterNames.joined(separator: " + ") }
}

private enum FFmpegLiveLabCatalog {
    private static func parameter(
        _ id: String,
        _ title: String,
        _ range: ClosedRange<Double>,
        _ initialValue: Double,
        step: Double = 0.1,
        unit: String = ""
    ) -> FFmpegLiveLabParameter {
        FFmpegLiveLabParameter(
            id: id,
            title: title,
            range: range,
            step: step,
            initialValue: initialValue,
            unit: unit
        )
    }

    static let effects: [FFmpegLiveLabEffect] = [
        .init(kind: .volume, group: .dynamics, title: "音量增益", filterNames: ["volume"], parameters: [
            parameter("gain", "增益", -12...12, 3, unit: "dB")
        ]),
        .init(kind: .loudness, group: .dynamics, title: "响度标准化", filterNames: ["loudnorm"], parameters: [
            parameter("lufs", "目标响度", -24 ... -6, -14, unit: "LUFS"),
            parameter("lra", "响度范围", 1...20, 7, step: 1, unit: "LRA"),
            parameter("peak", "真峰值", -6 ... -0.1, -1, unit: "dBTP")
        ]),
        .init(kind: .compressor, group: .dynamics, title: "动态压缩", filterNames: ["acompressor"], parameters: [
            parameter("threshold", "阈值", -60...0, -20, unit: "dB"),
            parameter("ratio", "压缩比", 1...20, 4),
            parameter("attack", "启动", 0.1...200, 5, unit: "ms"),
            parameter("release", "释放", 10...1000, 50, step: 1, unit: "ms"),
            parameter("makeup", "补偿", -6...12, 2, unit: "dB")
        ]),
        .init(kind: .limiter, group: .dynamics, title: "峰值限幅", filterNames: ["alimiter"], parameters: [
            parameter("limit", "上限", -12 ... -0.1, -1, unit: "dBFS")
        ]),
        .init(kind: .noiseGate, group: .dynamics, title: "噪声门", filterNames: ["agate"], parameters: [
            parameter("threshold", "阈值", -80...0, -40, unit: "dB")
        ]),
        .init(kind: .autoGain, group: .dynamics, title: "自动增益", filterNames: ["dynaudnorm"], parameters: []),
        .init(kind: .dynamicNormalize, group: .dynamics, title: "动态标准化", filterNames: ["dynaudnorm"], parameters: [
            parameter("frame", "帧长度", 100...1000, 500, step: 10, unit: "ms"),
            parameter("window", "窗口", 3...101, 31, step: 2),
            parameter("peak", "目标峰值", 0.5...1, 0.95, step: 0.01)
        ]),
        .init(kind: .speechNormalize, group: .dynamics, title: "人声标准化", filterNames: ["speechnorm"], parameters: []),
        .init(kind: .compand, group: .dynamics, title: "压缩扩展", filterNames: ["compand"], parameters: []),

        .init(kind: .bass, group: .frequency, title: "低音", filterNames: ["bass"], parameters: [
            parameter("gain", "增益", -12...12, 4, unit: "dB")
        ]),
        .init(kind: .treble, group: .frequency, title: "高音", filterNames: ["treble"], parameters: [
            parameter("gain", "增益", -12...12, 4, unit: "dB")
        ]),
        .init(kind: .subBass, group: .frequency, title: "超低音", filterNames: ["asubboost"], parameters: [
            parameter("gain", "增益", 0...12, 6, unit: "dB"),
            parameter("cutoff", "截止频率", 35...250, 100, step: 1, unit: "Hz")
        ]),
        .init(kind: .bandPass, group: .frequency, title: "带通", filterNames: ["bandpass"], parameters: [
            parameter("frequency", "中心频率", 40...16000, 1000, step: 10, unit: "Hz"),
            parameter("width", "带宽", 20...8000, 2000, step: 10, unit: "Hz")
        ]),
        .init(kind: .bandReject, group: .frequency, title: "带阻", filterNames: ["bandreject"], parameters: [
            parameter("frequency", "中心频率", 40...16000, 1000, step: 10, unit: "Hz"),
            parameter("width", "带宽", 20...4000, 200, step: 10, unit: "Hz")
        ]),
        .init(kind: .exciter, group: .frequency, title: "高频激励", filterNames: ["aexciter"], parameters: [
            parameter("amount", "激励量", 0...10, 3, unit: "dB"),
            parameter("frequency", "起始频率", 2000...16000, 7500, step: 100, unit: "Hz")
        ]),
        .init(kind: .virtualBass, group: .frequency, title: "虚拟低音", filterNames: ["virtualbass"], parameters: [
            parameter("cutoff", "截止频率", 60...500, 250, step: 5, unit: "Hz"),
            parameter("strength", "强度", 0...10, 3)
        ]),

        .init(kind: .surround, group: .spatial, title: "环绕", filterNames: ["stereotools"], parameters: [
            parameter("level", "强度", 0...1, 0.45, step: 0.01)
        ]),
        .init(kind: .reverb, group: .spatial, title: "混响", filterNames: ["aecho"], parameters: [
            parameter("level", "强度", 0...1, 0.3, step: 0.01)
        ]),
        .init(kind: .stereoWidth, group: .spatial, title: "立体声宽度", filterNames: ["stereotools"], parameters: [
            parameter("width", "宽度", 0...2, 1.4, step: 0.01)
        ]),
        .init(kind: .channelBalance, group: .spatial, title: "声道平衡", filterNames: ["pan"], parameters: [
            parameter("balance", "平衡", -1...1, 0, step: 0.01)
        ]),
        .init(kind: .mono, group: .spatial, title: "单声道", filterNames: ["pan"], parameters: []),
        .init(kind: .channelSwap, group: .spatial, title: "声道交换", filterNames: ["pan"], parameters: []),
        .init(kind: .bs2b, group: .spatial, title: "双耳交叉馈送", filterNames: ["bs2b"], parameters: [
            parameter("cutoff", "截止频率", 300...2000, 700, step: 10, unit: "Hz"),
            parameter("feed", "馈送", 0...150, 50, step: 1)
        ]),
        .init(kind: .crossfeed, group: .spatial, title: "耳机交叉馈送", filterNames: ["stereotools"], parameters: [
            parameter("strength", "强度", 0...1, 0.3, step: 0.01)
        ]),
        .init(kind: .haas, group: .spatial, title: "Haas 空间", filterNames: ["haas"], parameters: [
            parameter("delay", "延迟", 0...40, 20, unit: "ms")
        ]),

        .init(kind: .tempo, group: .time, title: "播放速度", filterNames: ["atempo"], parameters: [
            parameter("rate", "倍率", 0.5...2, 1, step: 0.01, unit: "×")
        ]),
        .init(kind: .pitch, group: .time, title: "音调", filterNames: ["asetrate", "atempo"], parameters: [
            parameter("semitone", "半音", -12...12, 0, unit: "st")
        ]),
        .init(kind: .fadeIn, group: .time, title: "淡入", filterNames: ["afade"], parameters: [
            parameter("duration", "时长", 0.2...10, 3, unit: "s")
        ]),
        .init(kind: .fadeOut, group: .time, title: "淡出", filterNames: ["afade"], parameters: [
            parameter("duration", "时长", 0.2...10, 3, unit: "s"),
            parameter("start", "开始时间", 0...600, 0, step: 1, unit: "s")
        ]),
        .init(kind: .delay, group: .time, title: "声道延迟", filterNames: ["adelay"], parameters: [
            parameter("delay", "延迟", 0...250, 20, step: 1, unit: "ms")
        ]),

        .init(kind: .vocalRemoval, group: .effects, title: "人声消除", filterNames: ["pan"], parameters: [
            parameter("level", "强度", 0...1, 0.7, step: 0.01)
        ]),
        .init(kind: .dialogueEnhance, group: .effects, title: "人声增强", filterNames: ["dialoguenhance"], parameters: [
            parameter("original", "原声", 0...2, 1, step: 0.05),
            parameter("enhance", "增强", 0...3, 1, step: 0.05)
        ]),
        .init(kind: .chorus, group: .effects, title: "合唱", filterNames: ["chorus"], parameters: [
            parameter("depth", "深度", 0...1, 0.5, step: 0.01)
        ]),
        .init(kind: .flanger, group: .effects, title: "镶边", filterNames: ["flanger"], parameters: [
            parameter("depth", "深度", 0...1, 0.5, step: 0.01)
        ]),
        .init(kind: .tremolo, group: .effects, title: "振幅颤音", filterNames: ["tremolo"], parameters: [
            parameter("frequency", "频率", 0.1...20, 5, unit: "Hz"),
            parameter("depth", "深度", 0...1, 0.5, step: 0.01)
        ]),
        .init(kind: .vibrato, group: .effects, title: "音高颤音", filterNames: ["vibrato"], parameters: [
            parameter("frequency", "频率", 0.1...20, 5, unit: "Hz"),
            parameter("depth", "深度", 0...1, 0.5, step: 0.01)
        ]),
        .init(kind: .loFi, group: .effects, title: "位深压缩", filterNames: ["acrusher"], parameters: [
            parameter("bits", "位深", 1...16, 8, step: 1, unit: "bit"),
            parameter("samples", "降采样", 1...16, 4, step: 1)
        ]),
        .init(kind: .telephone, group: .effects, title: "电话", filterNames: ["bandpass"], parameters: []),
        .init(kind: .underwater, group: .effects, title: "水下", filterNames: ["lowpass", "aecho"], parameters: []),
        .init(kind: .radio, group: .effects, title: "收音机", filterNames: ["bandpass", "acompressor"], parameters: []),
        .init(kind: .softclip, group: .effects, title: "软削波", filterNames: ["asoftclip"], parameters: [
            parameter("type", "曲线", 0...7, 0, step: 1)
        ]),

        .init(kind: .fftDenoise, group: .repair, title: "FFT 降噪", filterNames: ["afftdn"], parameters: [
            parameter("amount", "降噪量", 0...100, 10, step: 1, unit: "dB")
        ]),
        .init(kind: .declick, group: .repair, title: "脉冲修复", filterNames: ["adeclick"], parameters: []),
        .init(kind: .declip, group: .repair, title: "削波修复", filterNames: ["adeclip"], parameters: [])
    ]
}

@MainActor
private final class FFmpegLiveLabViewModel: ObservableObject {
    @Published private(set) var selectedEffect: FFmpegLiveLabEffect
    @Published private(set) var values: [Double]
    @Published private(set) var runtimeSnapshot: FFmpegRuntimeSnapshot?
    @Published private(set) var isApplying = false
    @Published private(set) var isEffectEnabled = false

    private var session: AudioEffectsDiagnosticSession?
    private var applyTask: Task<Void, Never>?
    private var applyGeneration = 0

    init() {
        let first = FFmpegLiveLabCatalog.effects[0]
        selectedEffect = first
        values = first.parameters.map(\.initialValue)
    }

    var allEffects: [FFmpegLiveLabEffect] { FFmpegLiveLabCatalog.effects }

    func effects(in group: FFmpegLiveLabGroup) -> [FFmpegLiveLabEffect] {
        allEffects.filter { $0.group == group }
    }

    func start(audioEffects: AudioEffects) {
        guard session == nil else { return }
        session = audioEffects.beginDiagnosticSession()
        applyNow()
        loadRuntimeSnapshot()
    }

    func stop() {
        applyGeneration += 1
        applyTask?.cancel()
        applyTask = nil
        session?.restoreAsynchronously()
        session = nil
        isApplying = false
    }

    func select(_ effect: FFmpegLiveLabEffect) {
        guard selectedEffect.id != effect.id else { return }
        applyGeneration += 1
        applyTask?.cancel()
        selectedEffect = effect
        values = effect.parameters.map(\.initialValue)
        isEffectEnabled = false
        applyNow()
    }

    func setEffectEnabled(_ enabled: Bool) {
        guard isSupported(selectedEffect) else { return }
        isEffectEnabled = enabled
        scheduleApply(delayNanoseconds: 0)
    }

    func updateValue(_ value: Double, at index: Int) {
        guard selectedEffect.parameters.indices.contains(index) else { return }
        synchronizeValuesForSelectedEffect()
        guard values.indices.contains(index) else { return }
        values[index] = value
        guard isEffectEnabled else { return }
        scheduleApply(delayNanoseconds: 130_000_000)
    }

    func parameterValue(_ parameter: FFmpegLiveLabParameter) -> Double {
        guard let index = selectedEffect.parameters.firstIndex(where: { $0.id == parameter.id }) else {
            return parameter.initialValue
        }
        return values.indices.contains(index) ? values[index] : parameter.initialValue
    }

    func updateValue(_ value: Double, for parameter: FFmpegLiveLabParameter) {
        guard let index = selectedEffect.parameters.firstIndex(where: { $0.id == parameter.id }) else { return }
        updateValue(value, at: index)
    }

    func resetParameters() {
        values = selectedEffect.parameters.map(\.initialValue)
        guard isEffectEnabled else { return }
        scheduleApply(delayNanoseconds: 0)
    }

    func isSupported(_ effect: FFmpegLiveLabEffect) -> Bool {
        guard let runtimeSnapshot else { return true }
        let available = Set(runtimeSnapshot.filters)
        return effect.filterNames.allSatisfy(available.contains)
    }

    private func scheduleApply(delayNanoseconds: UInt64) {
        applyTask?.cancel()
        isApplying = true
        applyTask = Task { @MainActor [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            self?.applyNow()
        }
    }

    private func applyNow() {
        applyTask?.cancel()
        applyTask = nil
        synchronizeValuesForSelectedEffect()
        guard let session else {
            isApplying = false
            return
        }
        applyGeneration += 1
        let generation = applyGeneration
        let effect = selectedEffect.kind
        let requestedValues = values.map(Float.init)
        let enabled = isEffectEnabled
        isApplying = true
        applyTask = Task.detached(priority: .utility) { [weak self] in
            guard !Task.isCancelled else { return }
            session.apply(effect, values: requestedValues, enabled: enabled)
            await MainActor.run {
                guard let self, self.applyGeneration == generation else { return }
                self.applyTask = nil
                self.isApplying = false
            }
        }
    }

    private func synchronizeValuesForSelectedEffect() {
        let parameters = selectedEffect.parameters
        guard values.count != parameters.count else { return }
        values = parameters.enumerated().map { index, parameter in
            values.indices.contains(index) ? values[index] : parameter.initialValue
        }
    }

    private func loadRuntimeSnapshot() {
        Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                FFmpegRuntimeInspector.inspect()
            }.value
            self?.runtimeSnapshot = snapshot
        }
    }
}

@MainActor
struct FFmpegCapabilityTestView: View {
    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var model = FFmpegLiveLabViewModel()
    @State private var selectedGroup: FFmpegLiveLabGroup = .dynamics

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DeveloperDiagnosticBackdrop()

                if geometry.size.width >= 760 {
                    wideWorkspace(width: geometry.size.width)
                } else {
                    compactWorkspace(width: geometry.size.width)
                }
            }
        }
        .developerDiagnosticPageChrome(title: "实时音频实验台")
        .onAppear {
            model.start(audioEffects: player.audioEffects)
        }
        .onDisappear {
            model.stop()
        }
    }

    private func compactWorkspace(width: CGFloat) -> some View {
        let inset: CGFloat = width < 370 ? 12 : 16

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                compactHeader
                playbackStrip
                groupRail
                effectDirectory
                selectedEffectPanel
                runtimeStrip
                FloatingBarBottomSpacer()
            }
            .padding(.horizontal, inset)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func wideWorkspace(width: CGFloat) -> some View {
        let workspaceWidth = min(width - 40, 1160)

        return HStack(spacing: 0) {
            Spacer(minLength: 20)

            HStack(spacing: 0) {
                filterSidebar
                    .frame(width: 260)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 0.5)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        wideHeader
                        playbackStrip
                        selectedEffectPanel
                        runtimeStrip
                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: workspaceWidth)
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 0.7)
            }
            .padding(.vertical, 12)
            .frame(maxHeight: .infinity)

            Spacer(minLength: 20)
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if GlobalThemeId.persistedOrDefault != .default {
                    Text("实时音频实验台")
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text(headerStatus)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusTint)
            }

            Spacer(minLength: 0)
            outputStateControl
        }
    }

    private var wideHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.selectedEffect.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(model.selectedEffect.filterLabel)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
            }
            Spacer(minLength: 12)
            outputStateControl
        }
    }

    private var playbackStrip: some View {
        HStack(spacing: 13) {
            Group {
                if let coverURL = player.currentSong?.coverUrl?.sized(180) {
                    CachedAsyncImage(url: coverURL, width: 52, height: 52) {
                        coverPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    coverPlaceholder
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentSong?.name ?? "未在播放")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(player.currentSong?.artistName ?? "—")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text(model.isEffectEnabled ? "效果输出" : "原声输出")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(model.isEffectEnabled ? Color.cyan : Color.white.opacity(0.62))
                Text(model.selectedEffect.filterLabel)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .audioLabSurface(cornerRadius: 16)
    }

    private var coverPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.045)
            MonoIcon(icon: .musicNote, size: 18, color: .white.opacity(0.3))
        }
    }

    private var groupRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(FFmpegLiveLabGroup.allCases) { group in
                    groupButton(group)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func groupButton(_ group: FFmpegLiveLabGroup) -> some View {
        let selected = selectedGroup == group
        return Button {
            selectedGroup = group
            if let first = model.effects(in: group).first {
                model.select(first)
            }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(selected ? Color.cyan : Color.white.opacity(0.28))
                    .frame(width: 6, height: 6)
                Text(group.title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                Text("\(model.effects(in: group).count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .opacity(0.55)
            }
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.48))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(selected ? Color.cyan.opacity(0.13) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(selected ? Color.cyan.opacity(0.28) : Color.white.opacity(0.045), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
    }

    private var selectedEffectPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.selectedEffect.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(model.selectedEffect.filterLabel)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.38))
                }

                Spacer(minLength: 0)

                availabilityBadge
            }
            .padding(16)

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)

            abControl
                .padding(12)

            if !model.selectedEffect.parameters.isEmpty {
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)

                VStack(spacing: 0) {
                    ForEach(model.selectedEffect.parameters) { parameter in
                        parameterRow(parameter)
                        Rectangle()
                            .fill(Color.white.opacity(0.055))
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }

                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)

                Button {
                    model.resetParameters()
                } label: {
                    HStack(spacing: 8) {
                        MonoIcon(icon: .refresh, size: 12, color: .white.opacity(0.58))
                        Text("重置参数")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.plain)
            }
        }
        .audioLabSurface(cornerRadius: 16)
    }

    private var abControl: some View {
        HStack(spacing: 6) {
            outputChoice(title: "原声", enabled: false)
            outputChoice(title: "效果", enabled: true)
        }
        .padding(4)
        .background(Color.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func outputChoice(title: String, enabled: Bool) -> some View {
        let selected = model.isEffectEnabled == enabled
        let available = !enabled || (player.currentSong != nil && model.isSupported(model.selectedEffect))

        return Button {
            model.setEffectEnabled(enabled)
        } label: {
            HStack(spacing: 7) {
                if selected && model.isApplying {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(enabled ? .black : .white)
                } else {
                    Circle()
                        .fill(selected ? (enabled ? Color.black : Color.white) : Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selected && enabled ? Color.black : Color.white.opacity(selected ? 0.9 : 0.46))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(selected ? (enabled ? Color.cyan.opacity(0.9) : Color.white.opacity(0.09)) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.38)
    }

    private func parameterRow(_ parameter: FFmpegLiveLabParameter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(parameter.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text(parameter.formatted(model.parameterValue(parameter)))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(model.isEffectEnabled ? Color.cyan : Color.white.opacity(0.46))
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { model.parameterValue(parameter) },
                    set: { model.updateValue($0, for: parameter) }
                ),
                in: parameter.range,
                step: parameter.step
            )
            .tint(.cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var availabilityBadge: some View {
        let supported = model.isSupported(model.selectedEffect)
        return HStack(spacing: 6) {
            Circle()
                .fill(supported ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(supported ? "可用" : "缺失")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.68))
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var effectDirectory: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.effects(in: selectedGroup).enumerated()), id: \.element.id) { index, effect in
                effectRow(effect)
                if index < model.effects(in: selectedGroup).count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.leading, 46)
                }
            }
        }
        .padding(.horizontal, 12)
        .audioLabSurface(cornerRadius: 16)
    }

    private func effectRow(_ effect: FFmpegLiveLabEffect) -> some View {
        let selected = model.selectedEffect.id == effect.id
        let supported = model.isSupported(effect)

        return Button {
            model.select(effect)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(selected ? Color.cyan : (supported ? Color.white.opacity(0.25) : Color.red.opacity(0.7)))
                    .frame(width: 7, height: 7)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(effect.title)
                        .font(.system(size: 12.5, weight: selected ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(selected ? Color.white : Color.white.opacity(0.68))
                    Text(effect.filterLabel)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
                MonoIcon(icon: .chevronRight, size: 8, color: .white.opacity(0.22))
            }
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var runtimeStrip: some View {
        HStack(spacing: 0) {
            runtimeMetric(
                model.runtimeSnapshot.map { "\($0.filters.count)" } ?? "—",
                title: "音频滤镜"
            )
            metricDivider
            runtimeMetric(
                model.runtimeSnapshot.map { "\($0.audioDecoders.count)" } ?? "—",
                title: "解码器"
            )
            metricDivider
            runtimeMetric(
                model.runtimeSnapshot?.version ?? "—",
                title: "FFmpeg"
            )
        }
        .padding(.vertical, 13)
        .audioLabSurface(cornerRadius: 16)
    }

    private func runtimeMetric(_ value: String, title: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(width: 0.5, height: 30)
    }

    private var filterSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                MonoIcon(icon: .waveform, size: 24, color: .cyan)
                    .frame(width: 48, height: 48)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                if GlobalThemeId.persistedOrDefault != .default {
                    Text("实时音频实验台")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 7) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 7, height: 7)
                    Text(headerStatus)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(FFmpegLiveLabGroup.allCases) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.34))
                                .padding(.horizontal, 12)

                            ForEach(model.effects(in: group)) { effect in
                                sidebarEffectButton(effect)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)
            outputStateControl
                .padding(12)
        }
    }

    private func sidebarEffectButton(_ effect: FFmpegLiveLabEffect) -> some View {
        let selected = model.selectedEffect.id == effect.id
        let supported = model.isSupported(effect)

        return Button {
            selectedGroup = effect.group
            model.select(effect)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(selected ? Color.cyan : (supported ? Color.white.opacity(0.28) : Color.red.opacity(0.65)))
                    .frame(width: 6, height: 6)
                    .frame(width: 12)

                Text(effect.title)
                    .font(.system(size: 11.5, weight: selected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(selected ? Color.white : Color.white.opacity(0.56))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(selected ? Color.cyan.opacity(0.11) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var outputStateControl: some View {
        Button {
            model.setEffectEnabled(!model.isEffectEnabled)
        } label: {
            HStack(spacing: 8) {
                if model.isApplying {
                    ProgressView()
                        .controlSize(.small)
                        .tint(model.isEffectEnabled ? .black : .white)
                } else {
                    MonoIcon(
                        icon: model.isEffectEnabled ? .pause : .play,
                        size: 13,
                        color: model.isEffectEnabled ? .black : .white
                    )
                }

                Text(model.isEffectEnabled ? "停止效果" : "启用效果")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
            }
            .foregroundStyle(model.isEffectEnabled ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(model.isEffectEnabled ? Color.cyan : Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(player.currentSong == nil || !model.isSupported(model.selectedEffect))
        .opacity(player.currentSong == nil ? 0.42 : 1)
    }

    private var headerStatus: String {
        if player.currentSong == nil { return "等待播放" }
        if model.isApplying { return "正在更新" }
        return player.isPlaying ? "实时输出" : "播放已暂停"
    }

    private var statusTint: Color {
        if player.currentSong == nil { return .white.opacity(0.3) }
        if model.isApplying { return .orange }
        return player.isPlaying ? .green : .white.opacity(0.42)
    }
}

private extension View {
    func audioLabSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.045, green: 0.05, blue: 0.061))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.65)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
