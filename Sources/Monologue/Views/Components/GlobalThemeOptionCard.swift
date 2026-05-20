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
        case .default:   return .monologueAccent
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.monologueAccent)
                        .frame(width: 14, height: 14)

                    VStack(alignment: .leading, spacing: 3) {
                        Capsule()
                            .fill(Color.monologueTextPrimary.opacity(0.28))
                            .frame(width: 42, height: 4)
                        Capsule()
                            .fill(Color.monologueTextPrimary.opacity(0.12))
                            .frame(width: 28, height: 3)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.monologueAccent.opacity(0.9), Color.monologueAccent.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.monologueTextPrimary.opacity(index == 0 ? 0.24 : 0.12))
                                .frame(width: index == 2 ? 42 : 58, height: 5)
                        }

                        HStack(spacing: 4) {
                            Circle().fill(Color.monologueAccent.opacity(0.8)).frame(width: 10, height: 10)
                            Capsule().fill(Color.monologueAccent.opacity(0.25)).frame(width: 44, height: 5)
                        }
                    }
                }

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.monologueSeparator.opacity(index == 1 ? 0.72 : 0.42))
                            .frame(height: 18)
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: - Muji 预览

    private var mujiPreview: some View {
        ZStack {
            MujiStyle.paper
            MujiPaperTexture(opacity: 0.22)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(MujiStyle.clay.opacity(0.65))
                        .frame(width: 18, height: 18)
                        .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).stroke(MujiStyle.hairline, lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 3) {
                        Rectangle().fill(MujiStyle.ink.opacity(0.22)).frame(width: 46, height: 4)
                        Rectangle().fill(MujiStyle.ink.opacity(0.12)).frame(width: 30, height: 3)
                    }

                    Spacer()
                }

                Rectangle().fill(MujiStyle.separator).frame(width: 20, height: 0.5)

                HStack(alignment: .top, spacing: 9) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(MujiStyle.surfaceRaised)
                        .frame(width: 46, height: 52)
                        .overlay(
                            VStack(spacing: 4) {
                                Rectangle().fill(MujiStyle.hairline.opacity(0.55)).frame(height: 0.6)
                                Rectangle().fill(MujiStyle.hairline.opacity(0.35)).frame(height: 0.6)
                                Spacer()
                            }
                            .padding(7)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<4, id: \.self) { index in
                            Rectangle()
                                .fill(index == 1 ? MujiStyle.clay.opacity(0.45) : MujiStyle.ink.opacity(0.12))
                                .frame(width: index == 3 ? 40 : 58, height: index == 1 ? 6 : 4)
                        }
                    }
                    .padding(.top, 2)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 3) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill([MujiStyle.tea, MujiStyle.clay, MujiStyle.indigo][index].opacity(0.22))
                                .frame(height: 14)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Manga 预览

    private var mangaPreview: some View {
        ZStack {
            LinearGradient(
                colors: [MangaStyle.paper, MangaStyle.paperCool, MangaStyle.paperWarm],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            MangaDotsTexture(opacity: 0.08, gap: 8)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow)
                        .scaleEffect(0.55)
                        .frame(width: 16, height: 16)

                    Spacer()

                    Capsule()
                        .fill(MangaStyle.labelYellow)
                        .frame(width: 34, height: 9)
                        .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1))
                        .background(Capsule().fill(MangaStyle.strokeInk).offset(x: 1, y: 1))
                }

                HStack(spacing: 6) {
                    previewPanel(MangaStyle.bubblePink, height: 36)
                    previewPanel(MangaStyle.bubbleBlue, height: 46)
                }

                HStack(spacing: 6) {
                    previewMiniBubble(tint: MangaStyle.mint)
                    previewMiniBubble(tint: MangaStyle.paperWarm)
                    previewMiniBubble(tint: MangaStyle.bubbleWhite)
                }
            }
            .padding(10)
        }
    }

    private func previewPanel(_ fill: Color, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(fill)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(MangaStyle.ink.opacity(0.65)).frame(width: 28, height: 3)
                    Capsule().fill(MangaStyle.ink.opacity(0.28)).frame(width: 18, height: 2)
                }
                .padding(5),
                alignment: .bottomLeading
            )
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.1))
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 1.5, y: 1.5))
    }

    private func previewMiniBubble(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(tint)
            .frame(height: 18)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1))
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 1, y: 1))
    }

    // MARK: - Neumorphic 预览

    private var neumorphicPreview: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "202429"), Color(hex: "1B1F24"), Color(hex: "292722")]
                    : [Color(hex: "F2EEE8"), Color(hex: "E9EDF0"), Color(hex: "EEF2F4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            NeumorphicDiffuseGradient()
                .opacity(0.58)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(NeumorphicStyle.accent.opacity(0.82))
                        .frame(width: 14, height: 14)

                    VStack(alignment: .leading, spacing: 3) {
                        Capsule()
                            .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.26))
                            .frame(width: 42, height: 4)
                        Capsule()
                            .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.12))
                            .frame(width: 28, height: 3)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [NeumorphicStyle.accent.opacity(0.86), NeumorphicStyle.sage.opacity(0.34)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.08), lineWidth: 0.8)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill((colorScheme == .dark ? Color.white : Color.black).opacity(index == 0 ? 0.24 : 0.12))
                                .frame(width: index == 2 ? 42 : 58, height: 5)
                        }

                        HStack(spacing: 4) {
                            Circle().fill(NeumorphicStyle.accent.opacity(0.78)).frame(width: 10, height: 10)
                            Capsule().fill(NeumorphicStyle.accent.opacity(0.24)).frame(width: 44, height: 5)
                        }
                    }
                }

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(NeumorphicStyle.surfacePressed.opacity(index == 1 ? 0.82 : 0.54))
                            .frame(height: 18)
                    }
                }
            }
            .padding(12)
        }
    }

    private func previewNeumorphicTile(width: CGFloat, height: CGFloat, radius: CGFloat, tint: Color, elevated: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.clear)
            .frame(width: width, height: height)
            .background(NeumorphicSurfaceBackground(cornerRadius: radius, elevated: elevated, pressed: !elevated, tint: tint.opacity(colorScheme == .dark ? 0.5 : 0.42), lightweight: true))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func previewNeumorphicLine(width: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill((colorScheme == .dark ? Color.white : Color.black).opacity(opacity))
            .frame(width: width, height: 5)
    }

    private func previewNeumorphicCircle(size: CGFloat, tint: Color) -> some View {
        Circle()
            .fill(Color.clear)
            .frame(width: size, height: size)
            .background(NeumorphicSurfaceBackground(cornerRadius: size / 2, elevated: true, tint: tint.opacity(colorScheme == .dark ? 0.46 : 0.38)))
            .clipShape(Circle())
    }

    private var previewNeumorphicProgress: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.clear)
                .frame(width: 70, height: 8)
                .background(NeumorphicSurfaceBackground(cornerRadius: 4, elevated: false, pressed: true, lightweight: true))
                .clipShape(Capsule())

            Capsule()
                .fill(NeumorphicStyle.accent.opacity(0.7))
                .frame(width: 42, height: 5)
                .padding(.leading, 1.5)
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Capsule().fill(Color(hex: "3867FF")).frame(width: 28, height: 7)
                    Circle().fill(Color(hex: "2EC8E6")).frame(width: 7, height: 7)
                    Circle().fill(Color(hex: "8476FF")).frame(width: 7, height: 7)
                    Spacer()
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.66))
                        .frame(width: 28, height: 20)
                }

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.82))
                        .frame(width: 58, height: 52)
                        .overlay(
                            VStack(spacing: 5) {
                                Capsule().fill(Color(hex: "3867FF")).frame(width: 30, height: 8)
                                Capsule().fill(Color(hex: "2EC8E6").opacity(0.4)).frame(width: 20, height: 5)
                            }
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(CapsuleStyle.ink.opacity(0.22)).frame(width: 64, height: 6)
                        Capsule().fill(CapsuleStyle.ink.opacity(0.12)).frame(width: 42, height: 5)
                        HStack(spacing: 5) {
                            Capsule().fill(Color(hex: "3867FF").opacity(0.24)).frame(width: 32, height: 17)
                            Capsule().fill(Color(hex: "35CFA8").opacity(0.22)).frame(width: 25, height: 17)
                        }
                    }
                }

                HStack(spacing: 6) {
                    capsulePreviewPill(tint: Color(hex: "3867FF"), selected: true)
                    capsulePreviewPill(tint: Color(hex: "35CFA8"))
                    capsulePreviewPill(tint: Color(hex: "F0AD3D"))
                }
            }
            .padding(10)
        }
    }

    private func capsulePreviewPill(tint: Color, selected: Bool = false) -> some View {
        Capsule()
            .fill(selected ? tint : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.58))
            .frame(height: selected ? 22 : 18)
            .overlay(
                Capsule()
                    .stroke(selected ? Color.white.opacity(0.38) : tint.opacity(0.18), lineWidth: 0.8)
            )
    }

    private var pureWhitePreview: some View {
        ZStack {
            PureWhiteRootBackdrop()
                .opacity(colorScheme == .dark ? 0.92 : 1)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    PureWhiteIconBadge(icon: .sparkle, tint: PureWhiteStyle.accent, size: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(PureWhiteStyle.strokeInk.opacity(0.24)).frame(width: 50, height: 5)
                        Capsule().fill(PureWhiteStyle.strokeInk.opacity(0.12)).frame(width: 32, height: 3)
                    }

                    Spacer(minLength: 0)

                    Capsule(style: .continuous)
                        .fill(PureWhiteStyle.paperBlue.opacity(0.58))
                        .frame(width: 26, height: 8)
                        .overlay(Capsule(style: .continuous).stroke(PureWhiteStyle.strokeInk.opacity(0.22), lineWidth: 0.8))
                }

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PureWhiteStyle.surfaceRaised)
                        .frame(width: 50, height: 52)
                        .overlay(alignment: .topLeading) {
                            Capsule(style: .continuous)
                                .fill(PureWhiteStyle.accent.opacity(0.82))
                                .frame(width: 22, height: 4)
                                .padding(7)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PureWhiteStyle.strokeInk.opacity(0.52), lineWidth: 1)
                        )
                        .overlay(
                            MonologueIcon(icon: .musicNote, size: 20, color: PureWhiteStyle.ink, lineWidth: 2)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(PureWhiteStyle.strokeInk.opacity(0.22)).frame(width: 56, height: 5)
                        Capsule().fill(PureWhiteStyle.strokeInk.opacity(0.12)).frame(width: 38, height: 4)
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(PureWhiteStyle.paperBlue.opacity(0.36))
                                .frame(width: 24, height: 14)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(PureWhiteStyle.separator.opacity(0.72))
                                .frame(width: 24, height: 14)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(PureWhiteStyle.surfaceTint.opacity(0.94))
                                .frame(width: 24, height: 14)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PureWhiteStyle.paperBlue.opacity(0.48))
                        .frame(height: 18)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PureWhiteStyle.surfaceTint.opacity(0.94))
                        .frame(height: 18)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PureWhiteStyle.separator.opacity(0.54))
                        .frame(height: 18)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PureWhiteStyle.strokeInk.opacity(0.28), lineWidth: 0.8)
                )
            }
            .padding(10)
        }
    }

    private var petWhitePreview: some View {
        ZStack {
            PetWhiteStyle.paper

            LinearGradient(
                colors: [
                    PetWhiteStyle.sky.opacity(0.45),
                    PetWhiteStyle.paper,
                    PetWhiteStyle.butter.opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(PetWhiteStyle.dogOrange.opacity(0.86))
                        .frame(width: 14, height: 14)

                    VStack(alignment: .leading, spacing: 3) {
                        Capsule()
                            .fill(PetWhiteStyle.stroke.opacity(0.28))
                            .frame(width: 42, height: 4)
                        Capsule()
                            .fill(PetWhiteStyle.stroke.opacity(0.12))
                            .frame(width: 28, height: 3)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [PetWhiteStyle.dogOrange.opacity(0.9), PetWhiteStyle.mint.opacity(0.34)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(alignment: .topLeading) {
                            Capsule(style: .continuous)
                                .fill(PetWhiteStyle.paper.opacity(0.78))
                                .frame(width: 18, height: 4)
                                .padding(8)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PetWhiteStyle.stroke.opacity(0.34), lineWidth: 0.9)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(PetWhiteStyle.stroke.opacity(index == 0 ? 0.24 : 0.12))
                                .frame(width: index == 2 ? 42 : 58, height: 5)
                        }

                        HStack(spacing: 4) {
                            Circle().fill(PetWhiteStyle.dogOrange.opacity(0.8)).frame(width: 10, height: 10)
                            Capsule().fill(PetWhiteStyle.dogOrange.opacity(0.25)).frame(width: 44, height: 5)
                        }
                    }
                }

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill((index == 1 ? PetWhiteStyle.mint : PetWhiteStyle.butter).opacity(index == 1 ? 0.72 : 0.42))
                            .frame(height: 18)
                    }
                }
            }
            .padding(12)
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

            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    Capsule().fill(SequoiaStyle.accent.opacity(0.52)).frame(width: 24, height: 5)
                    Capsule().fill(SequoiaStyle.aqua.opacity(0.34)).frame(width: 14, height: 5)
                    Capsule().fill(SequoiaStyle.separator).frame(width: 5, height: 5)
                    Spacer()
                    SequoiaMeter(tint: SequoiaStyle.aqua, count: 5)
                }

                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SequoiaStyle.selectedWash)
                        .frame(width: 48, height: 52)
                        .overlay(
                            MonologueIcon(icon: .musicNote, size: 18, color: SequoiaStyle.accent, lineWidth: 1.6)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(SequoiaStyle.ink.opacity(0.24)).frame(width: 62, height: 5)
                        Capsule().fill(SequoiaStyle.inkSoft.opacity(0.18)).frame(width: 42, height: 4)
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SequoiaStyle.accent.opacity(0.18))
                                .frame(width: 28, height: 16)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SequoiaStyle.aqua.opacity(0.18))
                                .frame(width: 28, height: 16)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill([SequoiaStyle.materialList, SequoiaStyle.selectedWash, SequoiaStyle.aqua.opacity(0.16)][index])
                            .frame(height: 18)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SequoiaStyle.glass.opacity(0.5)))
            )
            .padding(10)
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

            LiquidGlassCausticField(opacity: colorScheme == .dark ? 0.1 : 0.16)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Capsule().fill(LiquidGlassStyle.accent.opacity(0.72)).frame(width: 26, height: 5)
                    Capsule().fill(LiquidGlassStyle.cyan.opacity(0.42)).frame(width: 14, height: 5)
                    Capsule().fill(LiquidGlassStyle.violet.opacity(0.34)).frame(width: 8, height: 5)
                    Spacer()
                    Circle().fill(LiquidGlassStyle.mint.opacity(0.68)).frame(width: 12, height: 12)
                }

                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 50, height: 50)
                            .overlay(Circle().fill(LiquidGlassStyle.glassPressed.opacity(0.74)))
                        Circle()
                            .fill(LiquidGlassStyle.accent.opacity(0.72))
                            .frame(width: 34, height: 34)
                            .overlay(MonologueIcon(icon: .musicNote, size: 13, color: LiquidGlassStyle.onAccent, lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(LiquidGlassStyle.ink.opacity(0.22)).frame(width: 62, height: 5)
                        Capsule().fill(LiquidGlassStyle.inkSoft.opacity(0.16)).frame(width: 42, height: 4)
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LiquidGlassStyle.accent.opacity(0.18))
                                .frame(width: 28, height: 16)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LiquidGlassStyle.violet.opacity(0.16))
                                .frame(width: 28, height: 16)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill([LiquidGlassStyle.glassList, LiquidGlassStyle.selectedWash, LiquidGlassStyle.cyan.opacity(0.15)][index])
                            .frame(height: 18)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.22), lineWidth: 0.5))
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LiquidGlassStyle.glass.opacity(0.62)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.32), lineWidth: 0.65))
            )
            .padding(10)
        }
    }

    // MARK: - Bento 预览

    private var bentoPreview: some View {
        ZStack {
            BentoStyle.paper

            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BentoStyle.tomato)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .topLeading) {
                            Capsule()
                                .fill(BentoStyle.onAccent.opacity(0.3))
                                .frame(width: 26, height: 5)
                                .padding(7)
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 3) {
                                Capsule().fill(BentoStyle.onAccent).frame(width: 38, height: 5)
                                Capsule().fill(BentoStyle.onAccent.opacity(0.5)).frame(width: 22, height: 3)
                            }
                            .padding(7)
                        }

                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(BentoStyle.sakura)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(BentoStyle.mustard)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: 36)
                }
                .frame(height: 76)

                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BentoStyle.matcha)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BentoStyle.ocean)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BentoStyle.nori)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 26)
            }
            .padding(8)
        }
    }


}
