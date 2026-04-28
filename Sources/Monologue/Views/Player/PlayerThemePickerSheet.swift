import SwiftUI

/// 播放器主题选择面板 — 毛玻璃背景 + 精致卡片预览
struct PlayerThemePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.monologueSheetContext) private var monologueSheetContext
    @State private var themeManager = PlayerThemeManager.shared

    var body: some View {
        VStack(spacing: 16) {
            if monologueSheetContext == nil {
                Capsule()
                    .fill(Color.monologueTextSecondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
            }

            // 标题
            Text("theme_title")
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .rounded(size: 20, weight: .bold))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                .padding(.bottom, 4)

            // 主题卡片网格 - 使用 ScrollView 确保内容可滚动
            ScrollView(.vertical) {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(PlayerTheme.allCases, id: \.self) { theme in
                        themeCard(theme)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .iPadContentWidth(600)
        .background(sheetBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var sheetBackground: some View {
        Color.clear
    }

    private func themeCard(_ theme: PlayerTheme) -> some View {
        let isSelected = themeManager.currentTheme == theme

        return Button {
            themeManager.setTheme(theme)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
            }
        } label: {
            VStack(spacing: 10) {
                // 预览区域
                themePreview(theme)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                            .stroke(
                                previewStrokeColor(isSelected: isSelected),
                                lineWidth: isSelected ? (NeumorphicStyle.isActive ? 1.4 : 2.5) : 1
                            )
                    )
                    .shadow(
                        color: previewShadowColor(isSelected: isSelected),
                        radius: NeumorphicStyle.isActive ? 10 : 8,
                        x: 0,
                        y: NeumorphicStyle.isActive ? 6 : 4
                    )

                // 标签
                HStack(spacing: 6) {
                    if isSelected {
                        MonologueIcon(icon: .checkmark, size: 13, color: selectedTint)
                    }

                    Text(theme.displayName)
                        .font(themeLabelFont(isSelected: isSelected))
                        .foregroundColor(isSelected ? selectedLabelColor : secondaryLabelColor)
                }
            }
            .padding(NeumorphicStyle.isActive ? 10 : 0)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(
                        cornerRadius: 24,
                        elevated: !isSelected,
                        pressed: isSelected,
                        tint: isSelected ? selectedTint.opacity(0.18) : nil
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var previewCornerRadius: CGFloat {
        NeumorphicStyle.isActive ? 18 : 16
    }

    private var selectedTint: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueAccent
    }

    private var selectedLabelColor: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
    }

    private var secondaryLabelColor: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary
    }

    private func themeLabelFont(isSelected: Bool) -> Font {
        NeumorphicStyle.isActive
            ? NeumorphicStyle.labelFont(14, weight: isSelected ? .semibold : .medium)
            : .rounded(size: 14, weight: isSelected ? .bold : .medium)
    }

    private func previewStrokeColor(isSelected: Bool) -> Color {
        if NeumorphicStyle.isActive {
            return isSelected ? NeumorphicStyle.accent.opacity(0.52) : NeumorphicStyle.separator.opacity(0.38)
        }
        return isSelected
            ? Color.monologueAccent
            : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.monologueSeparator)
    }

    private func previewShadowColor(isSelected: Bool) -> Color {
        if NeumorphicStyle.isActive {
            return isSelected ? NeumorphicStyle.darkShadow(colorScheme, intensity: 0.22) : .clear
        }
        return isSelected
            ? Color.monologueAccent.opacity(colorScheme == .dark ? 0.3 : 0.15)
            : Color.clear
    }

    /// 每种主题的缩略预览
    @ViewBuilder
    private func themePreview(_ theme: PlayerTheme) -> some View {
        switch theme {
        case .classic:
            classicPreview
        case .vinyl:
            vinylPreview
        case .lyricFocus:
            lyricFocusPreview
        case .card:
            cardPreview
        case .neumorphic:
            neumorphicPreview
        case .poster:
            posterPreview
        case .motoPager:
            motoPagerPreview
        case .typewriter:
            typewriterPreview
        case .pixel:
            pixelPreview
        case .aqua:
            aquaPreview
        case .breathing:
            breathingPreview
        case .cassette:
            cassettePreview
        case .radio:
            radioPreview
        case .immersiveLyric:
            immersiveLyricPreview
        case .mangaChat:
            mangaChatPreview
        case .folk:
            folkPreview
        case .game2048:
            game2048Preview
        }
    }

    // MARK: - 经典预览
    private var classicPreview: some View {
        ClassicThemePreview()
    }

    // MARK: - 黑胶预览
    private var vinylPreview: some View {
        VinylThemePreview()
    }

    // MARK: - 歌词预览
    private var lyricFocusPreview: some View {
        LyricFocusThemePreview()
    }

    // MARK: - 卡片预览
    private var cardPreview: some View {
        CardThemePreview()
    }

    // MARK: - 新拟物预览
    private var neumorphicPreview: some View {
        NeumorphicThemePreview()
    }
    
    // MARK: - 大字报预览
    private var posterPreview: some View {
        PosterThemePreview()
    }
    
    // MARK: - 寻呼机预览
    private var motoPagerPreview: some View {
        MotoPagerThemePreview()
    }

    // MARK: - 打字机预览
    private var typewriterPreview: some View {
        TypewriterThemePreview()
    }
    
    // MARK: - 像素预览
    private var pixelPreview: some View {
        PixelThemePreview()
    }
    
    // MARK: - 水韵预览
    private var aquaPreview: some View {
        let isDark = colorScheme == .dark
        
        return ZStack {
            // 水面渐变背景
            LinearGradient(
                colors: isDark
                    ? [Color(hex: "0B1A2B"), Color(hex: "154360"), Color(hex: "1A5276")]
                    : [.white, Color(hex: "D6EAF8"), Color(hex: "85C1E9")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 水波纹同心圆
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        isDark ? Color.white.opacity(0.06 - Double(i) * 0.015) : Color(hex: "3A8FB7").opacity(0.12 - Double(i) * 0.03),
                        lineWidth: 1
                    )
                    .frame(width: CGFloat(30 + i * 28), height: CGFloat(30 + i * 28))
                    .offset(y: 10)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // 水滴涟漪中心
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isDark
                                ? [Color(hex: "7EC8E3").opacity(0.4), Color.clear]
                                : [Color(hex: "3A8FB7").opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .offset(y: -10)
                
                Spacer().frame(height: 16)
                
                // 气泡控制按钮
                HStack(spacing: 12) {
                    Circle()
                        .fill(isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.6))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(isDark ? Color.white.opacity(0.15) : Color(hex: "85C1E9"), lineWidth: 0.5))
                    
                    // 播放气泡（大）
                    Circle()
                        .fill(isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(isDark ? Color.white.opacity(0.2) : Color(hex: "5DADE2"), lineWidth: 0.8))
                        .overlay(
                            MonologueIcon(icon: .play, size: 10, color: isDark ? .white.opacity(0.5) : Color(hex: "2E86C1"))
                        )
                        .shadow(color: isDark ? Color(hex: "7EC8E3").opacity(0.2) : Color(hex: "5DADE2").opacity(0.3), radius: 6)
                    
                    Circle()
                        .fill(isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.6))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(isDark ? Color.white.opacity(0.15) : Color(hex: "85C1E9"), lineWidth: 0.5))
                }
                
                Spacer().frame(height: 12)
            }
            
            // 漂浮小气泡装饰
            Circle()
                .fill(isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.5))
                .frame(width: 5, height: 5)
                .offset(x: -35, y: 20)
            Circle()
                .fill(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.35))
                .frame(width: 3, height: 3)
                .offset(x: 40, y: 30)
            Circle()
                .fill(isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.4))
                .frame(width: 4, height: 4)
                .offset(x: 25, y: -15)
        }
    }

    // MARK: - 呼吸体预览
    private var breathingPreview: some View {
        let bgTop = colorScheme == .dark ? Color(hex: "06080C") : Color(hex: "F5F6FA")
        let bgBottom = colorScheme == .dark ? Color(hex: "111621") : Color(hex: "E9ECF5")
        let accentA = colorScheme == .dark ? Color(hex: "9E8CFF") : Color(hex: "6E5DFF")
        let accentB = colorScheme == .dark ? Color(hex: "5AD4FF") : Color(hex: "2BB8F2")
        let text = colorScheme == .dark ? Color.white.opacity(0.9) : Color(hex: "10131A")

        return ZStack {
            LinearGradient(
                colors: [bgTop, bgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accentA.opacity(0.18))
                .frame(width: 96, height: 96)
                .blur(radius: 24)
                .offset(x: -8, y: -8)

            ForEach(0..<24, id: \.self) { index in
                let fraction = Double(index) / 24.0
                let angle = fraction * .pi * 2
                let x = CGFloat(cos(angle)) * 42
                let y = CGFloat(sin(angle)) * 34

                Circle()
                    .fill(fraction < 0.6 ? text.opacity(0.9) : accentB.opacity(0.18))
                    .frame(width: fraction < 0.6 ? 5 : 3, height: fraction < 0.6 ? 5 : 3)
                    .offset(x: x, y: y)
            }

            BreathingBlobShape(amplitude: 7, phase: 0.6, lobes: 5, twist: 0.08)
                .fill(
                    LinearGradient(
                        colors: [accentA, accentB, Color.white.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)
                .overlay(
                    Text("LIVE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(text)
                )
                .shadow(color: accentA.opacity(0.32), radius: 18, x: 0, y: 10)
        }
    }

    // MARK: - 磁带预览
    private var cassettePreview: some View {
        let bgColor = colorScheme == .dark ? Color(hex: "1F1F24") : Color(hex: "E8E8E3")
        let shellColor = colorScheme == .dark ? Color(hex: "2A2A30") : Color.white
        let labelColor = colorScheme == .dark ? Color(hex: "E0E0D6") : Color(hex: "F4F4EB")
        
        return ZStack {
            bgColor
            
            // 磁带外壳
            RoundedRectangle(cornerRadius: 6)
                .fill(shellColor)
                .frame(width: 80, height: 50)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.1), lineWidth: 1))
            
            VStack(spacing: 2) {
                // 顶部防误擦除孔
                HStack {
                    RoundedRectangle(cornerRadius: 1).fill(Color.black.opacity(0.1)).frame(width: 6, height: 4)
                    Spacer().frame(width: 40)
                    RoundedRectangle(cornerRadius: 1).fill(Color.black.opacity(0.1)).frame(width: 6, height: 4)
                }
                .padding(.top, 2)
                
                // 贴纸 (Label)
                RoundedRectangle(cornerRadius: 2)
                    .fill(labelColor)
                    .frame(width: 66, height: 28)
                    .overlay(
                        VStack(spacing: 0) {
                            // 红色横条纹
                            Rectangle().fill(Color(hex: "E74C3C")).frame(height: 3)
                            Rectangle().fill(Color(hex: "E67E22")).frame(height: 3)
                            Rectangle().fill(Color(hex: "F1C40F")).frame(height: 3)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 4)
                    )
                    .overlay(
                        // 磁带大孔
                        HStack(spacing: 16) {
                            Circle().fill(bgColor).frame(width: 14, height: 14)
                                .overlay(Circle().fill(Color.black).frame(width: 4, height: 4))
                            Circle().fill(bgColor).frame(width: 14, height: 14)
                                .overlay(Circle().fill(Color.black).frame(width: 4, height: 4))
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.black.opacity(0.05), lineWidth: 1))
                
                // 底部梯形槽
                Path { path in
                    path.move(to: CGPoint(x: 10, y: 0))
                    path.addLine(to: CGPoint(x: 40, y: 0))
                    path.addLine(to: CGPoint(x: 45, y: 8))
                    path.addLine(to: CGPoint(x: 5, y: 8))
                    path.closeSubpath()
                }
                .fill(Color.black.opacity(0.05))
                .frame(width: 50, height: 8)
                
                Spacer().frame(height: 2)
            }
        }
    }

    // MARK: - 收音机预览
    private var radioPreview: some View {
        RadioThemePreview()
    }
    
    // MARK: - 沉浸歌词预览
    private var immersiveLyricPreview: some View {
        ImmersiveLyricThemePreview()
    }

    // MARK: - 漫画聊天预览
    private var mangaChatPreview: some View {
        MangaChatThemePreview()
    }

    // MARK: - 民谣预览

    private var folkPreview: some View {
        FolkThemePreview()
    }

    // MARK: - 2048 预览
    private var game2048Preview: some View {
        // 动态 2048 预览 — 展示随机布局的迷你棋盘
        Game2048MiniPreview()
    }

    private func miniTile(_ text: String, bg: Color, fg: Color, r: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(bg)
            .frame(width: 13, height: 13)
            .overlay(
                Text(text)
                    .font(.system(size: text.count > 2 ? 4.5 : 5.5, weight: .black, design: .rounded))
                    .foregroundColor(fg)
            )
    }

}

/// 三角形 Shape（用于小票锯齿边缘）
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
