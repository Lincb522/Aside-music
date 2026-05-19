import SwiftUI

/// 播放器主题选择面板 — 毛玻璃背景 + 精致卡片预览
struct PlayerThemePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.monologueSheetContext) private var monologueSheetContext
    @ObservedObject private var settings = SettingsManager.shared
    @State private var themeManager = PlayerThemeManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

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
        PlayerThemeStaticPreview(theme: theme)
    }
}

private struct PlayerThemeStaticPreview: View {
    let theme: PlayerTheme
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var ink: Color { isDark ? Color.white.opacity(0.92) : Color(hex: "141414") }
    private var muted: Color { isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.36) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                previewBackground
                previewContent(size: size)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private var previewBackground: some View {
        switch theme {
        case .classic:
            if PetWhiteStyle.isActive {
                pawcelainPreviewBackground
            } else if NeumorphicStyle.isActive {
                LinearGradient(
                    colors: isDark ? [Color(hex: "252A30"), Color(hex: "1A1F24")] : [Color(hex: "EEF2F4"), Color(hex: "DDE5E9")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(colors: isDark ? [Color(hex: "1B1D24"), Color(hex: "101218")] : [Color(hex: "F7F7F4"), Color(hex: "E9ECEF")], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        case .vinyl:
            LinearGradient(colors: isDark ? [Color(hex: "15120F"), Color(hex: "2B241B")] : [Color(hex: "F4F1EA"), Color(hex: "D8D0C2")], startPoint: .top, endPoint: .bottom)
        case .lyricFocus:
            LinearGradient(colors: isDark ? [Color(hex: "171B2B"), Color(hex: "07090F")] : [Color(hex: "F7F9FF"), Color(hex: "E9EEFB")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .card:
            LinearGradient(colors: isDark ? [Color(hex: "211429"), Color(hex: "3C2147")] : [Color(hex: "FFE5EF"), Color(hex: "DAD8FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .neumorphic:
            LinearGradient(colors: isDark ? [Color(hex: "2B2D32"), Color(hex: "1C1E22")] : [Color(hex: "EEF0F4"), Color(hex: "DDE2EA")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .poster:
            isDark ? Color.black : Color.white
        case .motoPager:
            LinearGradient(colors: isDark ? [Color(hex: "15160F"), Color(hex: "252714")] : [Color(hex: "E8E3C5"), Color(hex: "BDBA91")], startPoint: .top, endPoint: .bottom)
        case .typewriter:
            LinearGradient(colors: isDark ? [Color(hex: "221811"), Color(hex: "3A2B1F")] : [Color(hex: "B58A60"), Color(hex: "755436")], startPoint: .top, endPoint: .bottom)
        case .pixel:
            isDark ? Color(hex: "07101B") : Color(hex: "DDE7D5")
        case .aqua:
            LinearGradient(colors: isDark ? [Color(hex: "071A2C"), Color(hex: "0D4A69")] : [Color(hex: "F4FCFF"), Color(hex: "87C9E8")], startPoint: .top, endPoint: .bottom)
        case .breathing:
            RadialGradient(colors: isDark ? [Color(hex: "182A36"), Color(hex: "05070B")] : [Color(hex: "ECFAFF"), Color(hex: "F4F0FF")], center: .center, startRadius: 4, endRadius: 95)
        case .cassette:
            isDark ? Color(hex: "19191D") : Color(hex: "E7E5DD")
        case .radio:
            LinearGradient(colors: isDark ? [Color(hex: "180F32"), Color(hex: "382061")] : [Color(hex: "BCA6E7"), Color(hex: "8869BE")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .immersiveLyric:
            LinearGradient(colors: isDark ? [Color(hex: "191526"), Color(hex: "0B0A11")] : [Color(hex: "FAF7FF"), Color(hex: "ECE9FA")], startPoint: .top, endPoint: .bottom)
        case .mangaChat:
            LinearGradient(colors: isDark ? [Color(hex: "2A2631"), Color(hex: "17151D")] : [Color(hex: "FFF3D8"), Color(hex: "FFE3EE")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .folk:
            LinearGradient(colors: isDark ? [Color(hex: "2C2118"), Color(hex: "15100C")] : [Color(hex: "F5E9D8"), Color(hex: "E4D1B8")], startPoint: .top, endPoint: .bottom)
        case .game2048:
            Color(hex: "BBADA0")
        }
    }

    @ViewBuilder
    private func previewContent(size: CGSize) -> some View {
        switch theme {
        case .classic:
            if PetWhiteStyle.isActive {
                pawcelainPreview(size: size)
            } else {
                classicPreview(size: size)
            }
        case .vinyl: vinylPreview(size: size)
        case .lyricFocus: lyricFocusPreview(size: size)
        case .card: cardPreview(size: size)
        case .neumorphic: neumorphicPreview(size: size)
        case .poster: posterPreview(size: size)
        case .motoPager: motoPagerPreview(size: size)
        case .typewriter: typewriterPreview(size: size)
        case .pixel: pixelPreview(size: size)
        case .aqua: aquaPreview(size: size)
        case .breathing: breathingPreview(size: size)
        case .cassette: cassettePreview(size: size)
        case .radio: radioPreview(size: size)
        case .immersiveLyric: immersiveLyricPreview(size: size)
        case .mangaChat: mangaChatPreview(size: size)
        case .folk: folkPreview(size: size)
        case .game2048: game2048Preview(size: size)
        }
    }

    @ViewBuilder
    private var pawcelainPreviewBackground: some View {
        ZStack {
            PetWhiteRootBackdrop()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.58),
                    PetWhiteStyle.mint.opacity(isDark ? 0.12 : 0.18),
                    PetWhiteStyle.butter.opacity(isDark ? 0.08 : 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func classicPreview(size: CGSize) -> some View {
        if NeumorphicStyle.isActive {
            neumorphicClassicPreview(size: size)
        } else {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: isDark ? [Color(hex: "444854"), Color(hex: "262A34")] : [Color.white, Color(hex: "DADDE4")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                    .overlay(MonologueIcon(icon: .musicNote, size: 19, color: muted))

                lineStack(widths: [70, 48], color: ink, mutedColor: muted)
                progressBar(width: 80, progress: 0.58, tint: ink, track: muted.opacity(0.22))
                controlsRow(tint: ink, muted: muted)
            }
        }
    }

    private func pawcelainPreview(size: CGSize) -> some View {
        ZStack {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    PetWhiteIconBadge(icon: .musicNoteList, tint: PetWhiteStyle.butter, size: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(PetWhiteStyle.ink)
                            .frame(width: max(34, size.width * 0.28), height: 8)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(PetWhiteStyle.inkSoft.opacity(0.6))
                            .frame(width: max(24, size.width * 0.2), height: 7)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)

                HStack(spacing: 8) {
                    PetWhiteMascotMark(kind: .cat, size: 34)
                        .frame(width: 40, height: 40)
                        .background(PetWhiteStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    PetWhiteMascotMark(kind: .dog, size: 34)
                        .frame(width: 40, height: 40)
                        .background(PetWhiteStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PetWhiteStyle.surfaceRaised)
                        .frame(width: 52, height: 12)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PetWhiteStyle.mint)
                        .frame(width: 26, height: 26)
                        .overlay(PetWhitePackIcon(icon: .play, size: 12, visualScale: 1.06))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(isDark ? 0.07 : 0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(PetWhiteStyle.stroke.opacity(0.8), lineWidth: 1.2)
                    )
            )
            .padding(10)
        }
    }

    private func neumorphicClassicPreview(size: CGSize) -> some View {
        let base = isDark ? Color(hex: "252A30") : Color(hex: "EEF2F4")
        let raised = isDark ? Color(hex: "2D333A") : Color(hex: "F8FAFA")
        let pressed = isDark ? Color(hex: "1B1F24") : Color(hex: "DDE3E7")
        let accent = isDark ? Color(hex: "7AB9B0") : Color(hex: "4F8E86")

        return VStack(spacing: 8) {
            HStack(spacing: 5) {
                Capsule().fill(pressed).frame(width: 34, height: 12)
                Spacer(minLength: 0)
                Capsule().fill(accent.opacity(0.9)).frame(width: 18, height: 5)
                Capsule().fill(Color(hex: "7D9475").opacity(0.55)).frame(width: 11, height: 5)
                Capsule().fill(Color(hex: "C59A66").opacity(0.52)).frame(width: 7, height: 5)
            }

            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(raised)
                    .frame(width: 50, height: 50)
                    .shadow(color: isDark ? Color.black.opacity(0.28) : Color.black.opacity(0.1), radius: 4, x: 3, y: 3)
                    .shadow(color: isDark ? Color.white.opacity(0.035) : Color.white.opacity(0.82), radius: 4, x: -3, y: -3)
                    .overlay(MonologueIcon(icon: .musicNote, size: 15, color: accent.opacity(0.86), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 7) {
                    lineStack(widths: [54, 38], color: ink, mutedColor: muted)

                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            Capsule()
                                .fill(index.isMultiple(of: 2) ? accent.opacity(0.76) : Color(hex: "7D9475").opacity(0.48))
                                .frame(width: 4, height: CGFloat(7 + (index % 3) * 3))
                        }
                        Capsule().fill(pressed).frame(width: 34, height: 5)
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pressed))
                }
            }

            progressBar(width: 84, progress: 0.56, tint: accent, track: pressed)

            HStack(spacing: 8) {
                neumorphicButton(base: raised, icon: .previous, size: 22)
                neumorphicButton(base: accent.opacity(0.24), icon: .play, size: 30)
                neumorphicButton(base: raised, icon: .next, size: 22)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(base.opacity(0.86))
                .shadow(color: isDark ? Color.black.opacity(0.28) : Color.black.opacity(0.1), radius: 7, x: 4, y: 4)
                .shadow(color: isDark ? Color.white.opacity(0.035) : Color.white.opacity(0.82), radius: 7, x: -4, y: -4)
        )
    }

    private func vinylPreview(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.42))
                .frame(width: 110, height: 92)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(muted.opacity(0.18), lineWidth: 1))

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "0B0B0C"), Color(hex: "242424"), Color(hex: "060606")], center: .center, startRadius: 5, endRadius: 38))
                    .frame(width: 74, height: 74)
                ForEach([28, 44, 60], id: \.self) { diameter in
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.7).frame(width: CGFloat(diameter), height: CGFloat(diameter))
                }
                Circle().fill(Color(hex: "D7B56D")).frame(width: 22, height: 22)
                Circle().fill(Color.black.opacity(0.75)).frame(width: 5, height: 5)
            }
            .offset(x: -12, y: 2)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.78), Color.gray.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: 48)
                .rotationEffect(.degrees(-18), anchor: .top)
                .offset(x: 36, y: -24)
        }
    }

    private func lyricFocusPreview(size: CGSize) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "7696FF"), Color(hex: "F29BC4")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 48)
                .overlay(MonologueIcon(icon: .musicNote, size: 15, color: .white.opacity(0.88)))

            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(muted.opacity(0.3)).frame(width: 54, height: 4)
                Capsule().fill(ink).frame(width: 76, height: 7)
                Capsule().fill(ink.opacity(0.72)).frame(width: 60, height: 5)
                Capsule().fill(muted.opacity(0.32)).frame(width: 82, height: 4)
            }
        }
        .padding(14)
    }

    private func cardPreview(size: CGSize) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(isDark ? 0.08 : 0.32)).frame(width: 84, height: 84).offset(x: -42, y: -28)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.82))
                .frame(width: 104, height: 90)
                .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.12), radius: 12, x: 0, y: 8)

            VStack(spacing: 8) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "FF7CA8"), Color(hex: "8B78FF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                lineStack(widths: [58, 38], color: ink, mutedColor: muted)
                progressBar(width: 72, progress: 0.44, tint: Color(hex: "FF7CA8"), track: muted.opacity(0.22))
            }
        }
    }

    private func neumorphicPreview(size: CGSize) -> some View {
        let base = isDark ? Color(hex: "2B2D32") : Color(hex: "E7EBF2")
        return VStack(spacing: 10) {
            Circle()
                .fill(base)
                .frame(width: 54, height: 54)
                .shadow(color: isDark ? Color.black.opacity(0.4) : Color.black.opacity(0.13), radius: 7, x: 5, y: 5)
                .shadow(color: isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.86), radius: 7, x: -5, y: -5)
                .overlay(Circle().fill(LinearGradient(colors: [Color(hex: "8EA1B7").opacity(0.35), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 38, height: 38))

            progressBar(width: 76, progress: 0.62, tint: Color(hex: "6E8DA8"), track: isDark ? Color.black.opacity(0.22) : Color.white.opacity(0.64))
            HStack(spacing: 12) {
                neumorphicButton(base: base, icon: .previous, size: 18)
                neumorphicButton(base: base, icon: .play, size: 25)
                neumorphicButton(base: base, icon: .next, size: 18)
            }
        }
    }

    private func posterPreview(size: CGSize) -> some View {
        let red = Color(hex: "EF2A2A")
        return VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)
            Text("PLAY")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(ink)
            Text("LIST")
                .font(.system(size: 35, weight: .black, design: .rounded))
                .foregroundStyle(ink)
                .offset(y: -5)
            Rectangle().fill(red).frame(height: 4)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(index == 1 ? red : ink.opacity(0.12))
                        .frame(height: 16)
                        .overlay(Rectangle().stroke(ink, lineWidth: 0.8))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func motoPagerPreview(size: CGSize) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isDark ? Color(hex: "303323") : Color(hex: "D5D0A8"))
                .frame(width: 106, height: 78)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isDark ? Color(hex: "A8B47B").opacity(0.38) : Color(hex: "5F6D3A").opacity(0.28))
                        .frame(width: 86, height: 34)
                        .padding(.top, 10)
                        .overlay(alignment: .center) {
                            VStack(spacing: 4) {
                                Capsule().fill(ink.opacity(0.65)).frame(width: 56, height: 3)
                                Capsule().fill(ink.opacity(0.38)).frame(width: 42, height: 2)
                            }
                            .padding(.top, 4)
                        }
                }
                .overlay(alignment: .bottom) {
                    HStack(spacing: 8) {
                        Circle().fill(ink.opacity(0.18)).frame(width: 12, height: 12)
                        Circle().fill(ink.opacity(0.28)).frame(width: 16, height: 16)
                        Circle().fill(ink.opacity(0.18)).frame(width: 12, height: 12)
                    }
                    .padding(.bottom, 9)
                }
        }
    }

    private func typewriterPreview(size: CGSize) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isDark ? Color(hex: "E5D2B3") : Color(hex: "FFF7E9"))
                .frame(width: 88, height: 60)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 5) {
                        Capsule().fill(Color(hex: "A54A32")).frame(width: 28, height: 3)
                        Capsule().fill(Color(hex: "2D241C")).frame(width: 48, height: 4)
                        Capsule().fill(Color(hex: "2D241C").opacity(0.22)).frame(width: 62, height: 2)
                        Capsule().fill(Color(hex: "2D241C").opacity(0.18)).frame(width: 52, height: 2)
                    }
                    .padding(10)
                }
                .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 4)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDark ? Color(hex: "44372F") : Color(hex: "5B493D"))
                .frame(width: 104, height: 32)
                .overlay {
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            ForEach(0..<5, id: \.self) { _ in keyCap() }
                        }
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(hex: "E9DCC8")).frame(width: 44, height: 8)
                    }
                }
                .offset(y: -6)
        }
    }

    private func pixelPreview(size: CGSize) -> some View {
        let green = Color(hex: "30FF6A")
        return ZStack {
            pixelGrid(color: isDark ? green.opacity(0.09) : Color.black.opacity(0.05), step: 8)
            VStack(spacing: 8) {
                Text("PIXEL")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(green)
                    .shadow(color: green.opacity(0.35), radius: 4)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach([8, 17, 11, 23, 15, 20, 9, 14], id: \.self) { height in
                        Rectangle().fill(green.opacity(height > 12 ? 0.9 : 0.42)).frame(width: 5, height: CGFloat(height))
                    }
                }
                HStack(spacing: 9) {
                    pixelButton(icon: .previous, color: green)
                    Rectangle().fill(green).frame(width: 14, height: 14)
                    pixelButton(icon: .next, color: green)
                }
            }
        }
    }

    private func aquaPreview(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(isDark ? 0.12 : 0.32), lineWidth: 1)
                    .frame(width: CGFloat(42 + index * 30), height: CGFloat(42 + index * 30))
                    .offset(y: 4)
            }

            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(isDark ? 0.4 : 0.72), Color(hex: "4BB6E0").opacity(0.16), .clear], center: .center, startRadius: 2, endRadius: 36))
                .frame(width: 70, height: 70)

            VStack {
                Spacer()
                HStack(spacing: 12) {
                    bubble(size: 15)
                    bubble(size: 25, icon: .play)
                    bubble(size: 15)
                }
                .padding(.bottom, 15)
            }
        }
    }

    private func breathingPreview(size: CGSize) -> some View {
        let cyan = Color(hex: "58D7FF")
        let violet = Color(hex: "8F7BFF")
        return ZStack {
            Circle().fill(violet.opacity(0.2)).frame(width: 102, height: 102).blur(radius: 18)
            Circle().stroke(cyan.opacity(0.34), lineWidth: 1.2).frame(width: 82, height: 82)
            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .fill(index < 11 ? cyan.opacity(0.82) : violet.opacity(0.32))
                    .frame(width: index < 11 ? 5 : 3, height: index < 11 ? 5 : 3)
                    .offset(breathingDotOffset(index: index))
            }
            Circle()
                .fill(LinearGradient(colors: [violet, cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay(MonologueIcon(icon: .waveform, size: 18, color: .white.opacity(0.9)))
        }
    }

    private func cassettePreview(size: CGSize) -> some View {
        let shell = isDark ? Color(hex: "2B2B31") : Color.white
        let label = isDark ? Color(hex: "E5E0D2") : Color(hex: "F6F1E6")

        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(shell)
            .frame(width: 106, height: 74)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(label)
                    .frame(width: 82, height: 38)
                    .padding(.top, 13)
                    .overlay(alignment: .top) {
                        VStack(spacing: 2) {
                            Rectangle().fill(Color(hex: "E85D45")).frame(width: 66, height: 4)
                            Rectangle().fill(Color(hex: "F0B64E")).frame(width: 66, height: 4)
                        }
                        .padding(.top, 18)
                    }
                    .overlay {
                        HStack(spacing: 24) {
                            tapeReel()
                            tapeReel()
                        }
                        .padding(.top, 13)
                    }
            }
            .overlay(alignment: .bottom) {
                TrapezoidShape()
                    .fill(Color.black.opacity(isDark ? 0.24 : 0.08))
                    .frame(width: 56, height: 12)
                    .padding(.bottom, 7)
            }
    }

    private func radioPreview(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isDark ? Color(hex: "312058") : Color(hex: "9272C8"))
            .frame(width: 112, height: 86)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isDark ? Color(hex: "090711") : Color(hex: "1D1331"))
                    .frame(width: 92, height: 22)
                    .padding(.top, 10)
                    .overlay {
                        HStack(spacing: 3) {
                            ForEach(0..<12, id: \.self) { index in
                                Circle()
                                    .fill(index < 7 ? Color(hex: "DCC8FF") : Color(hex: "DCC8FF").opacity(0.22))
                                    .frame(width: 3, height: 3)
                            }
                        }
                        .padding(.top, 10)
                    }
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 9) {
                    speaker()
                    VStack(alignment: .leading, spacing: 6) {
                        lineStack(widths: [34, 25], color: Color.white.opacity(0.86), mutedColor: Color.white.opacity(0.42))
                        progressBar(width: 42, progress: 0.56, tint: Color(hex: "78E6A5"), track: Color.black.opacity(0.25))
                    }
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.14)))
                }
                .padding(.bottom, 9)
            }
    }

    private func immersiveLyricPreview(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "B495FF"), Color(hex: "F1A6C7")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 30, height: 30)
                lineStack(widths: [54, 34], color: ink, mutedColor: muted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 7) {
                Capsule().fill(muted.opacity(0.28)).frame(width: 78, height: 5)
                Capsule().fill(ink).frame(width: 96, height: 11)
                Capsule().fill(ink.opacity(0.66)).frame(width: 70, height: 7)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func mangaChatPreview(size: CGSize) -> some View {
        ZStack {
            mangaDotTexture()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    mangaMark(fill: Color(hex: "FFE16B"))
                    Spacer()
                    mangaMark(fill: Color(hex: "FF8BAD"))
                }
                speechBubble(width: 78, fill: Color.white, tailLeading: true)
                speechBubble(width: 66, fill: Color(hex: "BFE3FF"), tailLeading: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                HStack(spacing: 7) {
                    Circle().fill(Color(hex: "FF8BAD")).frame(width: 15, height: 15)
                    Circle().fill(Color(hex: "FFE16B")).frame(width: 22, height: 22)
                    Circle().fill(Color(hex: "BFE3FF")).frame(width: 15, height: 15)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(13)
        }
    }

    private func folkPreview(size: CGSize) -> some View {
        VStack(spacing: 9) {
            HStack {
                Spacer()
                stamp()
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(isDark ? 0.24 : 0.86))
                    .frame(width: 30, height: 36)
                    .rotationEffect(.degrees(-5))
                    .overlay(Rectangle().fill(Color(hex: "D8C29D")).frame(width: 18, height: 5).rotationEffect(.degrees(-9)).offset(y: -15))

                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(Color(hex: "B44A3B")).frame(width: 22, height: 2)
                    Capsule().fill(ink.opacity(0.78)).frame(width: 52, height: 4)
                    Capsule().fill(muted.opacity(0.52)).frame(width: 38, height: 3)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(ink.opacity(0.78)).frame(width: 82, height: 3)
                Capsule().fill(ink.opacity(0.35)).frame(width: 58, height: 2)
            }
            progressBar(width: 82, progress: 0.43, tint: Color(hex: "B44A3B"), track: muted.opacity(0.22))
        }
        .padding(13)
    }

    private func game2048Preview(size: CGSize) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                gameTile("2", color: Color(hex: "EEE4DA"), textColor: Color(hex: "776E65"))
                gameTile("4", color: Color(hex: "EDE0C8"), textColor: Color(hex: "776E65"))
                gameTile("8", color: Color(hex: "F2B179"), textColor: .white)
                gameTile("16", color: Color(hex: "F59563"), textColor: .white)
            }
            HStack(spacing: 4) {
                gameTile("32", color: Color(hex: "F67C5F"), textColor: .white)
                gameTile("64", color: Color(hex: "F65E3B"), textColor: .white)
                gameTile("128", color: Color(hex: "EDCF72"), textColor: .white)
                gameTile("", color: Color(hex: "CDC1B4"), textColor: .white)
            }
            HStack(spacing: 4) {
                gameTile("PLAY", color: Color(hex: "EDC22E"), textColor: .white, wide: true)
                gameTile("", color: Color(hex: "CDC1B4"), textColor: .white)
                gameTile("", color: Color(hex: "CDC1B4"), textColor: .white)
            }
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: "A99B8E")))
    }

    private func lineStack(widths: [CGFloat], color: Color, mutedColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                Capsule()
                    .fill(index == 0 ? color.opacity(0.82) : mutedColor.opacity(0.6))
                    .frame(width: width, height: index == 0 ? 4 : 3)
            }
        }
    }

    private func progressBar(width: CGFloat, progress: CGFloat, tint: Color, track: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(track).frame(width: width, height: 4)
            Capsule().fill(tint).frame(width: width * progress, height: 4)
            Circle().fill(tint).frame(width: 8, height: 8).offset(x: width * progress - 4)
        }
        .frame(width: width, height: 8)
    }

    private func controlsRow(tint: Color, muted: Color) -> some View {
        HStack(spacing: 13) {
            MonologueIcon(icon: .previous, size: 11, color: muted, lineWidth: 1.5)
            Circle()
                .fill(tint)
                .frame(width: 24, height: 24)
                .overlay(MonologueIcon(icon: .play, size: 10, color: isDark ? .black : .white, lineWidth: 1.7))
            MonologueIcon(icon: .next, size: 11, color: muted, lineWidth: 1.5)
        }
    }

    private func neumorphicButton(base: Color, icon: MonologueIcon.IconType, size: CGFloat) -> some View {
        Circle()
            .fill(base)
            .frame(width: size, height: size)
            .shadow(color: isDark ? Color.black.opacity(0.34) : Color.black.opacity(0.12), radius: 3, x: 2, y: 2)
            .shadow(color: isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.84), radius: 3, x: -2, y: -2)
            .overlay(MonologueIcon(icon: icon, size: size * 0.38, color: muted, lineWidth: 1.4))
    }

    private func keyCap() -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color(hex: "E9DCC8"))
            .frame(width: 12, height: 8)
    }

    private func pixelGrid(color: Color, step: CGFloat) -> some View {
        Canvas { ctx, size in
            for x in stride(from: 0, through: size.width, by: step) {
                ctx.stroke(Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }, with: .color(color), lineWidth: 0.6)
            }
            for y in stride(from: 0, through: size.height, by: step) {
                ctx.stroke(Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }, with: .color(color), lineWidth: 0.6)
            }
        }
    }

    private func pixelButton(icon: MonologueIcon.IconType, color: Color) -> some View {
        ZStack {
            Rectangle().fill(color.opacity(0.18)).frame(width: 18, height: 18)
            MonologueIcon(icon: icon, size: 9, color: color, lineWidth: 1.4)
        }
    }

    private func bubble(size: CGFloat, icon: MonologueIcon.IconType? = nil) -> some View {
        Circle()
            .fill(Color.white.opacity(isDark ? 0.14 : 0.72))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.white.opacity(isDark ? 0.16 : 0.52), lineWidth: 0.8))
            .overlay {
                if let icon {
                    MonologueIcon(icon: icon, size: size * 0.38, color: isDark ? Color.white.opacity(0.72) : Color(hex: "2E86C1"), lineWidth: 1.5)
                }
            }
    }

    private func breathingDotOffset(index: Int) -> CGSize {
        let fraction = Double(index) / 18.0
        let angle = fraction * .pi * 2
        return CGSize(width: cos(angle) * 36, height: sin(angle) * 29)
    }

    private func tapeReel() -> some View {
        Circle()
            .fill(Color.black.opacity(0.14))
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(Color.black.opacity(0.16), lineWidth: 1))
            .overlay(Circle().fill(Color.black.opacity(0.35)).frame(width: 5, height: 5))
    }

    private func speaker() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .frame(width: 42, height: 42)
            ForEach([18, 28, 38], id: \.self) { diameter in
                Circle().stroke(Color.white.opacity(0.09), lineWidth: 1).frame(width: CGFloat(diameter), height: CGFloat(diameter))
            }
        }
    }

    private func mangaDotTexture() -> some View {
        Canvas { ctx, size in
            let color = Color.black.opacity(isDark ? 0.1 : 0.08)
            for x in stride(from: 4, through: size.width, by: 12) {
                for y in stride(from: 4, through: size.height, by: 12) {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.2, height: 2.2)), with: .color(color))
                }
            }
        }
    }

    private func mangaMark(fill: Color) -> some View {
        HeartShape()
            .fill(fill)
            .frame(width: 16, height: 14)
            .overlay(HeartShape().stroke(Color.black.opacity(isDark ? 0.55 : 0.85), lineWidth: 1.2))
    }

    private func speechBubble(width: CGFloat, fill: Color, tailLeading: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fill.opacity(isDark ? 0.18 : 0.92))
            .frame(width: width, height: 24)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(isDark ? 0.48 : 0.82), lineWidth: 1.2))
            .overlay(alignment: tailLeading ? .bottomLeading : .bottomTrailing) {
                Triangle()
                    .fill(fill.opacity(isDark ? 0.18 : 0.92))
                    .frame(width: 9, height: 7)
                    .rotationEffect(.degrees(tailLeading ? -90 : 90))
                    .offset(x: tailLeading ? 7 : -7, y: 4)
            }
            .overlay(lineStack(widths: [width * 0.48, width * 0.32], color: ink, mutedColor: muted))
    }

    private func stamp() -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Color(hex: "B44A3B").opacity(0.62), lineWidth: 1)
            .frame(width: 34, height: 18)
            .overlay(Capsule().fill(Color(hex: "B44A3B").opacity(0.7)).frame(width: 22, height: 2))
            .rotationEffect(.degrees(-5))
    }

    private func gameTile(_ text: String, color: Color, textColor: Color, wide: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(color)
            .frame(width: wide ? 54 : 25, height: 25)
            .overlay(
                Text(text)
                    .font(.system(size: text.count > 2 ? 6 : 9, weight: .black, design: .rounded))
                    .foregroundStyle(textColor)
            )
    }
}

private struct TrapezoidShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.33),
            control1: CGPoint(x: rect.midX - w * 0.42, y: rect.maxY - h * 0.18),
            control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + h * 0.22),
            control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.02),
            control2: CGPoint(x: rect.midX - w * 0.28, y: rect.minY - h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.33),
            control1: CGPoint(x: rect.midX + w * 0.28, y: rect.minY - h * 0.02),
            control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.62),
            control2: CGPoint(x: rect.midX + w * 0.42, y: rect.maxY - h * 0.18)
        )
        return path
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
