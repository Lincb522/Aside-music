import SwiftUI

/// 全局主题选择卡片 — 「型录标本」式海报预览
///
/// 不再用灰条假文拼「迷你界面」：每张卡就是该主题的一页真实标本 ——
/// 主题自己的纸面与纹理、用主题字体排出的主题名、主题真实材质做的
/// 迷你播放条、一排真实配色色点。差异来自主题本身，而非线框骨架。
struct GlobalThemeOptionCard: View {
    let themeId: GlobalThemeId
    let isSelected: Bool

    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack(alignment: .topTrailing) {
            poster
                .frame(height: 156)
                .frame(maxWidth: .infinity)
                .compositingGroup()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isSelected
                                ? selectionTint.opacity(0.8)
                                : Color.monoSeparator.opacity(0.45),
                            lineWidth: isSelected ? 1.7 : 0.8
                        )
                )
                .shadow(
                    color: isSelected ? selectionTint.opacity(0.16) : .clear,
                    radius: 9,
                    y: 4
                )

            if isSelected {
                ZStack {
                    Circle()
                        .fill(selectionTint)
                    MonoIcon(
                        icon: .checkmark,
                        size: 10,
                        color: ThemeColorCustomization.readableForegroundColor(on: selectionTint, light: Color(hex: "111821"), dark: .white),
                        lineWidth: 2.2
                    )
                }
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.white.opacity(0.92), lineWidth: 1.2))
                .shadow(color: selectionTint.opacity(0.35), radius: 5, y: 2)
                .padding(8)
            }
        }
    }

    private var isDark: Bool { colorScheme == .dark }

    // MARK: - 分发

    @ViewBuilder
    private var poster: some View {
        switch themeId {
        case .default:
            asidePoster
        case .petWhite:
            pawPoster
        case .minimalWhite:
            minimalWhitePoster
        case .muji:
            mujiPoster
        case .manga:
            mangaPoster
        case .neumorphic:
            neumorphicPoster
        case .capsule:
            capsulePoster
        case .clarity:
            clarityPoster
        }
    }

    private var selectionTint: Color {
        switch themeId {
        case .default:      return isDark ? .white : Color(hex: "111111")
        case .muji:         return Color(hex: "B8694A")
        case .manga:        return Color(hex: "111110")
        case .neumorphic:   return Color(hex: "4F8E86")
        case .capsule:      return Color(hex: "3867FF")
        case .petWhite:     return Color(hex: "F6A93B")
        case .minimalWhite: return MinimalWhiteStyle.accent
        case .clarity:      return Color(hex: "2478D8")
        }
    }

    // MARK: - 通透感

    private var clarityPoster: some View {
        ZStack {
            LinearGradient(
                colors: isDark
                    ? [Color(hex: "131C25"), Color(hex: "0D1218")]
                    : [Color(hex: "F7F8F8"), Color(hex: "E8EFF1")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: "C5B8E8").opacity(0.34))
                .frame(width: 108, height: 108)
                .blur(radius: 26)
                .offset(x: 62, y: -50)

            Circle()
                .fill(Color(hex: "70D8E8").opacity(0.28))
                .frame(width: 118, height: 118)
                .blur(radius: 28)
                .offset(x: -70, y: 66)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Capsule()
                        .fill(Color.white.opacity(isDark ? 0.28 : 0.9))
                        .frame(width: 22, height: 3)

                    Spacer(minLength: 0)

                    paletteDots([
                        Color(hex: "2879E8"),
                        Color(hex: "70D8E8"),
                        Color(hex: "C5B8E8")
                    ], ring: Color.white.opacity(0.7))
                }

                Text(themeId.displayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? Color.white : Color(hex: "11151A"))
                    .padding(.top, 8)

                Spacer(minLength: 6)

                miniPlayerChip(
                    cover: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "C5B8E8"), Color(hex: "70D8E8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ),
                    coverRadius: 8,
                    titleFont: .system(size: 9.5, weight: .bold, design: .rounded),
                    artistFont: .system(size: 7.5, weight: .medium, design: .rounded),
                    titleColor: isDark ? .white : Color(hex: "11151A"),
                    artistColor: isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.42),
                    accent: Color(hex: "2879E8"),
                    playForeground: .white,
                    background: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.56))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(isDark ? 0.18 : 0.82), lineWidth: 0.9)
                        )
                        .shadow(color: Color.black.opacity(isDark ? 0.26 : 0.08), radius: 8, y: 4)
                )
            }
            .padding(12)
        }
    }

    // MARK: - 共用小件

    /// 真实配色色点（始终为选中角标预留右侧空间，避免布局跳动）
    private func paletteDots(_ colors: [Color], ring: Color = .clear) -> some View {
        HStack(spacing: 4) {
            ForEach(colors.indices, id: \.self) { index in
                Circle()
                    .fill(colors[index])
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(ring, lineWidth: 0.6))
            }
        }
        .padding(.trailing, 18)
    }

    /// 迷你播放条 — 用主题真实材质与真实文字构成
    private func miniPlayerChip<Cover: View, Chrome: View>(
        cover: Cover,
        coverRadius: CGFloat,
        title: String = "晚风",
        artist: String = "Mono",
        titleFont: Font,
        artistFont: Font,
        titleColor: Color,
        artistColor: Color,
        accent: Color,
        playForeground: Color,
        background: Chrome
    ) -> some View {
        HStack(spacing: 8) {
            cover
                .frame(width: 27, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(titleColor)
                    .lineLimit(1)

                Text(artist)
                    .font(artistFont)
                    .foregroundColor(artistColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Circle()
                .fill(accent)
                .frame(width: 19, height: 19)
                .overlay(
                    MonoIcon(icon: .play, size: 7.5, color: playForeground, lineWidth: 1.7)
                        .offset(x: 0.5)
                )
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background { background }
    }

    // MARK: - Aside 经典（编辑部）

    private var asidePoster: some View {
        let paper = isDark ? Color(hex: "0C0C0E") : Color(hex: "F6F6F4")
        let ink = isDark ? Color.white : Color(hex: "141414")
        let hairline = ink.opacity(0.14)

        return ZStack {
            paper

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(ink)
                        .frame(width: 14, height: 3)

                    Text("EDITORIAL")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .tracking(1.8)
                        .foregroundColor(ink.opacity(0.45))

                    Spacer(minLength: 0)

                    paletteDots([ink, ink.opacity(0.38), ink.opacity(0.14)])
                }

                Text(themeId.displayName)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    Text("01")
                        .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundColor(ink.opacity(0.4))

                    Rectangle()
                        .fill(hairline)
                        .frame(height: 0.6)
                }
                .padding(.top, 7)

                Spacer(minLength: 6)

                miniPlayerChip(
                    cover: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ink.opacity(0.3), ink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ),
                    coverRadius: 7,
                    titleFont: .system(size: 9.5, weight: .bold, design: .rounded),
                    artistFont: .system(size: 7.5, weight: .semibold, design: .rounded),
                    titleColor: ink,
                    artistColor: ink.opacity(0.45),
                    accent: ink,
                    playForeground: isDark ? Color(hex: "141414") : .white,
                    background: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isDark ? Color.white.opacity(0.07) : Color.white)
                        .shadow(color: Color.black.opacity(isDark ? 0.3 : 0.06), radius: 6, y: 3)
                )
            }
            .padding(12)
        }
    }

    // MARK: - Paw 黏土玩具

    private var pawPoster: some View {
        ZStack {
            PetWhiteStyle.paper

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    PetWhitePawPrint(size: 14, tint: PetWhiteStyle.dogOrange)

                    Spacer(minLength: 0)

                    paletteDots(
                        [PetWhiteStyle.dogOrange, PetWhiteStyle.mint, PetWhiteStyle.blush],
                        ring: PetWhiteStyle.stroke.opacity(0.5)
                    )
                }

                Text(themeId.displayName)
                    .font(PetWhiteStyle.titleFont(19, weight: .black))
                    .foregroundColor(PetWhiteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 8)

                // 糖果小胶囊
                HStack(spacing: 4) {
                    Capsule().fill(PetWhiteStyle.mint).frame(width: 18, height: 5)
                    Capsule().fill(PetWhiteStyle.butter).frame(width: 12, height: 5)
                    Capsule().fill(PetWhiteStyle.blush.opacity(0.8)).frame(width: 8, height: 5)
                }
                .padding(.top, 7)

                Spacer(minLength: 6)

                miniPlayerChip(
                    cover: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(PetWhiteStyle.butter.opacity(0.55))
                        .overlay(PetWhitePawPrint(size: 14, tint: PetWhiteStyle.dogOrange)),
                    coverRadius: 9,
                    titleFont: PetWhiteStyle.labelFont(9.5, weight: .black),
                    artistFont: PetWhiteStyle.labelFont(7.5, weight: .bold),
                    titleColor: PetWhiteStyle.ink,
                    artistColor: PetWhiteStyle.inkSoft.opacity(0.75),
                    accent: PetWhiteStyle.dogOrange,
                    playForeground: .white,
                    background: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PetWhiteStyle.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PetWhiteStyle.stroke.opacity(0.8), lineWidth: 1.3)
                        )
                )
            }
            .padding(12)
        }
    }

    // MARK: - 纯白极简

    private var minimalWhitePoster: some View {
        ZStack {
            MinimalWhiteStyle.paper

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .stroke(MinimalWhiteStyle.ink, lineWidth: 1.1)
                        .frame(width: 9, height: 9)

                    Spacer(minLength: 0)

                    paletteDots(
                        [MinimalWhiteStyle.ink, MinimalWhiteStyle.controlFill, MinimalWhiteStyle.paper],
                        ring: MinimalWhiteStyle.separator
                    )
                }

                Text(themeId.displayName)
                    .font(MinimalWhiteStyle.titleFont(19, weight: .semibold))
                    .foregroundColor(MinimalWhiteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 9)

                Rectangle()
                    .fill(MinimalWhiteStyle.separator)
                    .frame(height: 0.7)
                    .padding(.top, 8)

                Spacer(minLength: 6)

                miniPlayerChip(
                    cover: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(MinimalWhiteStyle.controlFill)
                        .overlay(
                            MonoIcon(icon: .musicNote, size: 11, color: MinimalWhiteStyle.ink, lineWidth: 1.5)
                        ),
                    coverRadius: 6,
                    titleFont: MinimalWhiteStyle.labelFont(9.5, weight: .semibold),
                    artistFont: MinimalWhiteStyle.labelFont(7.5, weight: .regular),
                    titleColor: MinimalWhiteStyle.ink,
                    artistColor: MinimalWhiteStyle.inkMuted,
                    accent: MinimalWhiteStyle.ink,
                    playForeground: MinimalWhiteStyle.paper,
                    background: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(MinimalWhiteStyle.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(MinimalWhiteStyle.separator, lineWidth: 0.8)
                        )
                )
            }
            .padding(12)
        }
    }

    // MARK: - 无印良品

    private var mujiPoster: some View {
        ZStack {
            MujiStyle.paper

            // 清新水彩晕染角落
            Ellipse()
                .fill(MujiStyle.clay.opacity(0.12))
                .frame(width: 110, height: 90)
                .blur(radius: 22)
                .offset(x: 46, y: -38)

            Ellipse()
                .fill(MujiStyle.straw.opacity(0.14))
                .frame(width: 90, height: 80)
                .blur(radius: 20)
                .offset(x: -42, y: 52)

            MujiPaperTexture(opacity: 0.14)

            VStack(alignment: .leading, spacing: 0) {
                // 眉题行：双圆点 + small caps
                HStack(alignment: .center, spacing: 5) {
                    Circle()
                        .fill(MujiStyle.clay)
                        .frame(width: 4, height: 4)
                    Circle()
                        .fill(MujiStyle.straw)
                        .frame(width: 2.5, height: 2.5)

                    Text("NOTE")
                        .font(.system(size: 6.5, weight: .semibold, design: .rounded))
                        .foregroundColor(MujiStyle.clay)
                        .tracking(1.2)
                        .padding(.leading, 2)
                }

                Text(themeId.displayName)
                    .font(MujiStyle.titleFont(18, weight: .medium))
                    .foregroundColor(MujiStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 9)

                HStack(spacing: 4) {
                    Circle().fill(MujiStyle.tea).frame(width: 3.5, height: 3.5)
                    Circle().fill(MujiStyle.clay).frame(width: 3.5, height: 3.5)
                    Circle().fill(MujiStyle.indigo).frame(width: 3.5, height: 3.5)
                }
                .padding(.top, 8)

                Spacer(minLength: 6)

                miniPlayerChip(
                    cover: RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.3)),
                    coverRadius: 4.5,
                    titleFont: MujiStyle.bodyFont(9.5, weight: .medium),
                    artistFont: MujiStyle.labelFont(7.5, weight: .regular),
                    titleColor: MujiStyle.ink,
                    artistColor: MujiStyle.ink.opacity(0.5),
                    accent: MujiStyle.clay,
                    playForeground: MujiStyle.onTint,
                    background: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(MujiStyle.surface.opacity(0.92))
                        .shadow(color: MujiStyle.ink.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            .padding(12)
        }
    }

    // MARK: - 漫画风

    private var mangaPoster: some View {
        ZStack {
            MangaComicPalette.paper
            MangaScreentone(opacity: 0.06, gap: 9, fadeFrom: .topTrailing)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    MangaSectionMark(kind: .note, size: 15)

                    Spacer(minLength: 0)

                    paletteDots(
                        [MangaComicPalette.ink, MangaComicPalette.toneMid, MangaComicPalette.paperShadow],
                        ring: MangaComicPalette.ink.opacity(0.6)
                    )
                }

                Text(themeId.displayName)
                    .font(MangaStyle.comicFont(19, weight: .black))
                    .foregroundColor(MangaComicPalette.ink)
                    .shadow(color: MangaComicPalette.toneLight, radius: 0, x: 2, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 8)

                // 排线
                MangaHatching(opacity: 0.5, gap: 3.5, angle: 0, lineWidth: 1)
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)

                Spacer(minLength: 6)

                miniPlayerChip(
                    cover: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(MangaComicPalette.paperWarm)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(MangaComicPalette.ink, lineWidth: 1.3)
                        ),
                    coverRadius: 4,
                    titleFont: MangaStyle.comicFont(9.5, weight: .black),
                    artistFont: MangaStyle.comicFont(7.5, weight: .bold),
                    titleColor: MangaComicPalette.ink,
                    artistColor: MangaComicPalette.ink.opacity(0.55),
                    accent: MangaComicPalette.ink,
                    playForeground: MangaComicPalette.whiteInk,
                    background: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(MangaComicPalette.paperBright)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(MangaComicPalette.ink, lineWidth: 1.5)
                        )
                        .shadow(color: MangaComicPalette.ink, radius: 0, x: 2.5, y: 2.5)
                )
            }
            .padding(12)
        }
    }

    // MARK: - 新拟物

    private var neumorphicPoster: some View {
        let base = isDark ? Color(hex: "23282D") : Color(hex: "EEF2F4")
        let raised = isDark ? Color(hex: "2B3138") : Color(hex: "F6F9FA")
        let darkShadow = isDark ? Color.black.opacity(0.42) : Color.black.opacity(0.11)
        let lightShadow = isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.9)
        let ink = isDark ? Color(hex: "D5DCE1") : Color(hex: "3A4750")
        let accent = Color(hex: "4F8E86")

        return ZStack {
            base

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(base)
                        .frame(width: 13, height: 13)
                        .shadow(color: darkShadow, radius: 2, x: 1.5, y: 1.5)
                        .shadow(color: lightShadow, radius: 2, x: -1.5, y: -1.5)
                        .overlay(Circle().fill(accent).frame(width: 4.5, height: 4.5))

                    Spacer(minLength: 0)

                    paletteDots([accent, ink.opacity(0.4), raised], ring: ink.opacity(0.14))
                }

                Text(themeId.displayName)
                    .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                    .foregroundColor(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 9)

                // 凹陷滑轨
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(isDark ? Color.black.opacity(0.3) : Color.black.opacity(0.07))
                        .frame(width: 58, height: 7)

                    Circle()
                        .fill(raised)
                        .frame(width: 12, height: 12)
                        .shadow(color: darkShadow, radius: 2, x: 1.5, y: 1.5)
                        .shadow(color: lightShadow, radius: 2, x: -1.5, y: -1.5)
                        .offset(x: 31)
                }
                .padding(.top, 9)

                Spacer(minLength: 6)

                miniPlayerChip(
                    cover: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(base)
                        .shadow(color: darkShadow, radius: 2.5, x: 2, y: 2)
                        .shadow(color: lightShadow, radius: 2.5, x: -2, y: -2)
                        .overlay(
                            MonoIcon(icon: .musicNote, size: 10, color: accent.opacity(0.85), lineWidth: 1.5)
                        ),
                    coverRadius: 8,
                    titleFont: NeumorphicStyle.labelFont(9.5, weight: .semibold),
                    artistFont: NeumorphicStyle.labelFont(7.5, weight: .medium),
                    titleColor: ink,
                    artistColor: ink.opacity(0.5),
                    accent: accent,
                    playForeground: .white,
                    background: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(raised)
                        .shadow(color: darkShadow, radius: 5, x: 3.5, y: 3.5)
                        .shadow(color: lightShadow, radius: 5, x: -3.5, y: -3.5)
                )
            }
            .padding(12)
        }
    }

    // MARK: - Capsule OS

    private var capsulePoster: some View {
        let blue = Color(hex: "3867FF")
        let cyan = Color(hex: "2EC8E6")
        let purple = Color(hex: "8476FF")
        let ink = isDark ? Color.white : Color(hex: "182034")
        let surface = isDark ? Color.white.opacity(0.09) : Color.white.opacity(0.8)

        return ZStack {
            LinearGradient(
                colors: isDark
                    ? [Color(hex: "111725"), Color(hex: "1B2440"), Color(hex: "221C38")]
                    : [Color(hex: "F6F8FF"), Color(hex: "EAF1FF"), Color(hex: "F8F2FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Capsule()
                        .fill(blue)
                        .frame(width: 28, height: 13)
                        .overlay(
                            Text("OS")
                                .font(.system(size: 7, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        )

                    Spacer(minLength: 0)

                    paletteDots([blue, cyan, purple])
                }

                Text(themeId.displayName)
                    .font(CapsuleStyle.titleFont(18, weight: .bold))
                    .foregroundColor(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 8)

                HStack(spacing: 4) {
                    Capsule().fill(blue.opacity(0.85)).frame(width: 20, height: 5)
                    Capsule().fill(cyan.opacity(0.8)).frame(width: 13, height: 5)
                    Capsule().fill(ink.opacity(0.16)).frame(width: 9, height: 5)
                }
                .padding(.top, 8)

                Spacer(minLength: 6)

                miniPlayerChip(
                    cover: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(colors: [blue, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(
                            MonoIcon(icon: .waveform, size: 11, color: .white, lineWidth: 1.5)
                        ),
                    coverRadius: 12,
                    titleFont: CapsuleStyle.labelFont(9.5, weight: .bold),
                    artistFont: CapsuleStyle.labelFont(7.5, weight: .semibold),
                    titleColor: ink,
                    artistColor: ink.opacity(0.5),
                    accent: blue,
                    playForeground: .white,
                    background: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(isDark ? 0.14 : 0.65), lineWidth: 0.8)
                        )
                )
            }
            .padding(12)
        }
    }

}
