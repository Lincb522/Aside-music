//
//  AppearanceSettingsView.swift
//  Monologue
//
//  外观与歌词设置子页面
//

import SwiftUI

private func appearanceSettingsFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
    if MangaStyle.isActive {
        return MangaStyle.comicFont(size, weight: weight == .regular ? .bold : weight)
    }
    if MujiStyle.isActive {
        return MujiStyle.labelFont(size, weight: weight == .bold ? .semibold : weight)
    }
    return .system(size: size, weight: weight, design: .rounded)
}

struct AppearanceSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isGlobalThemeExpanded = false
    @State private var isAppBrandStyleExpanded = false

    var body: some View {
        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                VStack(spacing: 20) {
                    globalThemeSection
                    appearanceSection
                    lyricSection
                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.isPad ? 32 : 24)
                .iPadContentWidth(700)
            }
            .scrollIndicators(.hidden)
        }
        .themedNavigationChrome(title: String(localized: "settings_navigation_appearance_title"), eyebrow: "STYLE", icon: .sparkle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            settings.enforceCoverBackgroundPolicyForCurrentTheme()
        }
    }

    // MARK: - 外观

    private var appearanceSection: some View {
        SettingsSection(title: String(localized: "settings_appearance")) {
            VStack(spacing: 0) {
                SettingsAppBrandRow(
                    title: String(localized: "settings_app_brand_title"),
                    subtitle: String(localized: "settings_app_brand_desc"),
                    selection: settings.appBrandStyle,
                    appearance: settings.appBrandAppearance,
                    supportsAlternateIcons: settings.supportsAlternateAppIcons,
                    isExpanded: $isAppBrandStyleExpanded,
                    onSelect: { style in
                        Task {
                            await settings.selectAppBrandStyle(style)
                        }
                    },
                    onSelectAppearance: { appearance in
                        Task {
                            await settings.selectAppBrandAppearance(appearance)
                        }
                    }
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .tabBar,
                    title: String(localized: "settings_system_tab_bar"),
                    subtitle: nil,
                    isOn: $settings.useSystemTabBar
                )

                if !settings.useSystemTabBar {
                    Divider()
                        .padding(.leading, 56)

                    SettingsFloatingBarRow(
                        icon: .layers,
                        title: String(localized: "settings_floating_bar"),
                        selection: Binding(
                            get: { settings.floatingBarStyle },
                            set: { settings.floatingBarStyle = $0 }
                        )
                    )
                }

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .hitokoto,
                    title: String(localized: "settings_hitokoto"),
                    subtitle: String(localized: "settings_hitokoto_desc"),
                    isOn: $settings.hitokotoEnabled
                )

                if settings.hitokotoEnabled {
                    Divider()
                        .padding(.leading, 56)

                    SettingsHitokotoTypeRow(
                        icon: .filter,
                        title: String(localized: "settings_hitokoto_type"),
                        selection: $settings.hitokotoType
                    )
                }

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .haptic,
                    title: String(localized: "settings_haptic"),
                    subtitle: String(localized: "settings_haptic_desc"),
                    isOn: $settings.hapticFeedback
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .layers,
                    title: String(localized: "settings_cover_bg_global"),
                    subtitle: String(localized: "settings_cover_bg_global_desc"),
                    isOn: $settings.coverBgGlobal,
                    isEnabled: !settings.locksCoverBackgroundSettings
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .layers,
                    title: String(localized: "settings_cover_bg_playlist"),
                    subtitle: String(localized: "settings_cover_bg_playlist_desc"),
                    isOn: $settings.coverBgPlaylist,
                    isEnabled: !settings.locksCoverBackgroundSettings
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .layers,
                    title: String(localized: "settings_cover_bg_player"),
                    subtitle: String(localized: "settings_cover_bg_player_desc"),
                    isOn: $settings.coverBgPlayer,
                    isEnabled: !settings.locksCoverBackgroundSettings
                )
            }
        }
    }

    // MARK: - 全局主题

    private var globalThemeSection: some View {
        SettingsSection(title: String(localized: "全局主题")) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        isGlobalThemeExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(icon: .playerTheme)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "主题风格"))
                                .font(appearanceSettingsFont(15, weight: .medium))
                                .foregroundColor(.monologueTextPrimary)

                            Text(settings.globalThemeId.displayName)
                                .font(appearanceSettingsFont(11, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        MonologueIcon(icon: .chevronRight, size: 11, color: .monologueTextSecondary.opacity(0.8), lineWidth: 1.7)
                            .rotationEffect(.degrees(isGlobalThemeExpanded ? -90 : 90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                SettingsDisclosureReveal(isExpanded: isGlobalThemeExpanded) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(GlobalThemeId.allCases) { themeId in
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        settings.globalThemeId = themeId
                                    }
                                } label: {
                                    GlobalThemeOptionCard(
                                        themeId: themeId,
                                        isSelected: settings.globalThemeId == themeId
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    // MARK: - 歌词

    private var lyricSection: some View {
        SettingsSection(title: String(localized: "settings_lyrics")) {
            VStack(spacing: 0) {
                lyricColorModeRow

                if settings.lyricColorMode == "solid" {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    lyricColorPickerRow(
                        title: String(localized: "settings_lyric_color"),
                        hex: $settings.lyricSolidColorHex
                    )
                }

                if settings.lyricColorMode == "gradient" {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    lyricColorPickerRow(
                        title: String(localized: "settings_lyric_color_start"),
                        hex: $settings.lyricGradientStartHex
                    )

                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    lyricColorPickerRow(
                        title: String(localized: "settings_lyric_color_end"),
                        hex: $settings.lyricGradientEndHex
                    )
                }

                if settings.lyricColorMode != "default" {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    lyricPreview
                }
            }
        }
    }

    // MARK: - Lyric Helpers

    private var lyricColorModeRow: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: .sparkle)

            Text(String(localized: "settings_lyric_color"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextPrimary)

            Spacer()

            Picker("", selection: $settings.lyricColorMode) {
                Text(String(localized: "settings_lyric_color_mode_default")).tag("default")
                Text(String(localized: "settings_lyric_color_mode_solid")).tag("solid")
                Text(String(localized: "settings_lyric_color_mode_gradient")).tag("gradient")
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func lyricColorPickerRow(title: String, hex: Binding<String>) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: hex.wrappedValue))
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.monologueSeparator, lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextPrimary)

            Spacer()

            ColorPicker("", selection: Binding(
                get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.toHex() }
            ), supportsOpacity: false)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var lyricPreview: some View {
        VStack(spacing: 8) {
            if settings.lyricColorMode == "gradient" {
                Text(String(localized: "settings_lyric_preview"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: settings.lyricGradientStartHex),
                                Color(hex: settings.lyricGradientEndHex)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else if settings.lyricColorMode == "solid" {
                Text(String(localized: "settings_lyric_preview"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: settings.lyricSolidColorHex))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

private struct SettingsAppBrandRow: View {
    let title: String
    let subtitle: String
    let selection: AppBrandStyle
    let appearance: AppBrandAppearance
    let supportsAlternateIcons: Bool
    @Binding var isExpanded: Bool
    let onSelect: (AppBrandStyle) -> Void
    let onSelectAppearance: (AppBrandAppearance) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(icon: .sparkle)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(appearanceSettingsFont(15, weight: .medium))
                            .foregroundColor(.monologueTextPrimary)

                        Text("\(selection.displayName) · \(appearance.displayName)")
                            .font(appearanceSettingsFont(11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    MonologueIcon(icon: .chevronRight, size: 11, color: .monologueTextSecondary.opacity(0.8), lineWidth: 1.7)
                        .rotationEffect(.degrees(isExpanded ? -90 : 90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            SettingsDisclosureReveal(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(AppBrandStyle.allCases) { style in
                            Button {
                                onSelect(style)
                            } label: {
                                AppBrandOptionCard(
                                    style: style,
                                    appearance: appearance,
                                    isSelected: selection == style
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(AppBrandAppearance.allCases) { item in
                            Button {
                                onSelectAppearance(item)
                            } label: {
                                Text(item.displayName)
                                    .font(appearanceSettingsFont(12, weight: appearance == item ? .semibold : .regular))
                                    .foregroundStyle(appearance == item ? Color.monologueIconForeground : Color.monologueTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(appearance == item ? Color.monologueIconBackground : Color.monologueSeparator.opacity(0.42))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !supportsAlternateIcons {
                        Text(String(localized: "settings_app_brand_device_hint"))
                            .font(appearanceSettingsFont(11, weight: .regular))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct SettingsDisclosureReveal<Content: View>: View {
    let isExpanded: Bool
    let content: Content
    @State private var measuredHeight: CGFloat = 0

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SettingsDisclosureHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .onPreferenceChange(SettingsDisclosureHeightPreferenceKey.self) { height in
                if height > 0 {
                    measuredHeight = height
                }
            }
            .frame(height: isExpanded ? measuredHeight : 0, alignment: .top)
            .opacity(isExpanded ? 1 : 0.001)
            .clipped()
            .compositingGroup()
            .allowsHitTesting(isExpanded)
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isExpanded)
    }
}

private struct SettingsDisclosureHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct AppBrandOptionCard: View {
    let style: AppBrandStyle
    let appearance: AppBrandAppearance
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(previewBackground)
                .frame(height: 94)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(previewStrokeColor, lineWidth: 1)
                }
                .overlay {
                    Image(style.previewAssetName(for: appearance))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(appearance == .dark ? 0.26 : 0.12), radius: 10, x: 0, y: 4)
                }

            if isSelected {
                Circle()
                    .fill(Color.monologueAccent)
                    .frame(width: 20, height: 20)
                    .overlay(MonologueIcon(icon: .checkmark, size: 11, color: .white, lineWidth: 2.1))
                    .padding(7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.monologueIconBackground.opacity(0.14) : Color.monologueSeparator.opacity(0.38))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.monologueAccent.opacity(0.4) : Color.clear, lineWidth: 1.2)
        }
    }

    private var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: style.previewBackgroundColor(for: appearance)),
                Color(hex: style.previewBackgroundColor(for: appearance)).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var previewStrokeColor: Color {
        appearance == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.42)
    }
}
