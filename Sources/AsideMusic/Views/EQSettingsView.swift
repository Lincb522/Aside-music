// EQSettingsView.swift
// AsideMusic
//
// 均衡器设置界面 - Aside 黑白风格

import SwiftUI
import FFmpegSwiftSDK

struct EQSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var eqManager = EQManager.shared
    @State private var selectedCategory: EQPresetCategory = .genre
    @State private var showSaveSheet = false
    @State private var customPresetName = ""
    @State private var draggedBandIndex: Int? = nil

    private var displayGains: [Float] {
        if let preset = eqManager.currentPreset, preset.id != "custom" {
            return preset.gains
        }
        return eqManager.customGains
    }
    
    private var bandCount: Int { 10 }
    
    private var currentPresetDisplayName: String {
        return eqManager.currentPreset?.name ?? "自定义"
    }

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerView
                        .padding(.top, DeviceLayout.headerTopPadding)

                    toggleCard

                    if eqManager.isEnabled {
                        spectrumCard
                        bandSliderCard
                        presetSection
                        
                        if hasCustomPresets {
                            customPresetsSection
                        }
                        
                        saveButton
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSaveSheet) {
            savePresetSheet
        }
    }
    
    private var hasCustomPresets: Bool {
        return !eqManager.customPresets.isEmpty
    }

    // MARK: - 顶部导航

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                AsideBackButton()
            }
            Spacer()
            Text("均衡器")
                .font(.rounded(size: 18, weight: .semibold))
                .foregroundColor(.asideTextPrimary)
            Spacer()
            Button(action: { eqManager.applyFlat() }) {
                Text("重置")
                    .font(.rounded(size: 14, weight: .medium))
                    .foregroundColor(.asideTextSecondary)
            }
            .opacity(eqManager.isEnabled ? 1 : 0)
        }
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
                Text("音频均衡器")
                    .font(.rounded(size: 16, weight: .semibold))
                    .foregroundColor(.asideTextPrimary)
                Text(eqManager.isEnabled ? currentPresetDisplayName : "使用原始音频输出")
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
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.asideCardBackground)
        )
    }

    // MARK: - 频谱曲线卡片

    private var spectrumCard: some View {
        VStack(spacing: 0) {
            spectrumCurve
                .frame(height: 140)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.asideCardBackground)
        )
    }

    private var spectrumCurve: some View {
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
                // 网格线
                ForEach([0.0, 0.5, 1.0], id: \.self) { ratio in
                    Path { path in
                        let y = h * CGFloat(ratio)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.asideSeparator, lineWidth: ratio == 0.5 ? 1 : 0.5)
                }

                // dB 标签
                VStack {
                    Text("+12")
                    Spacer()
                    Text("0")
                    Spacer()
                    Text("-12")
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.asideTextSecondary.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

                // 曲线填充
                if points.count >= 2 {
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
                            colors: [Color.asideAccent.opacity(0.2), Color.asideAccent.opacity(0.02)],
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
                    .stroke(Color.asideAccent, lineWidth: 2)
                }

                // 控制点
                ForEach(0..<count, id: \.self) { i in
                    let pt = points[i]
                    let isDragging = draggedBandIndex == i
                    Circle()
                        .fill(isDragging ? Color.asideIconForeground : Color.asideAccent)
                        .frame(width: isDragging ? 14 : (count > 10 ? 6 : 8))
                        .shadow(color: Color.asideAccent.opacity(0.3), radius: isDragging ? 6 : 3)
                        .position(pt)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    draggedBandIndex = i
                                    let ratio = 1 - (value.location.y / h)
                                    let clamped = min(max(ratio, 0), 1)
                                    let newGain = Float(clamped) * 24 - 12
                                    switchToCustomIfNeeded()
                                    eqManager.setCustomGain(newGain, at: i)
                                }
                                .onEnded { _ in draggedBandIndex = nil }
                        )
                }
            }
            .animation(.easeOut(duration: 0.12), value: displayGains)
        }
    }


    // MARK: - 频段滑块卡片

    private var bandSliderCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("频段调节")
                    .font(.rounded(size: 14, weight: .semibold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                Text("10 段")
                    .font(.rounded(size: 12))
                    .foregroundColor(.asideTextSecondary)
            }
            .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<bandCount, id: \.self) { index in
                        bandSlider(index: index)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.asideCardBackground)
        )
    }

    private func bandSlider(index: Int) -> some View {
        let gain = displayGains[index]
        let normalized = CGFloat((gain + 12) / 24)
        let sliderWidth: CGFloat = 28
        
        return VStack(spacing: 4) {
            // 增益值
            Text(String(format: "%+.0f", gain))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(abs(gain) > 0.5 ? .asideAccent : .asideTextSecondary)
                .frame(height: 12)
            
            // 滑块
            GeometryReader { geo in
                let height = geo.size.height
                let centerY = height / 2
                let thumbY = height * (1 - normalized)
                let barHeight = abs(thumbY - centerY)
                let barY = min(thumbY, centerY)
                
                ZStack {
                    // 轨道
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.asideSeparator)
                        .frame(width: 4)
                    
                    // 中线
                    Circle()
                        .fill(Color.asideTextSecondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .position(x: sliderWidth / 2, y: centerY)
                    
                    // 增益条
                    if barHeight > 1 {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.asideAccent.opacity(0.6))
                            .frame(width: 4, height: barHeight)
                            .position(x: sliderWidth / 2, y: barY + barHeight / 2)
                    }
                    
                    // 拇指
                    Circle()
                        .fill(Color.asideAccent)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .fill(Color.asideIconForeground)
                                .frame(width: 4, height: 4)
                        )
                        .position(x: sliderWidth / 2, y: thumbY)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = 1 - (value.location.y / height)
                            let clamped = min(max(ratio, 0), 1)
                            let newGain = Float(clamped) * 24 - 12
                            switchToCustomIfNeeded()
                            eqManager.setCustomGain(newGain, at: index)
                        }
                )
            }
            .frame(width: sliderWidth, height: 100)
            
            // 频率
            Text(EQBand.allCases[index].label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.asideTextSecondary)
                .frame(height: 12)
        }
    }


    // MARK: - 预设区域

    private var presetSection: some View {
        VStack(spacing: 14) {
            // 分类标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([EQPresetCategory.genre, .surround, .scene, .vocal], id: \.rawValue) { category in
                        categoryTab(category)
                    }
                }
            }

            // 预设网格
            let presets = eqManager.presets(for: selectedCategory)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(presets) { preset in
                    presetCard(preset)
                }
            }
        }
    }

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
                    .fill(isSelected ? Color.asideAccent : Color.asideCardBackground)
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
            VStack(spacing: 6) {
                miniCurve(gains: preset.gains, isSelected: isSelected)
                    .frame(height: 26)
                    .padding(.horizontal, 4)

                Text(preset.name)
                    .font(.rounded(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .asideIconForeground : .asideTextPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.asideAccent : Color.asideCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.asideSeparator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func miniCurve(gains: [Float], isSelected: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = gains.count
            let divisor = max(count - 1, 1)
            let points = gains.enumerated().map { (i, gain) -> CGPoint in
                let x = w * CGFloat(i) / CGFloat(divisor)
                let y = h * (1 - CGFloat((gain + 12) / 24))
                return CGPoint(x: x, y: y)
            }

            if points.count >= 2 {
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
                .fill((isSelected ? Color.asideIconForeground : Color.asideAccent).opacity(0.2))

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
                .stroke(
                    (isSelected ? Color.asideIconForeground : Color.asideAccent).opacity(0.6),
                    lineWidth: 1.5
                )
            }
        }
    }


    // MARK: - 自定义预设

    private var customPresetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("我的预设")
                .font(.rounded(size: 15, weight: .semibold))
                .foregroundColor(.asideTextPrimary)

            let customPresets = eqManager.customPresets
            
            ForEach(customPresets) { preset in
                customPresetRow(preset)
            }
        }
    }

    private func customPresetRow(_ preset: EQPreset) -> some View {
        let isSelected = eqManager.currentPreset?.id == preset.id
        
        return HStack(spacing: 12) {
            Button(action: { eqManager.applyPreset(preset) }) {
                HStack(spacing: 12) {
                    miniCurve(gains: preset.gains, isSelected: isSelected)
                        .frame(width: 50, height: 24)

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
                .fill(isSelected ? Color.asideAccent.opacity(0.1) : Color.asideCardBackground)
        )
    }

    // MARK: - 保存按钮

    private var saveButton: some View {
        Button(action: { showSaveSheet = true }) {
            HStack(spacing: 8) {
                AsideIcon(icon: .save, size: 16, color: .asideAccent)
                Text("保存为预设")
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
                    Text("保存自定义预设")
                        .font(.rounded(size: 18, weight: .semibold))
                        .foregroundColor(.asideTextPrimary)

                    miniCurve(gains: eqManager.customGains, isSelected: true)
                        .frame(height: 50)
                        .padding(.horizontal, 20)

                    TextField("预设名称", text: $customPresetName)
                        .font(.rounded(size: 16))
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.asideCardBackground)
                        )

                    Button(action: {
                        guard !customPresetName.isEmpty else { return }
                        eqManager.saveCustomPreset(name: customPresetName)
                        customPresetName = ""
                        showSaveSheet = false
                    }) {
                        Text("保存")
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
            .presentationDetents([.height(320)])
        }
    }

    // MARK: - 辅助方法

    private func switchToCustomIfNeeded() {
        if eqManager.currentPreset?.id != "custom" {
            if let preset = eqManager.currentPreset {
                eqManager.customGains = preset.gains
            }
            eqManager.currentPreset = EQPreset(
                id: "custom",
                name: "自定义",
                category: .custom,
                description: "手动调节的均衡器设置",
                gains: eqManager.customGains,
                isCustom: true
            )
        }
    }
}
