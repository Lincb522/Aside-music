//
//  EQView.swift
//  AsideMusic
//
//  均衡器 & HiFi 引擎调节界面
//

import SwiftUI

struct EQView: View {
    @ObservedObject private var eqManager = AudioEQManager.shared
    @ObservedObject private var hifiEngine = HiFiEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var showSaveSheet = false
    @State private var newPresetName = ""
    @State private var showDeleteAlert = false
    @State private var presetToDelete: CustomEQPreset?
    
    // 频谱动画
    @State private var spectrumValues: [Float] = Array(repeating: 0, count: 10)
    @State private var spectrumTimer: Timer?
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 顶部导航
                    headerSection
                        .padding(.top, DeviceLayout.headerTopPadding)
                    
                    // Tab 选择器
                    tabPicker
                    
                    // 内容
                    if selectedTab == 0 {
                        eqContent
                    } else if selectedTab == 1 {
                        hifiContent
                    } else {
                        smartContent
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            savePresetSheet
        }
        .alert("删除预设", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let preset = presetToDelete {
                    eqManager.deleteCustomPreset(preset.id)
                }
            }
        } message: {
            Text("确定要删除「\(presetToDelete?.name ?? "")」吗？")
        }
        .onAppear {
            startSpectrumUpdate()
        }
        .onDisappear {
            stopSpectrumUpdate()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    AsideIcon(icon: .back, size: 16, color: .black)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            Text(tabTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            
            Spacer()
            
            Button(action: { resetCurrent() }) {
                Text("重置")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }
            .frame(width: 40)
        }
    }
    
    private var tabTitle: String {
        switch selectedTab {
        case 0: return "均衡器"
        case 1: return "HiFi"
        default: return "智能"
        }
    }
    
    private func resetCurrent() {
        switch selectedTab {
        case 0: eqManager.reset()
        case 1: hifiEngine.reset()
        default: break
        }
    }
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                let titles = ["均衡器", "HiFi", "智能"]
                Button(action: { withAnimation(.spring(response: 0.3)) { selectedTab = index } }) {
                    Text(titles[index])
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(selectedTab == index ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == index ? Color.black : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private func startSpectrumUpdate() {
        spectrumTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let result = eqManager.analysisResult {
                withAnimation(.easeOut(duration: 0.1)) {
                    spectrumValues = result.spectrumEnergy
                }
            }
        }
    }
    
    private func stopSpectrumUpdate() {
        spectrumTimer?.invalidate()
        spectrumTimer = nil
    }

    // MARK: - EQ Content
    
    private var eqContent: some View {
        VStack(spacing: 20) {
            // 开关
            EQSection(title: "均衡器") {
                EQToggleRow(
                    icon: .eq,
                    title: "启用均衡器",
                    subtitle: "实时音频处理",
                    isOn: $eqManager.isEnabled
                )
            }
            
            // 预设选择
            EQSection(title: "预设") {
                VStack(spacing: 16) {
                    ForEach(EQPreset.grouped, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.category)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(group.presets) { preset in
                                        EQPresetButton(
                                            title: preset.rawValue,
                                            isSelected: eqManager.currentPreset == preset && eqManager.currentCustomPresetId == nil
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                eqManager.applyPreset(preset)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            
            // 自定义预设
            if !eqManager.customPresets.isEmpty {
                EQSection(title: "我的预设 (\(eqManager.customPresets.count)/\(AudioEQManager.maxCustomPresets))") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(eqManager.customPresets) { preset in
                                EQCustomPresetButton(
                                    preset: preset,
                                    isSelected: eqManager.currentCustomPresetId == preset.id,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            eqManager.applyCustomPreset(preset)
                                        }
                                    },
                                    onDelete: {
                                        presetToDelete = preset
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            
            // EQ 滑块
            EQSection(title: "频段调节") {
                VStack(spacing: 16) {
                    // 频率标签
                    HStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { index in
                            Text(AudioEQManager.frequencyLabels[index])
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // 滑块
                    HStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { index in
                            VStack(spacing: 8) {
                                Text(String(format: "%+.0f", eqManager.bands[index]))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(gainColor(for: eqManager.bands[index]))
                                
                                EQVerticalSlider(
                                    value: Binding(
                                        get: { eqManager.bands[index] },
                                        set: { eqManager.setBand(index, gain: $0) }
                                    ),
                                    range: -12...12
                                )
                                .frame(height: 140)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // dB 标签
                    HStack {
                        Text("+12 dB")
                        Spacer()
                        Text("0 dB")
                        Spacer()
                        Text("-12 dB")
                    }
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.gray.opacity(0.6))
                }
                .padding(16)
                .opacity(eqManager.isEnabled ? 1 : 0.4)
            }
            .disabled(!eqManager.isEnabled)
            
            // 保存按钮
            if eqManager.currentPreset == .custom && eqManager.customPresets.count < AudioEQManager.maxCustomPresets {
                Button(action: { showSaveSheet = true }) {
                    HStack {
                        AsideIcon(icon: .save, size: 14, color: .white)
                        Text("保存为预设")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func gainColor(for gain: Float) -> Color {
        if gain > 0 { return .green }
        else if gain < 0 { return .orange }
        return .gray
    }
    
    private var savePresetSheet: some View {
        NavigationStack {
            ZStack {
                AsideBackground().ignoresSafeArea()
                
                VStack(spacing: 20) {
                    TextField("预设名称", text: $newPresetName)
                        .font(.system(size: 16, design: .rounded))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 10)
                        .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("保存预设")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        newPresetName = ""
                        showSaveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if eqManager.saveCurrentAsPreset(name: newPresetName) {
                            newPresetName = ""
                            showSaveSheet = false
                        }
                    }
                    .disabled(newPresetName.isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - HiFi Content
    
    private var hifiContent: some View {
        VStack(spacing: 20) {
            // 开关
            EQSection(title: "HiFi 引擎") {
                EQToggleRow(
                    icon: .soundQuality,
                    title: "启用 HiFi",
                    subtitle: "专业级音频增强",
                    isOn: $hifiEngine.isEnabled
                )
            }
            
            // 空间音效
            EQSection(title: "空间音效") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("增强立体声宽度和空间感")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SpatialMode.allCases) { mode in
                                EQOptionButton(
                                    title: mode.rawValue,
                                    isSelected: hifiEngine.spatialMode == mode
                                ) {
                                    hifiEngine.spatialMode = mode
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .opacity(hifiEngine.isEnabled ? 1 : 0.4)
            .disabled(!hifiEngine.isEnabled)
            
            // 3D 环绕
            EQSection(title: "3D 环绕") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("模拟环绕声效果，适合耳机")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Surround3DMode.allCases) { mode in
                                EQOptionButton(
                                    title: mode.rawValue,
                                    isSelected: hifiEngine.surround3D == mode
                                ) {
                                    hifiEngine.surround3D = mode
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .opacity(hifiEngine.isEnabled ? 1 : 0.4)
            .disabled(!hifiEngine.isEnabled)
            
            // 低音增强
            EQSection(title: "低音增强") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("增强低频响应")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(BassBoostMode.allCases) { mode in
                                EQOptionButton(
                                    title: mode.rawValue,
                                    isSelected: hifiEngine.bassBoost == mode
                                ) {
                                    hifiEngine.bassBoost = mode
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .opacity(hifiEngine.isEnabled ? 1 : 0.4)
            .disabled(!hifiEngine.isEnabled)
            
            // 高级选项
            EQSection(title: "高级") {
                VStack(spacing: 0) {
                    EQToggleRow(
                        icon: .play,
                        title: "动态范围压缩",
                        subtitle: "平衡音量差异",
                        isOn: $hifiEngine.dynamicRange
                    )
                    
                    Divider().padding(.leading, 56)
                    
                    EQToggleRow(
                        icon: .soundQuality,
                        title: "响度均衡",
                        subtitle: "自动调整音量",
                        isOn: $hifiEngine.loudnessNorm
                    )
                }
            }
            .opacity(hifiEngine.isEnabled ? 1 : 0.4)
            .disabled(!hifiEngine.isEnabled)
        }
    }

    // MARK: - Smart Content
    
    private var smartContent: some View {
        VStack(spacing: 20) {
            // 智能模式开关
            EQSection(title: "智能音效") {
                VStack(spacing: 0) {
                    EQToggleRow(
                        icon: .sparkle,
                        title: "智能模式",
                        subtitle: "自动识别音乐类型，智能调节",
                        isOn: $eqManager.smartModeEnabled
                    )
                    
                    if eqManager.smartModeEnabled {
                        Divider().padding(.leading, 56)
                        
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.purple)
                                    .frame(width: 32, height: 32)
                                
                                AsideIcon(icon: .sparkle, size: 16, color: .white)
                            }
                            
                            Text("智能模式已启用，正在分析音频...")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.purple)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
            
            // 实时频谱
            EQSection(title: "实时频谱") {
                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(0..<10, id: \.self) { index in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(spectrumGradient(for: index))
                                    .frame(height: spectrumBarHeight(for: index))
                                
                                Text(AudioEQManager.frequencyLabels[index])
                                    .font(.system(size: 8, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 100)
                }
                .padding(16)
            }
            
            // 检测结果
            if eqManager.smartModeEnabled {
                EQSection(title: "检测结果") {
                    HStack(spacing: 12) {
                        // 音乐类型
                        EQInfoCard(
                            icon: .musicNoteList,
                            iconColor: .cyan,
                            title: eqManager.detectedGenre.rawValue,
                            subtitle: "音乐类型"
                        )
                        
                        // 人声
                        if let result = eqManager.analysisResult {
                            EQInfoCard(
                                icon: .like,
                                iconColor: .green,
                                title: "\(Int(result.vocalPresence * 100))%",
                                subtitle: "人声"
                            )
                            
                            // 噪声
                            EQInfoCard(
                                icon: .soundQuality,
                                iconColor: result.needsDenoising ? .orange : .blue,
                                title: "\(Int(result.noiseFloor)) dB",
                                subtitle: "噪声"
                            )
                        }
                    }
                    .padding(16)
                }
            }
            
            // 智能降噪
            EQSection(title: "智能降噪") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("基于频谱分析的实时噪声抑制")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(NoiseReductionMode.allCases) { mode in
                                EQOptionButton(
                                    title: mode.rawValue,
                                    isSelected: eqManager.noiseReductionMode == mode
                                ) {
                                    eqManager.noiseReductionMode = mode
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            
            // 手动应用推荐
            if !eqManager.smartModeEnabled {
                Button(action: { eqManager.applyRecommendedEQ() }) {
                    HStack {
                        AsideIcon(icon: .sparkle, size: 16, color: .white)
                        Text("应用推荐 EQ")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func spectrumGradient(for index: Int) -> LinearGradient {
        let colors: [Color] = index < 3 ? [.red, .orange] :
                              index < 7 ? [.green, .cyan] : [.blue, .purple]
        return LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top)
    }
    
    private func spectrumBarHeight(for index: Int) -> CGFloat {
        let value = spectrumValues[index]
        let normalized = (value + 60) / 60
        return max(8, CGFloat(normalized) * 80)
    }
}


// MARK: - Supporting Components

struct EQSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct EQToggleRow: View {
    let icon: AsideIcon.IconType
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 32, height: 32)
                
                AsideIcon(icon: icon, size: 16, color: .white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.black)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct EQPresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black : Color.black.opacity(0.05))
                )
        }
    }
}

struct EQCustomPresetButton: View {
    let preset: CustomEQPreset
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(preset.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .black)
                
                if isSelected {
                    Button(action: onDelete) {
                        AsideIcon(icon: .close, size: 12, color: .white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.purple : Color.black.opacity(0.05))
            )
        }
    }
}

struct EQOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black : Color.black.opacity(0.05))
                )
        }
    }
}

struct EQInfoCard: View {
    let icon: AsideIcon.IconType
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                AsideIcon(icon: icon, size: 18, color: iconColor)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
            
            Text(subtitle)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.02))
        .cornerRadius(12)
    }
}

struct EQVerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let yPosition = height * (1 - CGFloat(normalizedValue))
            
            ZStack(alignment: .bottom) {
                // 轨道
                Capsule()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 4)
                
                // 填充
                Capsule()
                    .fill(Color.black)
                    .frame(width: 4, height: max(0, height - yPosition))
                
                // 滑块
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 18 : 14, height: isDragging ? 18 : 14)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .position(x: geometry.size.width / 2, y: yPosition)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newY = gesture.location.y
                        let clampedY = max(0, min(height, newY))
                        let normalizedY = 1 - (clampedY / height)
                        let newValue = range.lowerBound + Float(normalizedY) * (range.upperBound - range.lowerBound)
                        value = round(newValue)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
}

#Preview {
    EQView()
}
