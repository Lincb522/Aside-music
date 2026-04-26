import SwiftUI

/// 全局主题选择卡片 — 用于外观设置中展示主题预览
struct GlobalThemeOptionCard: View {
    let themeId: GlobalThemeId
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // 预览区域
                previewArea
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected
                                    ? previewAccent.opacity(0.6)
                                    : Color.monologueSeparator.opacity(0.3),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white, Color.monologueAccent)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: themeId.iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? previewAccent : .monologueTextSecondary)

                    Text(themeId.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                }

                Text(themeId.description)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .frame(width: 150)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected
                    ? Color.monologueIconBackground.opacity(0.14)
                    : Color.monologueSeparator.opacity(0.38)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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

            VStack(spacing: 4) {
                // 迷你标题行
                HStack {
                    RoundedRectangle(cornerRadius: 2).fill(Color.monologueTextPrimary.opacity(0.3))
                        .frame(width: 40, height: 6)
                    Spacer()
                    Circle().fill(Color.monologueSeparator).frame(width: 12, height: 12)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)

                // 迷你卡片
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.monologueSeparator.opacity(0.6))
                            .frame(height: 36)
                    }
                }
                .padding(.horizontal, 12)

                Spacer()
            }
        }
    }

    // MARK: - Muji 预览

    private var mujiPreview: some View {
        ZStack {
            MujiStyle.paper
            MujiPaperTexture(opacity: 0.22)

            VStack(alignment: .leading, spacing: 6) {
                // 衬线标题
                HStack {
                    RoundedRectangle(cornerRadius: 1).fill(MujiStyle.ink.opacity(0.24)).frame(width: 55, height: 5)
                    Spacer()
                }
                .padding(.top, 12)

                Rectangle().fill(MujiStyle.separator).frame(width: 20, height: 0.5)

                // 方形封面 + 文字
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 3) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(MujiStyle.surfaceRaised)
                                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.4))
                                .frame(width: 44, height: 44)
                            RoundedRectangle(cornerRadius: 1).fill(MujiStyle.ink.opacity(0.15)).frame(width: 36, height: 3)
                        }
                    }
                    Spacer()
                }

                Spacer()

                // 底部薄线
                LinearGradient(colors: [MujiStyle.clay.opacity(0.5), MujiStyle.tea.opacity(0.32)], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
            }
            .padding(.horizontal, 12)
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
                        .overlay(Capsule().stroke(MangaStyle.ink, lineWidth: 1))
                        .background(Capsule().fill(MangaStyle.ink).offset(x: 1, y: 1))
                }

                HStack(spacing: 5) {
                    previewPanel(MangaStyle.bubblePink, height: 34)
                    previewPanel(MangaStyle.bubbleBlue, height: 42)
                }

                previewPanel(MangaStyle.bubbleWhite, height: 18)
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
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(MangaStyle.ink, lineWidth: 1.1))
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(MangaStyle.ink).offset(x: 1.5, y: 1.5))
    }
}
