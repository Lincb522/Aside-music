import SwiftUI

/// 全局主题选择卡片 — 用于外观设置中展示主题预览
struct GlobalThemeOptionCard: View {
    let themeId: GlobalThemeId
    let isSelected: Bool

    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                previewArea
                    .frame(height: 116)
                    .compositingGroup()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected
                                    ? previewAccent.opacity(0.78)
                                    : Color.monologueSeparator.opacity(0.3),
                                lineWidth: isSelected ? 1.6 : 1
                            )
                    )

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(previewAccent)
                        MonologueIcon(
                            icon: .checkmark,
                            size: 11,
                            color: ThemeColorCustomization.readableForegroundColor(on: previewAccent, light: Color(hex: "111821"), dark: .white),
                            lineWidth: 2.2
                        )
                    }
                    .frame(width: 23, height: 23)
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.2))
                    .shadow(color: previewAccent.opacity(0.25), radius: 5, y: 2)
                    .padding(8)
                }
            }

            HStack(spacing: 7) {
                MonologueIcon(
                    icon: themeId.iconType,
                    size: 14,
                    color: isSelected ? previewAccent : .monologueTextSecondary,
                    lineWidth: 1.5
                )

                Text(themeId.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected
                    ? Color.monologueIconBackground.opacity(0.14)
                    : Color.monologueSeparator.opacity(0.38)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected ? Color.monologueAccent.opacity(0.4) : Color.clear,
                    lineWidth: 1.2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 预览区

    @ViewBuilder
    private var previewArea: some View {
        switch themeId {
        case .default:
            defaultPreview
        case .muji:
            mujiPreview
        case .manga:
            mangaPreview
        case .neumorphic:
            neumorphicPreview
        case .capsule:
            capsulePreview
        case .petWhite:
            petWhitePreview
        case .pureWhite:
            pureWhitePreview
        case .sequoia:
            sequoiaPreview
        case .liquidGlass:
            liquidGlassPreview
        case .bento, .clay, .signal, .material3Expressive:
            defaultPreview
        }
    }

    private var previewAccent: Color {
        switch themeId {
        case .default:   return defaultPreviewAccent
        case .muji:      return Color(hex: "C4775A")
        case .manga:     return Color(hex: "FF8FAB")
        case .neumorphic: return Color(hex: "4F8E86")
        case .capsule: return Color(hex: "3867FF")
        case .petWhite: return Color(hex: "F6A93B")
        case .pureWhite: return Color(hex: "2563EB")
        case .sequoia:   return Color(hex: "0A84FF")
        case .liquidGlass: return Color(hex: "18A7FF")
        case .bento, .clay, .signal, .material3Expressive: return .monologueAccent
        }
    }

    // MARK: - Default 预览

    private var defaultPreview: some View {
        let bg = colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7")
        return ZStack {
            bg
            
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [defaultPreviewAccent.opacity(0.12), defaultPreviewAccent.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(defaultPreviewAccent.opacity(0.15), lineWidth: 1)
                        .frame(width: 72, height: 72)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [defaultPreviewAccent.opacity(0.85), defaultPreviewAccent.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: defaultPreviewAccent.opacity(0.24), radius: 10, y: 5)
                    
                    Circle()
                        .fill(bg)
                        .frame(width: 10, height: 10)
                }
                
                Capsule()
                    .fill(defaultPreviewAccent.opacity(0.18))
                    .frame(width: 58, height: 4)
            }
        }
    }

    private var defaultPreviewAccent: Color {
        colorScheme == .dark ? Color.white : Color(hex: "111111")
    }

    // MARK: - Muji 预览

    private var mujiPreview: some View {
        ZStack {
            MujiStyle.paper
            MujiPaperTexture(opacity: 0.18)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Rectangle()
                        .fill(MujiStyle.hairline)
                        .frame(width: 32, height: 0.8)
                    Spacer()
                    Text("極簡")
                        .font(.system(size: 11, weight: .light, design: .serif))
                        .foregroundColor(MujiStyle.clay.opacity(0.88))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .border(MujiStyle.clay.opacity(0.4), width: 0.6)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle()
                        .fill(MujiStyle.ink.opacity(0.18))
                        .frame(width: 72, height: 3.5)
                    Rectangle()
                        .fill(MujiStyle.ink.opacity(0.08))
                        .frame(width: 48, height: 2.5)
                }
                
                HStack(spacing: 8) {
                    Circle().fill(MujiStyle.tea.opacity(0.4)).frame(width: 8, height: 8)
                    Circle().fill(MujiStyle.clay.opacity(0.4)).frame(width: 8, height: 8)
                    Circle().fill(MujiStyle.indigo.opacity(0.4)).frame(width: 8, height: 8)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Manga 预览

    private var mangaPreview: some View {
        ZStack {
            MangaStyle.paper
            MangaDotsTexture(opacity: 0.08, gap: 8)
            
            ZStack {
                MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow)
                    .scaleEffect(1.2)
                    .frame(width: 46, height: 46)
                    .offset(x: -24, y: -10)
                
                MangaSectionMark(kind: .heart, tint: MangaStyle.accentPink)
                    .scaleEffect(0.9)
                    .frame(width: 30, height: 30)
                    .offset(x: 28, y: 15)
                
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: 1.6)
                    .frame(width: 104, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MangaStyle.bubbleWhite.opacity(0.9))
                    )
                    .overlay(
                        VStack(spacing: 6) {
                            Text("BOOM!")
                                .font(.system(size: 14, weight: .black, design: .serif))
                                .foregroundColor(MangaStyle.strokeInk)
                            HStack(spacing: 4) {
                                Capsule().fill(MangaStyle.strokeInk).frame(width: 24, height: 3)
                                Capsule().fill(MangaStyle.accentPink).frame(width: 14, height: 3)
                            }
                        }
                    )
                    .shadow(color: MangaStyle.strokeInk.opacity(0.08), radius: 0, x: 3, y: 3)
            }
        }
    }

    // MARK: - Neumorphic 预览

    private var neumorphicPreview: some View {
        let base = colorScheme == .dark ? Color(hex: "1F2327") : Color(hex: "F2EEE8")
        let accent = Color(hex: "4F8E86")
        
        return ZStack {
            base
            NeumorphicDiffuseGradient().opacity(0.38)
            
            VStack(spacing: 12) {
                Circle()
                    .fill(base)
                    .frame(width: 58, height: 58)
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.48) : Color.black.opacity(0.12), radius: 6, x: 4, y: 4)
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.88), radius: 6, x: -4, y: -4)
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(colors: [accent.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 28)
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(accent.opacity(0.34), lineWidth: 1.5)
                            .frame(width: 44, height: 44)
                    )
                    .overlay(
                        Circle()
                            .fill(accent)
                            .frame(width: 10, height: 10)
                            .shadow(color: accent.opacity(0.35), radius: 4, y: 2)
                    )
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.black.opacity(0.24) : Color.white.opacity(0.42))
                        .frame(width: 72, height: 6)
                        .overlay(
                            Capsule().stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.06), lineWidth: 0.5)
                        )
                    
                    Capsule()
                        .fill(accent)
                        .frame(width: 32, height: 6)
                }
            }
        }
    }

    // MARK: - Capsule OS 预览

    private var capsulePreview: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "111725"), Color(hex: "1B2440"), Color(hex: "221C38")]
                    : [Color(hex: "F6F8FF"), Color(hex: "EAF1FF"), Color(hex: "F8F2FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(Color(hex: "3867FF"))
                        .frame(width: 44, height: 20)
                        .overlay(
                            Text("OS")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                    
                    Circle()
                        .fill(Color(hex: "2EC8E6"))
                        .frame(width: 20, height: 20)
                    
                    Circle()
                        .fill(Color(hex: "8476FF"))
                        .frame(width: 20, height: 20)
                }
                
                HStack(spacing: 6) {
                    Capsule()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.62))
                        .frame(width: 34, height: 16)
                    Capsule()
                        .fill(Color(hex: "3867FF").opacity(0.18))
                        .frame(width: 52, height: 16)
                }
            }
        }
    }

    private var pureWhitePreview: some View {
        ZStack {
            PureWhiteRootBackdrop()
            
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("01 // PURE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(PureWhiteStyle.strokeInk.opacity(0.68))
                    Spacer()
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(PureWhiteStyle.paperBlue.opacity(0.38))
                        .frame(width: 18, height: 10)
                }
                
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PureWhiteStyle.strokeInk, lineWidth: 1.2)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(PureWhiteStyle.surfaceRaised))
                        .overlay(
                            MonologueIcon(icon: .sparkle, size: 16, color: PureWhiteStyle.accent, lineWidth: 1.8)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(PureWhiteStyle.strokeInk).frame(width: 50, height: 4)
                        Capsule().fill(PureWhiteStyle.strokeInk.opacity(0.24)).frame(width: 34, height: 3)
                    }
                }
            }
            .padding(12)
        }
    }

    private var petWhitePreview: some View {
        ZStack {
            PetWhiteStyle.paper
            
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PetWhiteStyle.surfaceRaised)
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PetWhiteStyle.stroke.opacity(0.72), lineWidth: 1.1)
                        )
                        
                    PetWhitePawPrint(size: 32, tint: PetWhiteStyle.dogOrange)
                }
                
                HStack(spacing: 6) {
                    Capsule()
                        .fill(PetWhiteStyle.mint)
                        .frame(width: 32, height: 6)
                    Capsule()
                        .fill(PetWhiteStyle.butter)
                        .frame(width: 18, height: 6)
                    Capsule()
                        .fill(PetWhiteStyle.blush.opacity(0.7))
                        .frame(width: 12, height: 6)
                }
            }
        }
    }

    // MARK: - Sequoia 预览

    private var sequoiaPreview: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "070A10"), Color(hex: "151922"), Color(hex: "06080D")]
                    : [Color(hex: "FCFEFF"), Color(hex: "F4F7FB"), Color(hex: "E3EBF2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SequoiaStyle.glass.opacity(0.45)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.28), lineWidth: 0.65))
                    .frame(width: 86, height: 86)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 10, y: 5)
                
                VStack(spacing: 8) {
                    MonologueIcon(icon: .musicNote, size: 28, color: SequoiaStyle.accent, lineWidth: 1.8)
                        .shadow(color: SequoiaStyle.accent.opacity(0.35), radius: 6)
                    
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(SequoiaStyle.aqua.opacity(index == 1 ? 0.9 : 0.42))
                                .frame(width: 3, height: CGFloat(6 + index * 4))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Liquid Glass 预览

    private var liquidGlassPreview: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "07111E"), Color(hex: "12243A"), Color(hex: "10142A")]
                    : [Color(hex: "F2F8FF"), Color(hex: "E8FBFF"), Color(hex: "F4F1FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            LiquidGlassCausticField(opacity: colorScheme == .dark ? 0.12 : 0.18)
            
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(LiquidGlassStyle.glassPressed.opacity(0.68)))
                    .overlay(Circle().stroke(Color.white.opacity(0.42), lineWidth: 0.8))
                    .frame(width: 66, height: 60)
                    .shadow(color: LiquidGlassStyle.accent.opacity(0.2), radius: 8, y: 4)
                
                Circle()
                    .fill(
                        LinearGradient(colors: [LiquidGlassStyle.accent, LiquidGlassStyle.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        MonologueIcon(icon: .waveform, size: 14, color: .white, lineWidth: 1.6)
                    )
                    .shadow(color: LiquidGlassStyle.accent.opacity(0.4), radius: 6, y: 3)
            }
        }
    }

    // MARK: - Bento 预览

    private var bentoPreview: some View {
        ZStack {
            BentoStyle.paper
            
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BentoStyle.tomato)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(BentoStyle.onAccent)
                    )
                
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BentoStyle.sakura)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BentoStyle.matcha)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 44)
            }
            .padding(10)
        }
    }


}
