import SwiftUI

/// 全局主题选择卡片 — 用于外观设置中展示主题预览
struct GlobalThemeOptionCard: View {
    let themeId: GlobalThemeId
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                previewArea
                    .frame(height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        MonologueIcon(icon: .checkmark, size: 11, color: .white, lineWidth: 2.2)
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
        .frame(width: 172)
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
        }
    }

    private var previewAccent: Color {
        switch themeId {
        case .default:   return .monologueAccent
        case .muji:      return Color(hex: "C4775A")
        case .manga:     return Color(hex: "FF8FAB")
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
}
