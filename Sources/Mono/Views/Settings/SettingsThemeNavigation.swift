import SwiftUI

// MARK: - Themed Settings Navigation

struct PetWhiteSettingsPortalCard: View {
    let icon: MonoIcon.IconType
    let title: String
    let badge: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                PetWhiteIconBadge(icon: icon, tint: tint, size: 38)

                Spacer(minLength: 8)

                PetWhitePill(text: badge, tint: tint)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(title)
                .font(PetWhiteStyle.titleFont(15, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 116, alignment: .topLeading)
        .padding(14)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 16,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MangaSettingsPortalCard: View {
    let icon: MonoIcon.IconType
    let title: String
    let badge: String
    let tint: Color

    var body: some View {
        // 目录条目：色章图标 + 黑体标题 + 页码式小徽标，直接排在纸上
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint)
                MonoIcon(icon: icon, size: 15, color: iconForeground, lineWidth: 1.8)
            }
            .frame(width: 34, height: 34)
            .rotationEffect(.degrees(-3))

            Text(title)
                .font(MangaStyle.titleFont(15, weight: .black))
                .foregroundStyle(MangaStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Text(badge)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(MangaStyle.inkMuted)
                .lineLimit(1)

            MonoIcon(icon: .chevronRight, size: 12, color: MangaStyle.inkMuted, lineWidth: 1.8)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }

    private var iconForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: tint,
            light: MangaStyle.strokeInk,
            dark: MangaStyle.onStrokeInk
        )
    }
}

/// Muji 主题模式行：裸排行内三段文字选择（系统 / 浅色 / 深色），无展开无容器
struct MujiThemeModeRow: View {
    @Binding var selection: String

    private let options: [(value: String, title: String)] = [
        ("system", String(localized: "settings_theme_auto")),
        ("light", String(localized: "settings_theme_light")),
        ("dark", String(localized: "settings_theme_dark")),
    ]

    var body: some View {
        HStack(spacing: 13) {
            MonoIcon(icon: .sparkle, size: 15, color: MujiStyle.clay, lineWidth: 1.4)
                .frame(width: 22, alignment: .leading)

            Text(String(localized: "settings_theme_mode"))
                .font(MujiStyle.bodyFont(15, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                ForEach(options, id: \.value) { option in
                    Button {
                        guard selection != option.value else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = option.value
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(option.title)
                                .font(MujiStyle.labelFont(11.5, weight: selection == option.value ? .semibold : .regular))
                                .foregroundStyle(selection == option.value ? MujiStyle.clay : MujiStyle.inkMuted)
                                .lineLimit(1)

                            Rectangle()
                                .fill(selection == option.value ? MujiStyle.clay.opacity(0.85) : Color.clear)
                                .frame(height: 1.2)
                        }
                        .fixedSize()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 13.5)
    }
}

struct MujiSettingsLedgerLink: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let destination: SettingsNavigationDestination

    var body: some View {
        NavigationLink {
            destination.view
        } label: {
            HStack(spacing: 13) {
                MonoIcon(icon: icon, size: 15, color: ledgerTint, lineWidth: 1.4)
                    .frame(width: 22, alignment: .leading)

                Text(title)
                    .font(MujiStyle.bodyFont(15, weight: .regular))
                    .foregroundStyle(MujiStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Text(value)
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(MujiStyle.inkMuted)
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                MonoIcon(icon: .chevronRight, size: 10, color: MujiStyle.inkMuted, lineWidth: 1.4)
            }
            .padding(.vertical, 13.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var ledgerTint: Color {
        switch icon {
        case .cloud:
            return MujiStyle.tea
        case .download, .storage:
            return MujiStyle.indigo
        case .soundQuality:
            return MujiStyle.straw
        default:
            return MujiStyle.clay
        }
    }
}

struct MujiSettingsDivider: View {
    var body: some View {
        MujiListDivider()
            .padding(.leading, 35)
    }
}
