// ContentView.swift
// FFmpegDemo — HiFi Player 全功能演示

import SwiftUI
import AVFoundation
import FFmpegSwiftSDK

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @State private var activePanel: Panel? = nil

    enum Panel: String, CaseIterable {
        case eq = "均衡器"
        case effects = "音效"
        case lyrics = "歌词"
        case abloop = "A-B循环"
        case analysis = "分析"
        case fingerprint = "识别"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0D0D0D), Color(hex: 0x1A1A2E)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        nowPlayingCard
                        if vm.spectrumEnabled { spectrumView }
                        transportControls
                        panelSelector
                        if let panel = activePanel {
                            switch panel {
                            case .eq:          eqPanel
                            case .effects:     effectsPanel
                            case .lyrics:      lyricsPanel
                            case .abloop:      abLoopPanel
                            case .analysis:    analysisPanel
                            case .fingerprint: fingerprintPanel
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("HiFi Player")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !vm.hifiInfoText.isEmpty {
                    Text(vm.hifiInfoText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                }
            }
            Spacer()
            // 频谱开关
            Button {
                vm.spectrumEnabled.toggle()
            } label: {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16))
                    .foregroundStyle(vm.spectrumEnabled ? accent : .gray)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Now Playing Card

    private var nowPlayingCard: some View {
        VStack(spacing: 14) {
            // 封面 / 视频 / 状态图标
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x2D2D44), Color(hex: 0x1A1A2E)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(height: vm.hasVideo ? 220 : 180)

                if vm.hasVideo {
                    VideoLayerView(layer: vm.videoLayer)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(4)
                } else if let data = vm.artworkData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(12)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: stateIcon)
                            .font(.system(size: 44))
                            .foregroundStyle(stateAccent)
                        Text(vm.state)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            // 元数据
            if vm.metaTitle != nil || vm.metaArtist != nil {
                VStack(spacing: 2) {
                    if let title = vm.metaTitle {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    if let artist = vm.metaArtist {
                        Text(artist + (vm.metaAlbum.map { " — \($0)" } ?? ""))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }

            // 流信息
            if !vm.streamInfoText.isEmpty {
                Text(vm.streamInfoText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            // URL 输入
            HStack(spacing: 8) {
                Image(systemName: "link").foregroundStyle(.gray).font(.system(size: 13))
                TextField("输入音视频地址", text: $vm.urlText)
                    .font(.system(size: 13))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 波形 + 进度条
            if vm.duration > 0 {
                waveformProgressView
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - 波形进度条

    private var waveformProgressView: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let progress = vm.duration > 0 ? vm.currentTime / vm.duration : 0

                ZStack(alignment: .leading) {
                    if !vm.waveformSamples.isEmpty {
                        // 波形图
                        HStack(spacing: 1) {
                            ForEach(0..<vm.waveformSamples.count, id: \.self) { i in
                                let sample = vm.waveformSamples[i]
                                let barProgress = Double(i) / Double(vm.waveformSamples.count)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(barProgress <= progress ? accent : Color.white.opacity(0.15))
                                    .frame(height: max(2, CGFloat(sample.positive) * 30))
                            }
                        }
                        .frame(height: 30)
                    } else {
                        // 简单进度条
                        Capsule().fill(Color.white.opacity(0.1)).frame(height: 3)
                        Capsule().fill(accent)
                            .frame(width: w * min(progress, 1), height: 3)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { drag in
                            let ratio = max(0, min(drag.location.x / w, 1))
                            vm.seek(to: vm.duration * ratio)
                        }
                )
            }
            .frame(height: vm.waveformSamples.isEmpty ? 3 : 30)

            HStack {
                Text(fmt(vm.currentTime))
                Spacer()
                if vm.tempo != 1.0 {
                    Text("\(String(format: "%.1f", vm.tempo))x")
                        .foregroundStyle(accent)
                }
                Spacer()
                Text(fmt(vm.duration))
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - 频谱

    private var spectrumView: some View {
        HStack(spacing: 2) {
            ForEach(0..<vm.spectrumData.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.3)],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .frame(height: max(2, CGFloat(vm.spectrumData[i]) * 50))
            }
        }
        .frame(height: 50)
        .animation(.easeOut(duration: 0.08), value: vm.spectrumData)
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 20) {
            Spacer()
            ctrlBtn(icon: "stop.fill", size: 16) { vm.stop() }
            // 主播放按钮
            Button(action: {
                if vm.state == "已暂停" { vm.resume() }
                else { vm.play() }
            }) {
                ZStack {
                    Circle().fill(accent).frame(width: 60, height: 60)
                    Image(systemName: vm.state == "播放中" ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .offset(x: vm.state == "播放中" ? 0 : 2)
                }
            }.buttonStyle(.plain)
            ctrlBtn(icon: "pause.fill", size: 16) { vm.pause() }
            Spacer()
        }
    }

    private func ctrlBtn(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }.buttonStyle(.plain)
    }

    // MARK: - Panel Selector

    private var panelSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Panel.allCases, id: \.rawValue) { panel in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            activePanel = activePanel == panel ? nil : panel
                        }
                    } label: {
                        Text(panel.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(activePanel == panel ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(activePanel == panel ? accent.opacity(0.3) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - EQ Panel

    private var eqPanel: some View {
        panelCard {
            VStack(spacing: 12) {
                HStack {
                    Text("10 段均衡器")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("重置") { vm.resetEQ() }
                        .font(.system(size: 11)).foregroundStyle(accent)
                }
                
                // EQ 预设选择器
                eqPresetSelector
                
                HStack(alignment: .center, spacing: 0) {
                    ForEach(EQBand.allCases, id: \.rawValue) { band in
                        eqColumn(band: band)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - EQ 预设选择器
    
    private var eqPresetSelector: some View {
        VStack(spacing: 8) {
            // 当前预设显示
            HStack {
                Text("预设")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(vm.selectedPreset?.name ?? "自定义")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(vm.selectedPreset != nil ? accent : .white.opacity(0.6))
            }
            
            // 预设分类滚动选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.presetsByCategory, id: \.category) { category in
                        Menu {
                            ForEach(category.presets) { preset in
                                Button {
                                    vm.applyPreset(preset)
                                } label: {
                                    HStack {
                                        Text(preset.name)
                                        if vm.selectedPreset?.id == preset.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(category.category)
                                    .font(.system(size: 10, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(categoryContainsSelected(category) ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(categoryContainsSelected(category) ? accent.opacity(0.3) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // 预设描述
            if let preset = vm.selectedPreset {
                Text(preset.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 显示预设包含的效果
                if preset.surroundLevel > 0 || preset.stereoWidth != 1.0 || preset.bassBoost != 0 || preset.trebleBoost != 0 {
                    HStack(spacing: 8) {
                        if preset.surroundLevel > 0 {
                            presetEffectTag("环绕 \(Int(preset.surroundLevel * 100))%")
                        }
                        if preset.stereoWidth != 1.0 {
                            presetEffectTag("宽度 \(String(format: "%.1f", preset.stereoWidth))")
                        }
                        if preset.bassBoost != 0 {
                            presetEffectTag("低音 \(preset.bassBoost > 0 ? "+" : "")\(Int(preset.bassBoost))dB")
                        }
                        if preset.trebleBoost != 0 {
                            presetEffectTag("高音 \(preset.trebleBoost > 0 ? "+" : "")\(Int(preset.trebleBoost))dB")
                        }
                    }
                }
            }
        }
    }
    
    private func categoryContainsSelected(_ category: (category: String, presets: [EQPreset])) -> Bool {
        guard let selected = vm.selectedPreset else { return false }
        return category.presets.contains { $0.id == selected.id }
    }
    
    private func presetEffectTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(accent.opacity(0.15))
            .clipShape(Capsule())
    }

    private func eqColumn(band: EQBand) -> some View {
        let gain = vm.eqGains[band] ?? 0
        return VStack(spacing: 3) {
            Text(gain == 0 ? "0" : String(format: "%+.0f", gain))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(abs(gain) > 6 ? accent : .white.opacity(0.4))
                .frame(height: 12)
            VerticalEQSlider(
                value: Binding(
                    get: { vm.eqGains[band] ?? 0 },
                    set: { vm.updateGain($0, for: band) }
                ),
                range: -12...12, accentColor: accent
            )
            .frame(width: 24, height: 120)
            Text(band.label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Effects Panel

    private var effectsPanel: some View {
        panelCard {
            VStack(spacing: 14) {
                HStack {
                    Text("音频效果")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("重置") { vm.resetEffects() }
                        .font(.system(size: 11)).foregroundStyle(accent)
                }

                // 基础效果
                effectSlider(label: "音量", value: vm.volume, range: -20...20, unit: "dB") { vm.updateVolume($0) }
                effectSlider(label: "倍速", value: vm.tempo, range: 0.5...4.0, unit: "x") { vm.updateTempo($0) }
                effectSlider(label: "变调", value: vm.pitch, range: -12...12, unit: "半音") { vm.updatePitch($0) }
                effectSlider(label: "低音", value: vm.bassGain, range: -12...12, unit: "dB") { vm.updateBass($0) }
                effectSlider(label: "高音", value: vm.trebleGain, range: -12...12, unit: "dB") { vm.updateTreble($0) }
                
                // 空间效果
                effectSlider(label: "环绕", value: vm.surroundLevel, range: 0...1, unit: "") { vm.updateSurround($0) }
                effectSlider(label: "混响", value: vm.reverbLevel, range: 0...1, unit: "") { vm.updateReverb($0) }
                effectSlider(label: "立体声宽度", value: vm.stereoWidth, range: 0...2, unit: "") { vm.updateStereoWidth($0) }
                effectSlider(label: "声道平衡", value: vm.channelBalance, range: -1...1, unit: "") { vm.updateChannelBalance($0) }
                
                // 人声消除
                effectSlider(label: "人声消除", value: vm.vocalRemoval, range: 0...1, unit: "") { vm.updateVocalRemoval($0) }
                
                // 时间效果
                effectSlider(label: "淡入", value: vm.fadeInDuration, range: 0...10, unit: "秒") { vm.updateFadeIn($0) }
                effectSlider(label: "延迟", value: vm.delayMs, range: 0...500, unit: "ms") { vm.updateDelay($0) }

                Divider().background(Color.white.opacity(0.1))
                
                // 开关效果
                Text("特殊效果").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    effectToggle("响度标准化", isOn: vm.loudnormEnabled) { vm.toggleLoudnorm() }
                    effectToggle("夜间模式", isOn: vm.nightModeEnabled) { vm.toggleNightMode() }
                    effectToggle("限幅器", isOn: vm.limiterEnabled) { vm.toggleLimiter() }
                    effectToggle("噪声门", isOn: vm.gateEnabled) { vm.toggleGate() }
                    effectToggle("自动增益", isOn: vm.autoGainEnabled) { vm.toggleAutoGain() }
                    effectToggle("超低音增强", isOn: vm.subboostEnabled) { vm.toggleSubboost() }
                    effectToggle("单声道", isOn: vm.monoEnabled) { vm.toggleMono() }
                    effectToggle("声道交换", isOn: vm.channelSwapEnabled) { vm.toggleChannelSwap() }
                    effectToggle("合唱", isOn: vm.chorusEnabled) { vm.toggleChorus() }
                    effectToggle("镶边", isOn: vm.flangerEnabled) { vm.toggleFlanger() }
                    effectToggle("颤音", isOn: vm.tremoloEnabled) { vm.toggleTremolo() }
                    effectToggle("颤抖", isOn: vm.vibratoEnabled) { vm.toggleVibrato() }
                    effectToggle("Lo-Fi 失真", isOn: vm.lofiEnabled) { vm.toggleLoFi() }
                    effectToggle("电话效果", isOn: vm.telephoneEnabled) { vm.toggleTelephone() }
                    effectToggle("水下效果", isOn: vm.underwaterEnabled) { vm.toggleUnderwater() }
                    effectToggle("收音机效果", isOn: vm.radioEnabled) { vm.toggleRadio() }
                }
            }
        }
    }

    private func effectToggle(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? accent : Color.white.opacity(0.2))
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(isOn ? .white : .white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? accent.opacity(0.2) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func effectSlider(label: String, value: Float, range: ClosedRange<Float>, unit: String, onChange: @escaping (Float) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 36, alignment: .leading)
            Slider(value: Binding(
                get: { value },
                set: { onChange($0) }
            ), in: range)
            .tint(accent)
            Text(String(format: "%.1f", value) + unit)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 52, alignment: .trailing)
        }
    }

    // MARK: - Lyrics Panel

    private var lyricsPanel: some View {
        panelCard {
            VStack(spacing: 12) {
                HStack {
                    Text("歌词同步")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    if vm.hasLyrics {
                        Button("清除") { vm.clearLyrics() }
                            .font(.system(size: 11)).foregroundStyle(accent)
                    }
                }

                if vm.hasLyrics {
                    // 歌词滚动显示
                    VStack(spacing: 6) {
                        ForEach(vm.nearbyLyrics, id: \.index) { item in
                            Text(item.text)
                                .font(.system(size: item.isCurrent ? 15 : 12, weight: item.isCurrent ? .semibold : .regular))
                                .foregroundStyle(item.isCurrent ? accent : .white.opacity(0.35))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .animation(.easeOut(duration: 0.2), value: item.isCurrent)
                        }
                        if let trans = vm.currentLyricTranslation {
                            Text(trans)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .frame(minHeight: 80)

                    // 偏移调整
                    HStack {
                        Text("偏移")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                        Button("-0.5s") { vm.adjustLyricOffset(-0.5) }
                            .font(.system(size: 10)).foregroundStyle(accent)
                        Text(String(format: "%+.1fs", vm.lyricOffset))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 44)
                        Button("+0.5s") { vm.adjustLyricOffset(0.5) }
                            .font(.system(size: 10)).foregroundStyle(accent)
                        Spacer()
                    }
                } else {
                    // 加载歌词选项
                    VStack(spacing: 12) {
                        Text("加载歌词")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        HStack(spacing: 10) {
                            // 加载示例歌词
                            Button {
                                vm.loadLyrics(sampleLRC)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 18))
                                    Text("示例歌词")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(accent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // 语音识别歌词
                            Button {
                                if vm.recognizerReady {
                                    vm.recognizeLyrics()
                                } else {
                                    vm.prepareRecognizer()
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    if vm.isPreparingRecognizer {
                                        ProgressView()
                                            .tint(.green)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: vm.recognizerReady ? "waveform.badge.mic" : "arrow.down.circle")
                                            .font(.system(size: 18))
                                    }
                                    Text(vm.recognizerReady ? "语音识别" : "下载模型")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(vm.isPreparingRecognizer || (vm.recognizerReady && vm.urlText.isEmpty))
                            .opacity((vm.isPreparingRecognizer || (vm.recognizerReady && vm.urlText.isEmpty)) ? 0.5 : 1.0)
                        }
                        
                        // 模型状态提示
                        if vm.isPreparingRecognizer {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .tint(accent)
                                    .scaleEffect(0.7)
                                Text("正在下载 Whisper 模型...")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        } else if vm.recognizerReady {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                                Text("识别引擎已就绪")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(minHeight: 60)
                }
                
                // 语音识别状态和结果
                if vm.isRecognizingLyrics {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ProgressView().tint(accent)
                            Text("正在识别歌词...")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        ProgressView(value: vm.lyricRecognitionProgress)
                            .tint(accent)
                            .frame(height: 4)
                        Text("\(Int(vm.lyricRecognitionProgress * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let result = vm.recognizedLyricResult {
                    VStack(spacing: 10) {
                        // 识别结果摘要
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("识别完成")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.green)
                                HStack(spacing: 12) {
                                    Label("\(result.segments.count) 行", systemImage: "text.alignleft")
                                    if let lang = result.language {
                                        Label(lang.uppercased(), systemImage: "globe")
                                    }
                                    Label("\(String(format: "%.1f", result.processingTime))s", systemImage: "clock")
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                        }
                        
                        // 操作按钮
                        HStack(spacing: 8) {
                            Button {
                                vm.applyRecognizedLyrics()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle")
                                    Text("应用歌词")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(accent.opacity(0.3))
                                .clipShape(Capsule())
                            }
                            
                            Button {
                                if let lrc = vm.exportRecognizedLyrics() {
                                    // 复制到剪贴板
                                    UIPasteboard.general.string = lrc
                                    vm.recognizedLyricMessage = "已复制到剪贴板"
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("导出 LRC")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                        
                        // 预览前几行
                        if !result.segments.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("预览")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                                ForEach(result.segments.prefix(3), id: \.startTime) { segment in
                                    HStack(spacing: 6) {
                                        Text(formatTime(segment.startTime))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(accent)
                                        Text(segment.text)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                }
                                if result.segments.count > 3 {
                                    Text("... 共 \(result.segments.count) 行")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let msg = vm.recognizedLyricMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(msg.contains("失败") ? .red : .white.opacity(0.6))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    
    // 格式化时间为 mm:ss
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - A-B Loop Panel

    private var abLoopPanel: some View {
        panelCard {
            VStack(spacing: 12) {
                HStack {
                    Text("A-B 循环")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    if vm.abLoopEnabled {
                        Button("清除") { vm.clearABLoop() }
                            .font(.system(size: 11)).foregroundStyle(accent)
                    }
                }

                HStack(spacing: 16) {
                    // A 点
                    VStack(spacing: 4) {
                        Text("A 点").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                        Text(fmt(vm.abPointA))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(vm.abLoopEnabled ? accent : .white.opacity(0.6))
                        Button("设为当前") { vm.setPointA() }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(accent.opacity(0.3))
                            .clipShape(Capsule())
                    }

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.white.opacity(0.3))

                    // B 点
                    VStack(spacing: 4) {
                        Text("B 点").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                        Text(fmt(vm.abPointB))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(vm.abLoopEnabled ? accent : .white.opacity(0.6))
                        Button("设为当前") { vm.setPointB() }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(accent.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }

                if vm.abLoopEnabled {
                    Text("循环中: \(fmt(vm.abPointA)) → \(fmt(vm.abPointB))")
                        .font(.system(size: 11))
                        .foregroundStyle(accent)
                }
            }
        }
    }

    // MARK: - Analysis Panel

    private var analysisPanel: some View {
        panelCard {
            VStack(spacing: 12) {
                HStack {
                    Text("音频分析")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("分析") { vm.runAnalysis() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(accent.opacity(0.3))
                        .clipShape(Capsule())
                }

                if vm.isAnalyzing {
                    VStack(spacing: 8) {
                        ProgressView(value: vm.analysisProgress)
                            .tint(accent)
                            .frame(height: 4)
                        Text("正在分析... \(Int(vm.analysisProgress * 100))%")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(minHeight: 100)
                } else if let r = vm.analysisResult {
                    VStack(alignment: .leading, spacing: 16) {
                        // 质量评分
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("质量评分")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(r.qualityScore)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(qualityColor(r.qualityScore))
                            }
                            Spacer()
                            Text(r.qualityGrade)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(qualityColor(r.qualityScore))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(qualityColor(r.qualityScore).opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // BPM 和节拍
                        analysisSection("节奏") {
                            analysisRow("BPM", "\(String(format: "%.1f", r.bpm))")
                            analysisRow("置信度", "\(String(format: "%.0f", r.bpmConfidence * 100))%")
                            analysisRow("稳定性", "\(String(format: "%.0f", r.bpmStability * 100))%")
                            analysisRow("节拍数", "\(r.beatCount)")
                        }
                        
                        // 响度
                        analysisSection("响度") {
                            analysisRow("积分响度", "\(String(format: "%.1f", r.loudnessLUFS)) LUFS")
                            analysisRow("短期响度", "\(String(format: "%.1f", r.shortTermLUFS)) LUFS")
                            analysisRow("响度范围", "\(String(format: "%.1f", r.loudnessRange)) LU")
                        }
                        
                        // 动态
                        analysisSection("动态") {
                            analysisRow("DR 值", "DR\(r.drValue)")
                            analysisRow("峰值", "\(String(format: "%.1f", r.peakDB)) dBFS")
                            analysisRow("RMS", "\(String(format: "%.1f", r.rmsDB)) dBFS")
                            analysisRow("波峰因数", "\(String(format: "%.1f", r.crestFactor)) dB")
                            analysisRow("削波", r.hasClipping ? "⚠️ 检测到" : "✓ 无")
                        }
                        
                        // 压缩评价
                        Text(r.compressionDesc)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        // 频率
                        analysisSection("频率") {
                            analysisRow("主频率", "\(String(format: "%.0f", r.dominantFreq)) Hz")
                            analysisRow("频谱质心", "\(String(format: "%.0f", r.spectralCentroid)) Hz")
                            analysisRow("低频", "\(String(format: "%.0f", r.lowEnergyRatio * 100))%")
                            analysisRow("中频", "\(String(format: "%.0f", r.midEnergyRatio * 100))%")
                            analysisRow("高频", "\(String(format: "%.0f", r.highEnergyRatio * 100))%")
                        }
                        
                        // 频段能量条
                        HStack(spacing: 4) {
                            energyBar("低", r.lowEnergyRatio, .blue)
                            energyBar("中", r.midEnergyRatio, .green)
                            energyBar("高", r.highEnergyRatio, .orange)
                        }
                        .frame(height: 40)
                        
                        // 音色
                        analysisSection("音色") {
                            analysisRow("亮度", "\(String(format: "%.0f", r.brightness * 100))%")
                            analysisRow("温暖度", "\(String(format: "%.0f", r.warmth * 100))%")
                            analysisRow("描述", r.timbreDesc)
                        }
                        
                        // EQ 建议
                        if !r.eqSuggestion.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EQ 建议")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(r.eqSuggestion)
                                    .font(.system(size: 11))
                                    .foregroundStyle(accent)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        // 音调
                        analysisSection("音调") {
                            analysisRow("音符", r.pitchNote)
                            analysisRow("基频", "\(String(format: "%.1f", r.pitchFreq)) Hz")
                        }
                        
                        // 相位（立体声）
                        analysisSection("立体声") {
                            analysisRow("相位相关", "\(String(format: "%.2f", r.phaseCorrelation))")
                            analysisRow("立体声宽度", "\(String(format: "%.0f", r.stereoWidth * 100))%")
                            analysisRow("状态", r.phaseDescription)
                        }
                        
                        // 问题列表
                        if !r.issues.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("检测到的问题")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.orange)
                                ForEach(r.issues, id: \.self) { issue in
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.orange)
                                        Text(issue)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                } else {
                    Text("点击「分析」按钮开始分析当前音频")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(minHeight: 60)
                }
            }
        }
    }
    
    private func analysisSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            content()
        }
    }

    private func analysisRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(accent)
        }
    }
    
    private func energyBar(_ label: String, _ value: Float, _ color: Color) -> some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.8))
                        .frame(height: geo.size.height * CGFloat(min(value * 2, 1)))
                }
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    private func qualityColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }

    // MARK: - Fingerprint Panel

    private var fingerprintPanel: some View {
        panelCard {
            VStack(spacing: 12) {
                HStack {
                    Text("歌曲识别")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("数据库: \(vm.fingerprintDBCount) 首")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }

                HStack(spacing: 10) {
                    Button("添加到库") { vm.addToFingerprintDB() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.3))
                        .clipShape(Capsule())

                    Button("识别歌曲") { vm.recognizeSong() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accent.opacity(0.3))
                        .clipShape(Capsule())
                }

                if vm.isRecognizing {
                    HStack(spacing: 8) {
                        ProgressView().tint(accent)
                        Text("识别中...")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else if let result = vm.recognitionResult {
                    VStack(spacing: 6) {
                        Text(result.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accent)
                        Text(result.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("匹配度: \(String(format: "%.0f", result.score * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 8)
                } else if let msg = vm.recognitionMessage {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(minHeight: 40)
                } else {
                    Text("先添加歌曲到数据库，然后可以识别未知音频")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(minHeight: 40)
                }
            }
        }
    }

    // MARK: - 通用面板卡片

    private func panelCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    private var accent: Color { Color(hex: 0xBB86FC) }

    private var stateIcon: String {
        switch vm.state {
        case "播放中":    return "waveform"
        case "连接中...": return "antenna.radiowaves.left.and.right"
        case "已暂停":    return "pause.circle"
        case "错误":      return "exclamationmark.triangle"
        case "已停止":    return "stop.circle"
        default:          return "music.note"
        }
    }

    private var stateAccent: Color {
        switch vm.state {
        case "播放中":    return accent
        case "连接中...": return .orange
        case "错误":      return .red
        default:          return .white.opacity(0.5)
        }
    }

    private func fmt(_ s: TimeInterval) -> String {
        String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}


// MARK: - 示例 LRC 歌词

private let sampleLRC = """
[ti:示例歌曲]
[ar:FFmpeg Demo]
[al:测试专辑]
[offset:0]
[00:00.00]♪ 前奏
[00:05.00]这是第一句歌词
[00:10.00]这是第二句歌词
[00:15.00]音乐在流淌
[00:20.00]旋律在飞扬
[00:25.00]每一个音符
[00:30.00]都是一段故事
[00:35.00]让我们一起
[00:40.00]感受音乐的力量
[00:45.00]♪ 间奏
[00:55.00]这是副歌部分
[01:00.00]跟着节奏摇摆
[01:05.00]让心灵自由飞翔
[01:10.00]在音乐的海洋里
[01:15.00]找到属于自己的方向
[01:20.00]♪ 尾奏
"""

// MARK: - VideoLayerView

struct VideoLayerView: UIViewRepresentable {
    let layer: AVSampleBufferDisplayLayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        layer.frame = uiView.bounds
    }
}

// MARK: - Vertical EQ Slider

struct VerticalEQSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let span = range.upperBound - range.lowerBound
            let norm = CGFloat((value - range.lowerBound) / span)
            let thumbY = h * (1 - norm)

            ZStack {
                Capsule().fill(Color.white.opacity(0.1)).frame(width: 3)
                let centerY = h * 0.5
                let fillTop = min(centerY, thumbY)
                let fillH = abs(thumbY - centerY)
                Capsule()
                    .fill(accentColor.opacity(0.6))
                    .frame(width: 3, height: fillH)
                    .position(x: geo.size.width / 2, y: fillTop + fillH / 2)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 10, height: 1)
                    .position(x: geo.size.width / 2, y: centerY)
                Circle()
                    .fill(accentColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: accentColor.opacity(0.4), radius: 3)
                    .position(x: geo.size.width / 2, y: thumbY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let clamped = max(0, min(drag.location.y, h))
                        let newNorm = 1 - Float(clamped / h)
                        let raw = range.lowerBound + newNorm * span
                        value = (raw * 2).rounded() / 2
                    }
            )
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

#Preview { ContentView() }
