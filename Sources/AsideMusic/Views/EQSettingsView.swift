// EQSettingsView.swift
// AsideMusic
//
// 均衡器设置界面 - 参考专业音频 App 设计
// 顶部：音效旋钮（低音/高音/环绕）
// 中部：频谱曲线 + 垂直滑块
// 底部：预设横向滚动选择

import SwiftUI
import FFmpegSwiftSDK

struct EQSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var eqManager = EQManager.shared
    @StateObject private var labManager = AudioLabManager.shared
    @State private var showSaveSheet = false
    @State private var customPresetName = ""
    @State private var showSmartAnalyzingToast = false
    @State private var showSmartAppliedToast = false
    
    // 音效旋钮值（0~1 范围）
    @State private var bassValue: CGFloat = 0.5
    @State private var trebleValue: CGFloat = 0.5
    @State private var surroundValue: CGFloat = 0.0
    @State private var reverbValue: CGFloat = 0.0
    
    // 变调（半音数，-12 ~ +12）
    @State private var pitchValue: Float = 0
    
    private var displayGains: [Float] {
        if let preset = eqManager.currentPreset, preset.id != "custom" {
            return preset.gains
        }
        return eqManager.customGains
    }

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.top, DeviceLayout.headerTopPadding)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 28) {
                        // 开关
                        toggleCard

                        if eqManager.isEnabled {
                            // 智能分析按钮（仅在智能音效开启时显示）
                            if labManager.isSmartEffectsEnabled {
                                smartAnalyzeButton
                            }
                            
                            // 音效旋钮区
                            knobSection

                            // 变调控制
                            pitchSection

                            // 均衡器（曲线 + 滑块合一）
                            equalizerSection

                            // 预设选择
                            presetScrollSection

                            // 自定义预设
                            if !eqManager.customPresets.isEmpty {
                                customPresetsSection
                            }

                            // 保存按钮
                            saveButton
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            
            // Toast 提示
            if showSmartAnalyzingToast || showSmartAppliedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        if showSmartAnalyzingToast {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text(LocalizedStringKey("eq_analyzing"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        } else {
                            AsideIcon(icon: .checkmark, size: 16, color: .white)
                            Text(LocalizedStringKey("eq_applied"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.asideAccent)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSaveSheet) {
            savePresetSheet
        }
        .onAppear { syncKnobsFromGains() }
        .onChange(of: eqManager.isEnabled) {
            // 当均衡器关闭时，同步 UI 旋钮到重置状态
            if !eqManager.isEnabled {
                syncKnobsFromGains()
            }
        }
        .onChange(of: eqManager.currentPreset?.id) {
            // 当预设变化时，同步旋钮（环绕预设会自动设置环绕参数）
            syncKnobsFromGains()
        }
    }

    // MARK: - 顶部导航

    private var headerView: some View {
        HStack {
            AsideBackButton()
            Spacer()
            Text(LocalizedStringKey("eq_title"))
                .font(.rounded(size: 18, weight: .semibold))
                .foregroundColor(.asideTextPrimary)
            Spacer()
            Button(action: { resetAll() }) {
                Text(LocalizedStringKey("eq_reset"))
                    .font(.rounded(size: 14, weight: .medium))
                    .foregroundColor(.asideTextSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
            }
            .opacity(eqManager.isEnabled ? 1 : 0)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 开关卡片

    private var toggleCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(eqManager.isEnabled ? Color.asideAccent.opacity(0.15) : Color.asideSeparator)
                    .frame(width: 44, height: 44)
                AsideIcon(icon: .waveform, size: 20, color: eqManager.isEnabled ? .asideAccent : .asideTextSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey("eq_toggle_title"))
                    .font(.rounded(size: 16, weight: .semibold))
                    .foregroundColor(.asideTextPrimary)
                Text(eqManager.isEnabled ? (eqManager.currentPreset?.name ?? NSLocalizedString("eq_custom", comment: "")) : NSLocalizedString("eq_original_output", comment: ""))
                    .font(.rounded(size: 13))
                    .foregroundColor(.asideTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $eqManager.isEnabled)
                .labelsHidden()
                .tint(.asideAccent)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
    
    // MARK: - 智能分析按钮
    
    private var smartAnalyzeButton: some View {
        Button(action: {
            // 触觉反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // 显示分析中提示
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showSmartAnalyzingToast = true
            }
            
            // 执行分析
            Task {
                await labManager.forceReanalyze()
                
                // 隐藏分析中提示，显示完成提示
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSmartAnalyzingToast = false
                    }
                    
                    // 同步旋钮
                    syncKnobsFromGains()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSmartAppliedToast = true
                    }
                    
                    // 2秒后隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSmartAppliedToast = false
                        }
                    }
                }
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.asideAccent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    AsideIcon(icon: .sparkle, size: 18, color: .asideAccent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("eq_smart_analyze"))
                        .font(.rounded(size: 15, weight: .semibold))
                        .foregroundColor(.asideTextPrimary)
                    Text(LocalizedStringKey("eq_smart_desc"))
                        .font(.rounded(size: 12))
                        .foregroundColor(.asideTextSecondary)
                }
                
                Spacer()
                
                AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary)
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.asideAccent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(PlayerManager.shared.currentSong == nil)
        .opacity(PlayerManager.shared.currentSong == nil ? 0.5 : 1)
    }

    // MARK: - 音效旋钮区

    private var knobSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("eq_effects"))
                .font(.rounded(size: 16, weight: .semibold))
                .foregroundColor(.asideTextPrimary)

            HStack(spacing: 0) {
                Spacer()
                knobItem(label: NSLocalizedString("eq_bass", comment: ""), value: $bassValue) { val in
                    applyBassKnob(val)
                }
                Spacer()
                knobItem(label: NSLocalizedString("eq_treble", comment: ""), value: $trebleValue) { val in
                    applyTrebleKnob(val)
                }
                Spacer()
                knobItem(label: NSLocalizedString("eq_surround", comment: ""), value: $surroundValue) { val in
                    applySurroundKnob(val)
                }
                Spacer()
                knobItem(label: NSLocalizedString("eq_reverb", comment: ""), value: $reverbValue) { val in
                    applyReverbKnob(val)
                }
                Spacer()
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private func knobItem(label: String, value: Binding<CGFloat>, onChange: @escaping (CGFloat) -> Void) -> some View {
        VStack(spacing: 10) {
            CircularKnob(value: value, onChange: onChange)
                .frame(width: 72, height: 72)
            Text(label)
                .font(.rounded(size: 13, weight: .medium))
                .foregroundColor(.asideTextSecondary)
        }
    }

    // MARK: - 变调控制

    private var pitchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("eq_pitch"))
                    .font(.rounded(size: 16, weight: .semibold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                // 当前半音数显示
                Text(pitchDisplayText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(pitchValue == 0 ? .asideTextSecondary : .asideAccent)
            }

            // 半音滑块
            VStack(spacing: 8) {
                // 刻度标记
                HStack {
                    Text("-12")
                    Spacer()
                    Text("0")
                    Spacer()
                    Text("+12")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.asideTextSecondary.opacity(0.6))

                // 自定义滑块
                GeometryReader { geo in
                    let w = geo.size.width
                    let normalized = CGFloat((pitchValue + 12) / 24) // -12~+12 → 0~1
                    let centerX = w * 0.5
                    let thumbX = w * normalized

                    ZStack(alignment: .leading) {
                        // 轨道
                        Capsule()
                            .fill(Color.asideSeparator)
                            .frame(height: 4)

                        // 中线标记
                        Rectangle()
                            .fill(Color.asideTextSecondary.opacity(0.3))
                            .frame(width: 2, height: 12)
                            .position(x: centerX, y: geo.size.height / 2)

                        // 活跃区域（从中心到拇指）
                        let barStart = min(centerX, thumbX)
                        let barWidth = abs(thumbX - centerX)
                        if barWidth > 1 {
                            Capsule()
                                .fill(Color.asideAccent.opacity(0.6))
                                .frame(width: barWidth, height: 4)
                                .offset(x: barStart)
                        }

                        // 拇指
                        Circle()
                            .fill(Color.asideAccent)
                            .frame(width: 20, height: 20)
                            .shadow(color: Color.asideAccent.opacity(0.3), radius: 4, y: 2)
                            .position(x: thumbX, y: geo.size.height / 2)
                    }
                    .contentShape(Rectangle().inset(by: -12))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let ratio = min(max(value.location.x / w, 0), 1)
                                // 映射到 -12~+12，吸附到整数半音
                                let raw = Float(ratio) * 24 - 12
                                let snapped = roundf(raw)
                                pitchValue = snapped
                                PlayerManager.shared.setPitch(snapped)
                            }
                    )
                }
                .frame(height: 28)

                // 快捷按钮
                HStack(spacing: 8) {
                    ForEach([-3, -1, 0, 1, 3], id: \.self) { semitone in
                        let s = Float(semitone)
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                pitchValue = s
                                PlayerManager.shared.setPitch(s)
                            }
                        }) {
                            Text(semitone > 0 ? "+\(semitone)" : "\(semitone)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(pitchValue == s ? .asideIconForeground : .asideTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(pitchValue == s ? Color.asideAccent : Color.asideSeparator)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private var pitchDisplayText: String {
        let v = Int(pitchValue)
        if v == 0 { return NSLocalizedString("eq_original_key", comment: "") }
        return String(format: NSLocalizedString("eq_semitone", comment: ""), v > 0 ? "+\(v)" : "\(v)")
    }

    // MARK: - 均衡器区域（曲线 + 滑块合一）

    private var equalizerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LocalizedStringKey("eq_equalizer"))
                    .font(.rounded(size: 16, weight: .semibold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                Button(action: { showSaveSheet = true }) {
                    Text(LocalizedStringKey("eq_save"))
                        .font(.rounded(size: 13, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.asideSeparator)
                        .clipShape(Capsule())
                }
            }

            // 曲线 + 滑块叠加
            ZStack(alignment: .bottom) {
                // 频谱曲线填充
                spectrumFill
                    .frame(height: 220)

                // 垂直滑块
                sliderOverlay
                    .frame(height: 220)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 频率标签
            frequencyLabels
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    // 频谱曲线填充（渐变）
    private var spectrumFill: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let gains = displayGains
            let count = gains.count
            let divisor = max(count - 1, 1)
            let points = gains.enumerated().map { (i, gain) -> CGPoint in
                let x = w * CGFloat(i) / CGFloat(divisor)
                let y = h * (1 - CGFloat((gain + 12) / 24))
                return CGPoint(x: x, y: y)
            }

            ZStack {
                // 水平参考线
                ForEach([0.25, 0.5, 0.75], id: \.self) { ratio in
                    Path { path in
                        let y = h * CGFloat(ratio)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.asideSeparator.opacity(0.4), lineWidth: 0.5)
                }

                if points.count >= 2 {
                    // 填充区域
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        path.addLine(to: points[0])
                        for i in 1..<points.count {
                            let prev = points[i - 1]
                            let curr = points[i]
                            let midX = (prev.x + curr.x) / 2
                            path.addCurve(to: curr,
                                          control1: CGPoint(x: midX, y: prev.y),
                                          control2: CGPoint(x: midX, y: curr.y))
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.asideAccent.opacity(0.25),
                                Color.asideAccent.opacity(0.08),
                                Color.asideAccent.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // 曲线描边
                    Path { path in
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            let prev = points[i - 1]
                            let curr = points[i]
                            let midX = (prev.x + curr.x) / 2
                            path.addCurve(to: curr,
                                          control1: CGPoint(x: midX, y: prev.y),
                                          control2: CGPoint(x: midX, y: curr.y))
                        }
                    }
                    .stroke(Color.asideAccent.opacity(0.5), lineWidth: 2)
                }
            }
            .animation(.easeOut(duration: 0.15), value: displayGains)
        }
    }

    // 垂直滑块叠加层
    private var sliderOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = displayGains.count
            let spacing = w / CGFloat(count)

            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let gain = displayGains[index]
                    let normalized = CGFloat((gain + 12) / 24)
                    let centerX = spacing * CGFloat(index) + spacing / 2
                    let thumbY = h * (1 - normalized)
                    let centerY = h * 0.5

                    // 轨道线
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.asideTextSecondary.opacity(0.15))
                        .frame(width: 3, height: h)
                        .position(x: centerX, y: h / 2)

                    // 增益条（从中线到拇指）
                    let barHeight = abs(thumbY - centerY)
                    let barMidY = min(thumbY, centerY) + barHeight / 2
                    if barHeight > 1 {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.asideAccent.opacity(0.5))
                            .frame(width: 3, height: barHeight)
                            .position(x: centerX, y: barMidY)
                    }

                    // 拇指
                    Capsule()
                        .fill(Color.asideAccent)
                        .frame(width: 8, height: 24)
                        .shadow(color: Color.asideAccent.opacity(0.3), radius: 4, y: 2)
                        .position(x: centerX, y: thumbY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let spacing = w / CGFloat(count)
                        let index = Int((value.location.x / spacing).rounded(.down))
                        let clampedIndex = min(max(index, 0), count - 1)
                        let ratio = 1 - (value.location.y / h)
                        let clamped = min(max(ratio, 0), 1)
                        let newGain = Float(clamped) * 24 - 12
                        switchToCustomIfNeeded()
                        eqManager.setCustomGain(newGain, at: clampedIndex)
                    }
            )
        }
    }

    // 频率标签
    private var frequencyLabels: some View {
        HStack(spacing: 0) {
            ForEach(EQBand.allCases, id: \.self) { band in
                Text(band.label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.asideTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }


    // MARK: - 预设横向滚动

    private var presetScrollSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 分类标签
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([EQPresetCategory.genre, .surround, .scene, .vocal], id: \.rawValue) { category in
                        categoryTab(category)
                    }
                }
            }
            .scrollIndicators(.hidden)

            // 预设卡片横向滚动
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(eqManager.presets(for: selectedCategory)) { preset in
                        presetCard(preset)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @State private var selectedCategory: EQPresetCategory = .genre

    private func categoryTab(_ category: EQPresetCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 5) {
                AsideIcon(icon: category.icon, size: 13,
                          color: isSelected ? .asideIconForeground : .asideTextSecondary)
                Text(category.rawValue)
                    .font(.rounded(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .asideIconForeground : .asideTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.asideAccent : Color.asideTextPrimary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private func presetCard(_ preset: EQPreset) -> some View {
        let isSelected = eqManager.currentPreset?.id == preset.id

        return Button(action: {
            withAnimation(.easeOut(duration: 0.2)) {
                eqManager.applyPreset(preset)
            }
        }) {
            VStack(spacing: 8) {
                // 选中指示圆点
                Circle()
                    .fill(isSelected ? Color.asideAccent : Color.asideSeparator)
                    .frame(width: 10, height: 10)

                Text(preset.name)
                    .font(.rounded(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .asideTextPrimary : .asideTextSecondary)
                    .lineLimit(1)
            }
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.asideTextPrimary.opacity(isSelected ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.asideAccent : Color.asideSeparator.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .shadow(color: isSelected ? Color.asideAccent.opacity(0.15) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 自定义预设

    private var customPresetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("eq_my_presets"))
                .font(.rounded(size: 15, weight: .semibold))
                .foregroundColor(.asideTextPrimary)

            ForEach(eqManager.customPresets) { preset in
                customPresetRow(preset)
            }
        }
    }

    private func customPresetRow(_ preset: EQPreset) -> some View {
        let isSelected = eqManager.currentPreset?.id == preset.id

        return HStack(spacing: 12) {
            Button(action: { eqManager.applyPreset(preset) }) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(isSelected ? Color.asideAccent : Color.asideSeparator)
                        .frame(width: 8, height: 8)

                    Text(preset.name)
                        .font(.rounded(size: 15, weight: .medium))
                        .foregroundColor(.asideTextPrimary)

                    Spacer()

                    if isSelected {
                        AsideIcon(icon: .checkmark, size: 14, color: .asideAccent)
                    }
                }
            }
            .buttonStyle(.plain)

            Button(action: { eqManager.deleteCustomPreset(preset) }) {
                AsideIcon(icon: .trash, size: 15, color: .asideTextSecondary.opacity(0.6))
                    .padding(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.asideAccent.opacity(0.08) : .clear)
                .glassEffect(isSelected ? .identity : .regular, in: .rect(cornerRadius: 14))
        )
    }

    // MARK: - 保存按钮

    private var saveButton: some View {
        Button(action: { showSaveSheet = true }) {
            HStack(spacing: 8) {
                AsideIcon(icon: .save, size: 16, color: .asideAccent)
                Text(LocalizedStringKey("eq_save_preset"))
                    .font(.rounded(size: 15, weight: .medium))
                    .foregroundColor(.asideAccent)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.asideAccent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.asideAccent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 保存预设 Sheet

    private var savePresetSheet: some View {
        NavigationStack {
            ZStack {
                AsideBackground()
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(LocalizedStringKey("eq_save_custom"))
                        .font(.rounded(size: 18, weight: .semibold))
                        .foregroundColor(.asideTextPrimary)

                    TextField(NSLocalizedString("eq_preset_name", comment: ""), text: $customPresetName)
                        .font(.rounded(size: 16))
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))

                    Button(action: {
                        guard !customPresetName.isEmpty else { return }
                        eqManager.saveCustomPreset(name: customPresetName)
                        customPresetName = ""
                        showSaveSheet = false
                    }) {
                        Text(LocalizedStringKey("eq_save"))
                            .font(.rounded(size: 16, weight: .semibold))
                            .foregroundColor(.asideIconForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.asideAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(customPresetName.isEmpty)
                    .opacity(customPresetName.isEmpty ? 0.5 : 1)

                    Spacer()
                }
                .padding(20)
            }
            .presentationDetents([.height(280)])
        }
    }

    // MARK: - 旋钮 ↔ AudioEffects 同步

    /// 从当前 AudioEffects 状态反推旋钮位置
    private func syncKnobsFromGains() {
        let effects = PlayerManager.shared.audioEffects
        bassValue = CGFloat((effects.bassGain + 12) / 24)
        trebleValue = CGFloat((effects.trebleGain + 12) / 24)
        surroundValue = CGFloat(effects.surroundLevel)
        reverbValue = CGFloat(effects.reverbLevel)
        pitchValue = PlayerManager.shared.pitchSemitones
    }

    /// 全部重置：EQ 增益 + 音效旋钮 + 变调
    private func resetAll() {
        // 重置 EQ 均衡器
        eqManager.applyFlat()
        
        // 重置音效参数
        PlayerManager.shared.audioEffects.setBassGain(0)
        PlayerManager.shared.audioEffects.setTrebleGain(0)
        PlayerManager.shared.audioEffects.setSurroundLevel(0)
        PlayerManager.shared.audioEffects.setReverbLevel(0)
        EQManager.shared.saveAudioEffectsState()
        
        // 重置变调
        PlayerManager.shared.setPitch(0)
        
        // 同步旋钮 UI
        syncKnobsFromGains()
    }

    private func applyBassKnob(_ val: CGFloat) {
        let db = Float(val) * 24 - 12
        PlayerManager.shared.audioEffects.setBassGain(db)
        EQManager.shared.updateSafetyLimiter()
        EQManager.shared.saveAudioEffectsState()
    }

    private func applyTrebleKnob(_ val: CGFloat) {
        let db = Float(val) * 24 - 12
        PlayerManager.shared.audioEffects.setTrebleGain(db)
        EQManager.shared.updateSafetyLimiter()
        EQManager.shared.saveAudioEffectsState()
    }

    private func applySurroundKnob(_ val: CGFloat) {
        PlayerManager.shared.audioEffects.setSurroundLevel(Float(val))
        EQManager.shared.saveAudioEffectsState()
    }

    private func applyReverbKnob(_ val: CGFloat) {
        PlayerManager.shared.audioEffects.setReverbLevel(Float(val))
        EQManager.shared.saveAudioEffectsState()
    }

    private func switchToCustomIfNeeded() {
        if eqManager.currentPreset?.id != "custom" {
            if let preset = eqManager.currentPreset {
                eqManager.customGains = preset.gains
            }
            eqManager.currentPreset = EQPreset(
                id: "custom",
                name: NSLocalizedString("eq_custom", comment: ""),
                category: .custom,
                description: "",
                gains: eqManager.customGains,
                isCustom: true
            )
        }
    }
}

// MARK: - 圆形旋钮组件

struct CircularKnob: View {
    @Binding var value: CGFloat // 0~1
    var onChange: ((CGFloat) -> Void)?

    private let lineWidth: CGFloat = 6
    private let trackColor = Color.asideSeparator
    private let activeColor = Color.asideAccent

    // 弧线参数：从左下 (225°) 顺时针到右下 (315°)，跨越 270°
    // SwiftUI trim 参数：startTrim = 0.125 (45°/360°), 总弧 = 0.75 (270°/360°)
    // 旋转 90° 使 trim(0) 在底部
    
    // 角度定义（以数学坐标系，从正右方逆时针）：
    // 起始位置：左下方 225° → 在 rotated 坐标中对应 trim 0.125
    // 结束位置：右下方 315° → 在 rotated 坐标中对应 trim 0.875

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // 背景轨道
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: size - lineWidth, height: size - lineWidth)

                // 活跃弧线
                Circle()
                    .trim(from: 0.125, to: 0.125 + 0.75 * value)
                    .stroke(activeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: size - lineWidth, height: size - lineWidth)

                // 中心百分比
                Text("\(Int(value * 100))")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let center = CGPoint(x: size / 2, y: size / 2)
                        let dx = drag.location.x - center.x
                        let dy = drag.location.y - center.y
                        
                        // atan2 返回 -π~π，转换为 0~2π（从正右方逆时针）
                        var angle = atan2(-dy, dx) // 标准数学坐标系角度
                        if angle < 0 { angle += 2 * .pi }
                        
                        // 弧线从 225°(5π/4) 顺时针经过 0° 到 315°(7π/4)
                        // 在数学坐标系中：225° = 5π/4 ≈ 3.927
                        // 死区：从 315°(5.498) 到 225°(3.927) 的短弧（底部 90°）
                        
                        // 将角度转换为从起始点(225°)开始的顺时针偏移
                        // 顺时针 = 角度减小方向
                        let startAngle: CGFloat = 5.0 * .pi / 4.0  // 225° = 3.927 rad
                        
                        // 从起始角顺时针的偏移量
                        var offset = startAngle - angle
                        if offset < 0 { offset += 2 * .pi }
                        
                        // 总弧度 270° = 3π/2
                        let totalArc: CGFloat = 3.0 * .pi / 2.0  // 4.712 rad
                        
                        // 如果偏移超过总弧度，说明在死区
                        if offset > totalArc {
                            // 在死区内，吸附到最近的端点
                            let distToStart = 2 * .pi - offset
                            let distToEnd = offset - totalArc
                            if distToStart < distToEnd {
                                value = 0
                            } else {
                                value = 1
                            }
                        } else {
                            value = min(max(offset / totalArc, 0), 1)
                        }
                        
                        onChange?(value)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
