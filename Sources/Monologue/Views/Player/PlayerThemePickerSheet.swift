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
                .font(.rounded(size: 20, weight: .bold))
                .foregroundColor(.monologueTextPrimary)
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected
                                    ? Color.monologueAccent
                                    : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.monologueSeparator),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                    .shadow(
                        color: isSelected
                            ? Color.monologueAccent.opacity(colorScheme == .dark ? 0.3 : 0.15)
                            : Color.clear,
                        radius: 8, x: 0, y: 4
                    )

                // 标签
                HStack(spacing: 6) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.monologueAccent)
                    }

                    Text(theme.displayName)
                        .font(.rounded(size: 14, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .monologueTextPrimary : .monologueTextSecondary)
                }
            }
            .contentShape(Rectangle())
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
                        MonologueIcon(icon: .musicNote, size: 18, color: colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.15))
                    )

                // 控制条示意
                HStack(spacing: 8) {
                    Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 8, height: 8)
                    Capsule().fill(Color.monologueTextSecondary.opacity(0.2)).frame(width: 40, height: 4)
                    Circle()
                        .fill(colorScheme == .dark ? Color.white : Color.black)
                        .frame(width: 16, height: 16)
                    Capsule().fill(Color.monologueTextSecondary.opacity(0.2)).frame(width: 40, height: 4)
                    Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 8, height: 8)
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
                    .fill(Color.monologueTextSecondary.opacity(0.12))
                    .frame(width: 55, height: 3)
                Capsule()
                    .fill(Color.monologueTextPrimary.opacity(0.8))
                    .frame(width: 85, height: 5)
                Capsule()
                    .fill(Color.monologueTextSecondary.opacity(0.12))
                    .frame(width: 45, height: 3)
                Capsule()
                    .fill(Color.monologueTextSecondary.opacity(0.06))
                    .frame(width: 65, height: 3)

                Spacer().frame(height: 8)

                // 进度线
                Rectangle()
                    .fill(Color.monologueTextPrimary.opacity(0.35))
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
                        MonologueIcon(icon: .play, size: 10, color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
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

    // MARK: - 打字机预览
    private var typewriterPreview: some View {
        let deskTop = colorScheme == .dark ? Color(hex: "2B1F18") : Color(hex: "9A7653")
        let deskBottom = colorScheme == .dark ? Color(hex: "1B1410") : Color(hex: "6E533B")
        let paperColor = colorScheme == .dark ? Color(hex: "E7D8BE") : Color(hex: "FFF8EB")
        let inkColor = colorScheme == .dark ? Color(hex: "2A211A") : Color(hex: "3B2D23")
        let machineColor = colorScheme == .dark ? Color(hex: "3A302A") : Color(hex: "5B493D")
        let keyColor = colorScheme == .dark ? Color(hex: "56473E") : Color(hex: "F0E4D4")

        return ZStack {
            LinearGradient(
                colors: [deskTop, deskBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Capsule()
                    .fill(machineColor.opacity(0.9))
                    .frame(width: 76, height: 10)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
                    )

                RoundedRectangle(cornerRadius: 10)
                    .fill(paperColor)
                    .frame(width: 86, height: 64)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 5) {
                            Capsule()
                                .fill(inkColor.opacity(0.55))
                                .frame(width: 34, height: 3)
                            Capsule()
                                .fill(inkColor.opacity(0.8))
                                .frame(width: 48, height: 4)
                            Capsule()
                                .fill(Color(hex: "B14A31").opacity(0.5))
                                .frame(height: 1.5)
                                .padding(.top, 3)
                            Capsule()
                                .fill(inkColor.opacity(0.22))
                                .frame(width: 58, height: 2)
                            Capsule()
                                .fill(inkColor.opacity(0.16))
                                .frame(width: 50, height: 2)
                        }
                        .padding(.top, 10)
                        .padding(.leading, 10)
                    }
                    .overlay(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "D9C4A0"), Color(hex: "B9925D")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 18, height: 18)
                            .padding(9)
                    }

                RoundedRectangle(cornerRadius: 12)
                    .fill(machineColor)
                    .frame(width: 98, height: 32)
                    .overlay(
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                ForEach(0..<5, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(keyColor)
                                        .frame(width: 12, height: 8)
                                }
                            }
                            RoundedRectangle(cornerRadius: 5)
                                .fill(keyColor)
                                .frame(width: 46, height: 9)
                        }
                        .padding(.top, 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .offset(y: -6)
            }
        }
    }
    
    // MARK: - 像素预览
    private var pixelPreview: some View {
        let isDark = colorScheme == .dark
        let bgColor = isDark ? Color(hex: "0a0a1a") : Color(hex: "e8eaf0")
        let pixelGreen = Color(hex: "00ff41")
        let gridColor = isDark ? pixelGreen.opacity(0.08) : Color.black.opacity(0.04)
        
        return ZStack {
            bgColor
            
            // 背景像素网格
            Canvas { ctx, size in
                let step: CGFloat = 8
                for row in 0...Int(size.height / step) {
                    for col in 0...Int(size.width / step) {
                        ctx.stroke(
                            Path(CGRect(x: CGFloat(col) * step, y: CGFloat(row) * step, width: step, height: step)),
                            with: .color(gridColor),
                            lineWidth: 0.5
                        )
                    }
                }
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // 扫描线效果标题
                HStack(spacing: 2) {
                    // "PIXEL" 像素字
                    ForEach(["P","I","X","E","L"], id: \.self) { ch in
                        Text(ch)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(pixelGreen)
                    }
                }
                .shadow(color: pixelGreen.opacity(0.6), radius: 4, x: 0, y: 0)
                
                Spacer().frame(height: 8)
                
                // 像素化波形
                HStack(spacing: 2) {
                    ForEach(0..<14, id: \.self) { i in
                        let heights: [CGFloat] = [4, 8, 12, 18, 14, 20, 10, 16, 22, 14, 8, 12, 6, 4]
                        Rectangle()
                            .fill(pixelGreen.opacity(i < 6 ? 0.9 : 0.3))
                            .frame(width: 4, height: heights[i])
                    }
                }
                
                Spacer().frame(height: 8)
                
                // 底部像素控制行
                HStack(spacing: 10) {
                    // 上一首
                    HStack(spacing: 0) {
                        Rectangle().fill(pixelGreen.opacity(0.5)).frame(width: 2, height: 8)
                        Path { p in
                            p.move(to: .init(x: 8, y: 0))
                            p.addLine(to: .init(x: 0, y: 4))
                            p.addLine(to: .init(x: 8, y: 8))
                            p.closeSubpath()
                        }
                        .fill(pixelGreen.opacity(0.5))
                        .frame(width: 8, height: 8)
                    }
                    
                    // 播放
                    Rectangle()
                        .fill(pixelGreen)
                        .frame(width: 12, height: 12)
                        .shadow(color: pixelGreen.opacity(0.5), radius: 3)
                    
                    // 下一首
                    HStack(spacing: 0) {
                        Path { p in
                            p.move(to: .init(x: 0, y: 0))
                            p.addLine(to: .init(x: 8, y: 4))
                            p.addLine(to: .init(x: 0, y: 8))
                            p.closeSubpath()
                        }
                        .fill(pixelGreen.opacity(0.5))
                        .frame(width: 8, height: 8)
                        Rectangle().fill(pixelGreen.opacity(0.5)).frame(width: 2, height: 8)
                    }
                }
                
                Spacer().frame(height: 10)
            }
            
            // CRT 扫描线叠加
            VStack(spacing: 2) {
                ForEach(0..<65, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(isDark ? 0.15 : 0.03))
                        .frame(height: 1)
                    Spacer().frame(height: 1)
                }
            }
            .allowsHitTesting(false)
        }
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
        let isDark = colorScheme == .dark
        let bgTop = isDark ? Color(hex: "1E1040") : Color(hex: "B8A0E0")
        let bgBot = isDark ? Color(hex: "100828") : Color(hex: "9070C0")
        let card = isDark ? Color(hex: "2E2058") : Color(hex: "8B6FC0")
        let ledBg = isDark ? Color(hex: "08060E") : Color(hex: "18102C")
        let ledOn = isDark ? Color(hex: "D0C0F0") : Color(hex: "F0E8FF")
        let ledOff = isDark ? Color(hex: "1E1830") : Color(hex: "2A2040")
        let spkr = isDark ? Color(hex: "18142A") : Color(hex: "2C2444")
        let info = isDark ? Color(hex: "3A2868") : Color(hex: "A088D8")
        let tw = isDark ? Color(hex: "F0E8FF") : Color(hex: "1E1040")
        let td = isDark ? Color(hex: "9080B0") : Color(hex: "5A4880")
        let pBg = isDark ? Color(hex: "14102A") : Color(hex: "3A2858")
        let pDot = isDark ? Color(hex: "80E8A0") : Color(hex: "50D080")

        return ZStack {
            LinearGradient(colors: [bgTop, bgBot], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 0) {
                // LED
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(ledBg)
                    Canvas { ctx, size in
                        let d: CGFloat = 1.6; let g: CGFloat = 4.5
                        for r in stride(from: g, to: size.height, by: g) {
                            for c in stride(from: g, to: size.width, by: g) {
                                ctx.fill(Path(ellipseIn: CGRect(x: c - d/2, y: r - d/2, width: d, height: d)),
                                         with: .color(ledOff))
                            }
                        }
                    }
                    HStack(spacing: 1.5) {
                        ForEach(0..<10, id: \.self) { _ in
                            Circle().fill(ledOn.opacity(0.6)).frame(width: 2.5, height: 2.5)
                        }
                        Capsule().fill(ledOn.opacity(0.8)).frame(width: 18, height: 2.5)
                        ForEach(0..<6, id: \.self) { _ in
                            Circle().fill(ledOn.opacity(0.35)).frame(width: 2.5, height: 2.5)
                        }
                    }
                }
                .frame(height: 18)
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 4)

                HStack(spacing: 5) {
                    // Speaker
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(spkr).frame(width: 52, height: 52)
                        ForEach(0..<3, id: \.self) { i in
                            Circle().stroke(Color.white.opacity(0.06), lineWidth: 1)
                                .frame(width: CGFloat(18 + i * 8), height: CGFloat(18 + i * 8))
                        }
                        Circle().fill(Color.white.opacity(0.06)).frame(width: 8, height: 8)
                        // Mini chrome spheres
                        ZStack {
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.8), .gray], center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 4))
                                .frame(width: 7, height: 7)
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.75), .gray], center: .init(x: 0.35, y: 0.25), startRadius: 0, endRadius: 3))
                                .frame(width: 5, height: 5).offset(x: -5, y: -3)
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.7), .gray], center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 2))
                                .frame(width: 4, height: 4).offset(x: 3, y: -5)
                        }
                        .offset(x: 8, y: 10)
                    }

                    // Info card
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.15))
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 1) {
                                Capsule().fill(tw.opacity(0.8)).frame(width: 28, height: 3)
                                Capsule().fill(td.opacity(0.5)).frame(width: 20, height: 2)
                            }
                        }
                        // Thick progress
                        ZStack(alignment: .leading) {
                            Capsule().fill(pBg).frame(height: 8)
                            Circle().fill(pDot).frame(width: 5, height: 5).offset(x: 14)
                        }
                        HStack(spacing: 2) {
                            Text("3:42").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(tw)
                            Text("5:10").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundStyle(td)
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(info))
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card).padding(4))
        }
    }
    
    // MARK: - 沉浸歌词预览
    private var immersiveLyricPreview: some View {
        let isDark = colorScheme == .dark
        let bgColor = isDark ? Color(hex: "1F1A2A") : Color(hex: "F8F5FF")
        let contentClr = isDark ? Color.white : Color.black
        
        return ZStack {
            bgColor
            
            // 背景弥散
            Circle().fill(Color.purple.opacity(0.15)).frame(width: 80, height: 80).blur(radius: 20).offset(x: -30, y: 30)
            Circle().fill(Color.blue.opacity(0.15)).frame(width: 60, height: 60).blur(radius: 15).offset(x: 40, y: -20)
            
            VStack {
                // 顶部信息
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.3)).frame(width: 14, height: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Capsule().fill(contentClr.opacity(0.8)).frame(width: 25, height: 2.5)
                        Capsule().fill(contentClr.opacity(0.4)).frame(width: 15, height: 2)
                    }
                    Spacer()
                    Circle().fill(contentClr.opacity(0.6)).frame(width: 4, height: 4)
                }
                .padding(.top, 8)
                .padding(.horizontal, 10)
                
                Spacer()
                
                // 大字歌词
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(contentClr.opacity(0.15)).frame(width: 50, height: 4)
                    Capsule().fill(contentClr.opacity(0.9)).frame(width: 70, height: 5) // 高亮行
                    Capsule().fill(contentClr.opacity(0.15)).frame(width: 40, height: 4)
                }
                .padding(.leading, -20)
                
                Spacer()
                
                // 底部悬浮控制
                RoundedRectangle(cornerRadius: 4)
                    .fill(contentClr.opacity(0.08))
                    .frame(height: 16)
                    .overlay(
                        HStack(spacing: 8) {
                            Circle().fill(contentClr.opacity(0.5)).frame(width: 5, height: 5)
                            Circle().fill(contentClr.opacity(0.8)).frame(width: 8, height: 8)  // Play
                            Circle().fill(contentClr.opacity(0.5)).frame(width: 5, height: 5)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
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
