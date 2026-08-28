import SwiftUI

// MARK: - 主题选择行

struct SettingsThemeRow: View {
    let icon: MonoIcon.IconType
    let title: String
    @Binding var selection: String
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 14) {
                    SettingsIconBadge(icon: summaryIcon)

                    Text(title)
                        .font(themedSettingsFont(16, weight: .medium))
                        .foregroundColor(themedSettingsPrimaryColor())

                    Spacer(minLength: 12)

                    Text(summaryText)
                        .font(themedSettingsFont(14, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)
                        .foregroundColor(themedSettingsSecondaryColor())

                    PetWhiteDisclosureChevron(
                        isExpanded: isExpanded,
                        size: 11,
                        color: themedSettingsSecondaryColor(),
                        lineWidth: 1.7
                    )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            SettingsHeaderReveal(isExpanded: isExpanded) {
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    themeModeOptionRow(
                        value: "system",
                        icon: .sparkle,
                        title: String(localized: "settings_theme_auto")
                    )

                    Divider()
                        .opacity(0.28)
                        .padding(.leading, 62)

                    themeModeOptionRow(
                        value: "light",
                        icon: .sun,
                        title: String(localized: "settings_theme_light")
                    )

                    Divider()
                        .opacity(0.28)
                        .padding(.leading, 62)

                    themeModeOptionRow(
                        value: "dark",
                        icon: .moon,
                        title: String(localized: "settings_theme_dark")
                    )
                }
            }
        }
    }

    private var summaryText: String {
        switch selection {
        case "light":
            return String(localized: "settings_theme_light")
        case "dark":
            return String(localized: "settings_theme_dark")
        default:
            return String(localized: "settings_theme_auto")
        }
    }

    private var summaryIcon: MonoIcon.IconType {
        switch selection {
        case "light":
            return .sun
        case "dark":
            return .moon
        default:
            return icon
        }
    }

    private func themeModeOptionRow(value: String, icon: MonoIcon.IconType, title: String) -> some View {
        let isSelected = selection == value

        return Button {
            selection = value
            isExpanded = false
        } label: {
            HStack(spacing: 14) {
                SettingsIconBadge(icon: icon)

                Text(title)
                    .font(themedSettingsFont(15, weight: .medium))
                    .foregroundColor(themedSettingsPrimaryColor())

                Spacer()

                if isSelected {
                    MonoIcon(icon: .checkmark, size: 16, color: themedSettingsPrimaryColor(), lineWidth: 1.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
