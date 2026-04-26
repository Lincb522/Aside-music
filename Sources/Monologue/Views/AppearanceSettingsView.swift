//
//  AppearanceSettingsView.swift
//  Monologue
//
//  外观与歌词设置子页面
//

import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    globalThemeSection
                    appearanceSection
                    lyricSection
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, DeviceLayout.isPad ? 32 : 24)
                .iPadContentWidth(700)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(String(localized: "settings_navigation_appearance_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
                    onSelect: { style in
                        Task {
                            await settings.selectAppBrandStyle(style)
                        }
                    }
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsAppBrandAppearanceRow(
                    title: String(localized: "settings_app_brand_appearance_title"),
                    subtitle: String(localized: "settings_app_brand_appearance_desc"),
                    selection: settings.appBrandAppearance,
                    onSelect: { appearance in
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
                    isOn: $settings.coverBgGlobal
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .layers,
                    title: String(localized: "settings_cover_bg_playlist"),
                    subtitle: String(localized: "settings_cover_bg_playlist_desc"),
                    isOn: $settings.coverBgPlaylist
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .layers,
                    title: String(localized: "settings_cover_bg_player"),
                    subtitle: String(localized: "settings_cover_bg_player_desc"),
                    isOn: $settings.coverBgPlayer
                )
            }
        }
    }

    // MARK: - 全局主题

    private var globalThemeSection: some View {
        SettingsSection(title: String(localized: "全局主题")) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        SettingsIconBadge(icon: .playerTheme)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "主题风格"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)

                            Text(String(localized: "切换整个 App 的视觉风格与布局"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }

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
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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
    let onSelect: (AppBrandStyle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SettingsIconBadge(icon: .sparkle)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

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

            if !supportsAlternateIcons {
                Text(String(localized: "settings_app_brand_device_hint"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SettingsAppBrandAppearanceRow: View {
    let title: String
    let subtitle: String
    let selection: AppBrandAppearance
    let onSelect: (AppBrandAppearance) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SettingsIconBadge(icon: .playerTheme)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                ForEach(AppBrandAppearance.allCases) { appearance in
                    Button {
                        onSelect(appearance)
                    } label: {
                        AppBrandAppearanceCard(
                            appearance: appearance,
                            isSelected: selection == appearance
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct AppBrandOptionCard: View {
    let style: AppBrandStyle
    let appearance: AppBrandAppearance
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(previewBackground)
                    .frame(height: 92)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(previewStrokeColor, lineWidth: 1)
                    }
                    .overlay {
                        Image(style.previewAssetName(for: appearance))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(appearance == .dark ? 0.26 : 0.12), radius: 10, x: 0, y: 4)
                    }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white, Color.monologueAccent)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(style.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Text(style.detailText)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
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

private struct AppBrandAppearanceCard: View {
    let appearance: AppBrandAppearance
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: appearance == .light ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(appearance == .light ? Color.orange : Color(hex: "8BA7FF"))

                Text(appearance.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()
            }

            Text(appearance.detailText)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.monologueIconBackground.opacity(0.14) : Color.monologueSeparator.opacity(0.38))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.monologueAccent.opacity(0.4) : Color.clear, lineWidth: 1.2)
        }
    }
}
