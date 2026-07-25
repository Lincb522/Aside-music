// [DEPRECATED] 音频实验室界面 - 智能音效分析与推荐
// 该功能已废弃，代码保留仅供参考，不再在 UI 中使用

import SwiftUI

struct AudioLabView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var labManager = AudioLabManager.shared
    @StateObject private var eqManager = EQManager.shared
    
    /// 显示应用成功的提示
    @State private var showAppliedToast = false
    
    var body: some View {
        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // 智能音效开关
                        smartEffectsToggle
                            .padding(.top, 16)
                        
                        // 当前分析结果
                        if labManager.isSmartEffectsEnabled {
                            if labManager.isAnalyzing {
                                analyzingCard
                            } else if let analysis = labManager.currentAnalysis {
                                analysisResultCard(analysis)
                            } else {
                                noAnalysisCard
                            }
                        }
                        
                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
            
            // 应用成功提示
            if showAppliedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .checkmark, size: 16, color: .monologueAccentForeground)
                        Text("已应用智能音效")
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.monologueAccentForeground)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.monologueAccent)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .themedNavigationChrome(title: String(localized: "settings_audio_lab"), eyebrow: "LAB", icon: .equalizer)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    // MARK: - 智能音效开关
    
    private var smartEffectsToggle: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(labManager.isSmartEffectsEnabled ? Color.monologueAccent.opacity(0.15) : Color.monologueSeparator)
                        .frame(width: 44, height: 44)
                    MonologueIcon(icon: .sparkle, size: 20, color: labManager.isSmartEffectsEnabled ? .monologueAccent : .monologueTextSecondary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("智能音效")
                        .font(.rounded(size: 16, weight: .semibold))
                        .foregroundColor(.monologueTextPrimary)
                    Text(labManager.isSmartEffectsEnabled ? String(localized: "自动分析并优化音效") : String(localized: "手动调节音效参数"))
                        .font(.rounded(size: 13))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Toggle("", isOn: $labManager.isSmartEffectsEnabled)
                    .labelsHidden()
                    .tint(Color(light: .black, dark: Color(white: 0.55)))
            }
            
            // 分析模式选择
            if labManager.isSmartEffectsEnabled {
                HStack(spacing: 8) {
                    ForEach(AudioLabManager.AnalysisMode.allCases, id: \.rawValue) { mode in
                        analysisModeButton(mode)
                    }
                }
            }
        }
        .padding(16)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? 18 : 16, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }
    
    private func analysisModeButton(_ mode: AudioLabManager.AnalysisMode) -> some View {
        let isSelected = labManager.analysisMode == mode
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                labManager.analysisMode = mode
            }
        }) {
            VStack(spacing: 4) {
                MonologueIcon(
                    icon: mode == .file ? .download : .waveform,
                    size: 16,
                    color: isSelected ? .monologueAccentForeground : .monologueTextSecondary
                )
                Text(mode.rawValue)
                    .font(.rounded(size: 12, weight: .medium))
                Text(mode == .file ? String(localized: "更准确") : String(localized: "更快速"))
                    .font(.rounded(size: 10))
                    .foregroundColor(isSelected ? .monologueAccentForeground.opacity(0.8) : .monologueTextSecondary.opacity(0.6))
            }
            .foregroundColor(isSelected ? .monologueAccentForeground : .monologueTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.monologueAccent : Color.monologueSeparator)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 分析中卡片
    
    private var analyzingCard: some View {
        VStack(spacing: 16) {
            // 动画指示器
            ZStack {
                Circle()
                    .stroke(Color.monologueSeparator, lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(labManager.analysisProgress))
                    .stroke(Color.monologueAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: labManager.analysisProgress)
                
                MonologueIcon(icon: .waveform, size: 24, color: .monologueAccent)
            }
            
            Text("正在分析音频特征...")
                .font(.rounded(size: 15, weight: .medium))
                .foregroundColor(.monologueTextPrimary)
            
            Text("分析 BPM、频谱、动态范围等")
                .font(.rounded(size: 13))
                .foregroundColor(.monologueTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? 18 : 16, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }
    
    // MARK: - 分析结果卡片
    
    private func analysisResultCard(_ analysis: AudioAnalysisResult) -> some View {
        VStack(spacing: 20) {
            // 推荐风格 + 置信度
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("识别风格")
                        .font(.rounded(size: 13))
                        .foregroundColor(.monologueTextSecondary)
                    HStack(spacing: 8) {
                        Text(analysis.suggestedGenre.rawValue)
                            .font(.rounded(size: 24, weight: .bold))
                            .foregroundColor(.monologueAccent)
                        
                        // BPM 置信度指示
                        if analysis.bpmConfidence > 0.7 {
                            Text("高置信度")
                                .font(.rounded(size: 10, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // 重新分析按钮
                Button(action: {
                    Task {
                        await labManager.forceReanalyze()
                    }
                }) {
                    HStack(spacing: 6) {
                        MonologueIcon(icon: .refresh, size: 14, color: .monologueTextSecondary)
                        Text("重新分析")
                            .font(.rounded(size: 13, weight: .medium))
                    }
                    .foregroundColor(.monologueTextSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.monologueSeparator)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(Color.monologueSeparator)
            
            // 分析数据
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                analysisItem(title: "BPM", value: String(format: "%.0f", analysis.bpm))
                analysisItem(title: String(localized: "低频"), value: String(format: "%.0f%%", analysis.lowFrequencyRatio * 100))
                analysisItem(title: String(localized: "中频"), value: String(format: "%.0f%%", analysis.midFrequencyRatio * 100))
                analysisItem(title: String(localized: "高频"), value: String(format: "%.0f%%", analysis.highFrequencyRatio * 100))
                analysisItem(title: String(localized: "亮度"), value: String(format: "%.0fHz", analysis.spectralCentroid))
                analysisItem(title: String(localized: "动态"), value: String(format: "%.0fdB", analysis.dynamicRange))
            }
            
            // 响度信息（文件分析模式才有）
            if analysis.loudness < 0 {
                HStack(spacing: 16) {
                    analysisItem(title: String(localized: "响度"), value: String(format: "%.1f LUFS", analysis.loudness))
                }
            }
            
            // 音色分析
            if let timbre = analysis.timbreAnalysis {
                Divider()
                    .background(Color.monologueSeparator)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("音色分析")
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.monologueTextPrimary)
                    
                    Text(timbre.description)
                        .font(.rounded(size: 15, weight: .medium))
                        .foregroundColor(.monologueAccent)
                    
                    // 音色指标条
                    HStack(spacing: 12) {
                        timbreBar(label: String(localized: "亮度"), value: timbre.brightness)
                        timbreBar(label: String(localized: "温暖"), value: timbre.warmth)
                        timbreBar(label: String(localized: "清晰"), value: timbre.clarity)
                        timbreBar(label: String(localized: "丰满"), value: timbre.fullness)
                    }
                    
                    if !timbre.eqSuggestion.isEmpty && timbre.eqSuggestion != String(localized: "音色均衡") {
                        Text("建议：\(timbre.eqSuggestion)")
                            .font(.rounded(size: 12))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }
            
            // 质量评估（文件分析模式才有）
            if let quality = analysis.qualityAssessment {
                Divider()
                    .background(Color.monologueSeparator)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("质量评估")
                            .font(.rounded(size: 14, weight: .semibold))
                            .foregroundColor(.monologueTextPrimary)
                        
                        Spacer()
                        
                        Text(quality.grade)
                            .font(.rounded(size: 14, weight: .bold))
                            .foregroundColor(qualityColor(score: quality.overallScore))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(qualityColor(score: quality.overallScore).opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 16) {
                        qualityScoreItem(title: String(localized: "总体"), score: quality.overallScore)
                        qualityScoreItem(title: String(localized: "动态"), score: quality.dynamicScore)
                        qualityScoreItem(title: String(localized: "频率"), score: quality.frequencyScore)
                    }
                    
                    if !quality.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(quality.issues, id: \.self) { issue in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 4, height: 4)
                                    Text(issue)
                                        .font(.rounded(size: 12))
                                        .foregroundColor(.monologueTextSecondary)
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.monologueSeparator)
            
            // 推荐设置
            VStack(alignment: .leading, spacing: 12) {
                Text("智能音效")
                    .font(.rounded(size: 14, weight: .semibold))
                    .foregroundColor(.monologueTextPrimary)
                
                HStack(spacing: 12) {
                    recommendedTag(L10n.format(
                        "audio_effect_decibel_format",
                        String(localized: "低音"),
                        analysis.recommendedEffects.bassGain
                    ))
                    recommendedTag(L10n.format(
                        "audio_effect_decibel_format",
                        String(localized: "eq_treble"),
                        analysis.recommendedEffects.trebleGain
                    ))
                    recommendedTag(L10n.format(
                        "audio_effect_percent_format",
                        String(localized: "eq_surround"),
                        Int(analysis.recommendedEffects.surroundLevel * 100)
                    ))
                }
                
                HStack(spacing: 12) {
                    recommendedTag(L10n.format(
                        "audio_effect_percent_format",
                        String(localized: "eq_reverb"),
                        Int(analysis.recommendedEffects.reverbLevel * 100)
                    ))
                    recommendedTag(L10n.format(
                        "audio_effect_multiplier_format",
                        String(localized: "声场"),
                        analysis.recommendedEffects.stereoWidth
                    ))
                    if analysis.recommendedEffects.loudnormEnabled {
                        recommendedTag(String(localized: "eq_loudness_normalization"))
                    }
                }
            }
            
            // 智能 EQ 曲线预览
            VStack(alignment: .leading, spacing: 8) {
                Text("智能 EQ 曲线")
                    .font(.rounded(size: 14, weight: .semibold))
                    .foregroundColor(.monologueTextPrimary)
                
                smartEQCurveView(gains: analysis.recommendedEffects.eqGains)
                    .frame(height: 80)
            }
            
            // 应用按钮
            Button(action: {
                // 触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // 应用设置
                labManager.applyCurrentAnalysis()
                
                // 显示成功提示
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAppliedToast = true
                }
                
                // 2秒后隐藏提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showAppliedToast = false
                    }
                }
            }) {
                HStack(spacing: 8) {
                    MonologueIcon(icon: .checkmark, size: 16, color: .monologueAccentForeground)
                    Text("应用推荐设置")
                        .font(.rounded(size: 15, weight: .semibold))
                }
                .foregroundColor(.monologueAccentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.monologueAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? 18 : 16, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }
    
    // 音色指标条
    private func timbreBar(label: String, value: Float) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.monologueSeparator)
                        .frame(width: 8)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.monologueAccent)
                        .frame(width: 8, height: geo.size.height * CGFloat(value))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 40)
            
            Text(label)
                .font(.rounded(size: 10))
                .foregroundColor(.monologueTextSecondary)
        }
    }
    
    // 质量评分项
    private func qualityScoreItem(title: String, score: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(qualityColor(score: score))
            Text(title)
                .font(.rounded(size: 11))
                .foregroundColor(.monologueTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // 质量颜色
    private func qualityColor(score: Int) -> Color {
        if score >= 90 { return .green }
        if score >= 75 { return .monologueAccent }
        if score >= 60 { return .orange }
        return .red
    }
    
    private func analysisItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
            Text(title)
                .font(.rounded(size: 12))
                .foregroundColor(.monologueTextSecondary)
        }
    }
    
    private func recommendedTag(_ text: String) -> some View {
        Text(text)
            .font(.rounded(size: 12, weight: .medium))
            .foregroundColor(.monologueAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.monologueAccent.opacity(0.1))
            .clipShape(Capsule())
    }
    
    // MARK: - 智能 EQ 曲线预览
    
    private func smartEQCurveView(gains: [Float]) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = gains.count
            let spacing = w / CGFloat(count)
            
            ZStack {
                // 背景网格
                ForEach([0.25, 0.5, 0.75], id: \.self) { ratio in
                    Path { path in
                        let y = h * CGFloat(ratio)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.monologueSeparator.opacity(0.3), lineWidth: 0.5)
                }
                
                // 中线（0dB）
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.5))
                    path.addLine(to: CGPoint(x: w, y: h * 0.5))
                }
                .stroke(Color.monologueTextSecondary.opacity(0.3), lineWidth: 1)
                
                // EQ 曲线
                let points = gains.enumerated().map { (i, gain) -> CGPoint in
                    let x = spacing * CGFloat(i) + spacing / 2
                    let normalized = CGFloat((gain + 12) / 24) // -12~+12 → 0~1
                    let y = h * (1 - normalized)
                    return CGPoint(x: x, y: y)
                }
                
                if points.count >= 2 {
                    // 填充区域
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: h * 0.5))
                        path.addLine(to: points[0])
                        for i in 1..<points.count {
                            let prev = points[i - 1]
                            let curr = points[i]
                            let midX = (prev.x + curr.x) / 2
                            path.addCurve(to: curr,
                                          control1: CGPoint(x: midX, y: prev.y),
                                          control2: CGPoint(x: midX, y: curr.y))
                        }
                        if let lastPt = points.last {
                            path.addLine(to: CGPoint(x: lastPt.x, y: h * 0.5))
                        }
                        path.closeSubpath()
                    }
                    .fill(Color.monologueAccent.opacity(0.2))
                    
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
                    .stroke(Color.monologueAccent, lineWidth: 2)
                    
                    // 节点
                    ForEach(0..<points.count, id: \.self) { i in
                        Circle()
                            .fill(Color.monologueAccent)
                            .frame(width: 6, height: 6)
                            .position(points[i])
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.monologueSeparator.opacity(0.2))
        )
    }
    
    // MARK: - 无分析结果卡片
    
    private var noAnalysisCard: some View {
        VStack(spacing: 16) {
            MonologueIcon(icon: .waveform, size: 40, color: .monologueTextSecondary.opacity(0.5))
            
            Text("播放音乐后自动分析")
                .font(.rounded(size: 15, weight: .medium))
                .foregroundColor(.monologueTextPrimary)
            
            Text("智能识别音乐风格，推荐最佳音效设置")
                .font(.rounded(size: 13))
                .foregroundColor(.monologueTextSecondary)
                .multilineTextAlignment(.center)
            
            // 手动分析按钮
            if PlayerManager.shared.currentSong != nil {
                Button(action: {
                    Task {
                        await labManager.analyzeCurrentSong()
                    }
                }) {
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .sparkle, size: 16, color: .monologueAccent)
                        Text("立即分析")
                            .font(.rounded(size: 14, weight: .medium))
                    }
                    .foregroundColor(.monologueAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.monologueAccent.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? 18 : 16, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }
    
    // MARK: - 功能说明卡片
    
    private var featureDescriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("功能说明")
                .font(.rounded(size: 16, weight: .semibold))
                .foregroundColor(.monologueTextPrimary)
            
            featureRow(icon: .waveform, title: String(localized: "频谱分析"), description: String(localized: "分析音频的频率分布特征"))
            featureRow(icon: .musicNote, title: String(localized: "风格识别"), description: String(localized: "智能识别流行、摇滚、电子等风格"))
            featureRow(icon: .settings, title: String(localized: "参数优化"), description: String(localized: "自动调整 EQ、环绕、混响等参数"))
            featureRow(icon: .headphones, title: String(localized: "实时适配"), description: String(localized: "切歌时自动分析并应用最佳设置"))
            
            Divider()
                .background(Color.monologueSeparator)
            
            Text("分析模式")
                .font(.rounded(size: 14, weight: .semibold))
                .foregroundColor(.monologueTextPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    MonologueIcon(icon: .download, size: 14, color: .monologueAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("文件分析")
                            .font(.rounded(size: 13, weight: .medium))
                            .foregroundColor(.monologueTextPrimary)
                        Text("解码音频文件进行完整分析，包括 BPM 检测、响度测量、动态范围、音色分析等，结果更准确")
                            .font(.rounded(size: 11))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 8) {
                    MonologueIcon(icon: .waveform, size: 14, color: .monologueAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("实时分析")
                            .font(.rounded(size: 13, weight: .medium))
                            .foregroundColor(.monologueTextPrimary)
                        Text("使用播放时的频谱数据进行快速分析，速度更快但准确度较低")
                            .font(.rounded(size: 11))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }
        }
        .padding(20)
        .themedPageSurface(cornerRadius: MangaStyle.isActive ? 18 : 16, elevated: true, mangaTint: MangaStyle.bubbleWhite)
    }
    
    private func featureRow(icon: MonologueIcon.IconType, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.monologueSeparator)
                    .frame(width: 36, height: 36)
                MonologueIcon(icon: icon, size: 16, color: .monologueTextSecondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rounded(size: 14, weight: .medium))
                    .foregroundColor(.monologueTextPrimary)
                Text(description)
                    .font(.rounded(size: 12))
                    .foregroundColor(.monologueTextSecondary)
            }
            
            Spacer()
        }
    }
}
