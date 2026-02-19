import SwiftUI

/// 播放器主题选择面板 — 毛玻璃背景 + 精致卡片预览
struct PlayerThemePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let themeManager = PlayerThemeManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // 拖拽指示器
            Capsule()
                .fill(Color.asideTextSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            // 标题
            Text("theme_title")
                .font(.rounded(size: 20, weight: .bold))
                .foregroundColor(.asideTextPrimary)
                .padding(.bottom, 4)

            // 主题卡片网格 - 使用 ScrollView 确保内容可滚动
            ScrollView(.vertical, showsIndicators: false) {
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
        }
        .background(sheetBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    /// 面板背景 — 使用通用弥散背景
    @ViewBuilder
    private var sheetBackground: some View {
        AsideBackground()
    }

    private func themeCard(_ theme: PlayerTheme) -> some View {
        let isSelected = themeManager.currentTheme == theme

        return Button {
            themeManager.setTheme(theme)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        } label: {
            VStack(spacing: 10) {
                // 预览区域
                themePreview(theme)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected
                                    ? Color.asideAccent
                                    : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.asideSeparator),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                    .shadow(
                        color: isSelected
                            ? Color.asideAccent.opacity(colorScheme == .dark ? 0.3 : 0.15)
                            : Color.clear,
                        radius: 8, x: 0, y: 4
                    )

                // 标签
                HStack(spacing: 6) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.asideAccent)
                    }

                    Text(theme.displayName)
                        .font(.rounded(size: 14, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .asideTextPrimary : .asideTextSecondary)
                }
            }
        }
        .buttonStyle(.plain)
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
        case .pixel:
            pixelPreview
        case .aqua:
            aquaPreview
        }
    }

    // MARK: - 经典预览
    private var classicPreview: some View {
        ZStack {
            // 背景
            if colorScheme == .dark {
                Color(hex: "1A1A1E")
            } else {
                Color(hex: "F0F0F2")
            }

            VStack(spacing: 8) {
                // 方形封面
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(hex: "3A3A3E"), Color(hex: "2A2A2E")]
                                : [Color(hex: "D8D8DC"), Color(hex: "C8C8CC")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        AsideIcon(icon: .musicNote, size: 18, color: colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.15))
                    )

                // 控制条示意
                HStack(spacing: 8) {
                    Circle().fill(Color.asideTextSecondary.opacity(0.3)).frame(width: 8, height: 8)
                    Capsule().fill(Color.asideTextSecondary.opacity(0.2)).frame(width: 40, height: 4)
                    Circle()
                        .fill(colorScheme == .dark ? Color.white : Color.black)
                        .frame(width: 16, height: 16)
                    Capsule().fill(Color.asideTextSecondary.opacity(0.2)).frame(width: 40, height: 4)
                    Circle().fill(Color.asideTextSecondary.opacity(0.3)).frame(width: 8, height: 8)
                }
            }
        }
    }

    // MARK: - 黑胶预览
    private var vinylPreview: some View {
        ZStack {
            Color(hex: "F5F5F5")

            ZStack {
                // 唱片
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "2A2A2A"), Color(hex: "1A1A1A"), Color(hex: "222222")],
                            center: .center,
                            startRadius: 8,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)
                // 沟槽
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: 50, height: 50)
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                    .frame(width: 36, height: 36)
                // 中心
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "555555"), Color(hex: "444444")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color(hex: "1A1A1A"))
                    .frame(width: 6, height: 6)
            }
            .offset(x: -5, y: -5)

            // 唱臂示意
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "E0E0E0"), Color(hex: "C0C0C0")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 3, height: 40)
                .rotationEffect(.degrees(-25), anchor: .top)
                .offset(x: 30, y: -30)
        }
    }

    // MARK: - 歌词预览
    private var lyricFocusPreview: some View {
        ZStack {
            if colorScheme == .dark {
                Color(hex: "1A1A1E")
            } else {
                Color(hex: "F0F0F2")
            }

            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(Color.asideTextSecondary.opacity(0.12))
                    .frame(width: 55, height: 3)
                Capsule()
                    .fill(Color.asideTextPrimary.opacity(0.8))
                    .frame(width: 85, height: 5)
                Capsule()
                    .fill(Color.asideTextSecondary.opacity(0.12))
                    .frame(width: 45, height: 3)
                Capsule()
                    .fill(Color.asideTextSecondary.opacity(0.06))
                    .frame(width: 65, height: 3)

                Spacer().frame(height: 8)

                // 进度线
                Rectangle()
                    .fill(Color.asideTextPrimary.opacity(0.35))
                    .frame(width: 65, height: 1.5)
            }
            .padding(.leading, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 卡片预览
    private var cardPreview: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [.pink.opacity(0.5), .purple.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 白色卡片
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.9))
                .padding(10)
                .overlay(
                    VStack(spacing: 6) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 3)
                        Capsule().fill(Color.gray.opacity(0.2)).frame(width: 30, height: 2)
                    }
                )
        }
    }

    // MARK: - 新拟物预览
    private var neumorphicPreview: some View {
        let bgColor = colorScheme == .dark ? Color(hex: "2D2D30") : Color(hex: "E8E8EC")
        
        return ZStack {
            bgColor
            
            VStack(spacing: 10) {
                // 凸起的圆形封面
                Circle()
                    .fill(bgColor)
                    .frame(width: 50, height: 50)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.15), radius: 6, x: 4, y: 4)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.05) : .white.opacity(0.7), radius: 6, x: -4, y: -4)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                    )
                
                // 凹陷的进度条
                RoundedRectangle(cornerRadius: 3)
                    .fill(bgColor)
                    .frame(width: 70, height: 6)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.15), radius: 2, x: 2, y: 2)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.05) : .white.opacity(0.7), radius: 2, x: -2, y: -2)
                    .overlay(
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                                .frame(width: 30, height: 4)
                            Spacer()
                        }
                        .padding(.horizontal, 1)
                    )
                
                // 凸起的播放按钮
                Circle()
                    .fill(bgColor)
                    .frame(width: 24, height: 24)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.15), radius: 3, x: 2, y: 2)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.05) : .white.opacity(0.7), radius: 3, x: -2, y: -2)
                    .overlay(
                        AsideIcon(icon: .play, size: 10, color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
                    )
            }
        }
    }
    
    // MARK: - 大字报预览
    private var posterPreview: some View {
        let bgClr: Color = colorScheme == .dark ? .black : .white
        let fgClr: Color = colorScheme == .dark ? .white : .black
        let redClr = Color(hex: "FF0000")
        
        return ZStack {
            bgClr
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                // 巨型文字
                Text("大")
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(fgClr)
                    .tracking(-2)
                
                Text("字报")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(fgClr)
                    .tracking(-1)
                
                // 红色粗线
                Rectangle()
                    .fill(redClr)
                    .frame(height: 3)
                    .padding(.vertical, 4)
                
                // 模拟控制格子
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        Rectangle()
                            .fill(bgClr)
                            .frame(height: 14)
                            .overlay(
                                Circle()
                                    .fill(i == 1 ? redClr : fgClr.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            )
                        if i < 3 {
                            Rectangle().fill(fgClr).frame(width: 1, height: 14)
                        }
                    }
                }
                .overlay(Rectangle().stroke(fgClr, lineWidth: 1))
                
                Spacer().frame(height: 6)
            }
            .padding(.horizontal, 10)
        }
    }
    
    // MARK: - 寻呼机预览
    private var motoPagerPreview: some View {
        let bgColor = colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F5F0E8")
        let textColor = colorScheme == .dark ? Color.white.opacity(0.8) : Color(hex: "333333")
        
        return ZStack {
            bgColor
            
            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                
                // 模拟小票打印文字
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(textColor.opacity(i == 1 ? 0.6 : 0.2))
                        .frame(width: CGFloat([55, 70, 40][i]), height: i == 1 ? 4 : 2.5)
                }
                
                Spacer().frame(height: 6)
                
                // 锯齿边缘
                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { _ in
                        Triangle()
                            .fill(textColor.opacity(0.15))
                            .frame(width: 6, height: 4)
                    }
                }
                
                Spacer().frame(height: 4)
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - 像素预览
    private var pixelPreview: some View {
        let bgColor = colorScheme == .dark ? Color(hex: "1a1a2e") : Color(hex: "e8eaf0")
        let pixelGreen = Color(hex: "00ff41")
        let pixelPurple = Color(hex: "bd00ff")
        
        return ZStack {
            bgColor
            
            VStack(spacing: 6) {
                // 像素化封面占位
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [pixelPurple.opacity(0.4), pixelGreen.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        // 像素网格
                        Canvas { ctx, size in
                            let step: CGFloat = 6
                            for row in 0..<Int(size.height / step) {
                                for col in 0..<Int(size.width / step) {
                                    let on = (row + col) % 3 != 0
                                    if on {
                                        ctx.fill(
                                            Path(CGRect(x: CGFloat(col) * step, y: CGFloat(row) * step, width: step - 1, height: step - 1)),
                                            with: .color(pixelGreen.opacity(0.3))
                                        )
                                    }
                                }
                            }
                        }
                    )
                
                // 像素进度条
                HStack(spacing: 1) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle()
                            .fill(i < 4 ? pixelGreen : pixelGreen.opacity(0.15))
                            .frame(width: 5, height: 4)
                    }
                }
                
                // 像素控制按钮
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle()
                            .fill(i == 1 ? pixelGreen : pixelGreen.opacity(0.4))
                            .frame(width: i == 1 ? 12 : 8, height: i == 1 ? 12 : 8)
                    }
                }
            }
        }
    }
    
    // MARK: - 水韵预览
    private var aquaPreview: some View {
        ZStack {
            aquaPreviewBackground
            aquaPreviewContent
        }
    }

    private var aquaPreviewBackground: some View {
        let isDark = colorScheme == .dark
        return LinearGradient(
            colors: isDark
                ? [Color(hex: "154360"), Color(hex: "1A5276"), Color(hex: "0B1A2B")]
                : [Color(hex: "3A8FB7"), Color(hex: "7EC8E3"), Color(hex: "B8E0F7")],
            startPoint: .bottom,
            endPoint: .top
        )
        .overlay(
            VStack(spacing: 0) {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(isDark ? 0.06 : 0.12))
                    .frame(height: 3)
                    .offset(y: -2)
                Capsule()
                    .fill(Color.white.opacity(isDark ? 0.03 : 0.07))
                    .frame(height: 2)
                    .offset(y: 2)
                Color.white.opacity(isDark ? 0.03 : 0.06)
                    .frame(height: 40)
            }
        )
    }

    private var aquaPreviewContent: some View {
        let bubbleGrad = LinearGradient(
            colors: [Color(hex: "7EC8E3").opacity(0.5), Color(hex: "3A8FB7").opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return VStack(spacing: 8) {
            Circle()
                .fill(bubbleGrad)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .overlay(AsideIcon(icon: .musicNote, size: 16, color: .white.opacity(0.6)))

            HStack(spacing: 6) {
                Circle().fill(Color.white.opacity(0.3)).frame(width: 7, height: 7)
                Circle().fill(Color.white.opacity(0.6)).frame(width: 14, height: 14)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 7, height: 7)
            }
        }
    }
    
}

/// 三角形 Shape（用于小票锯齿边缘）
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
