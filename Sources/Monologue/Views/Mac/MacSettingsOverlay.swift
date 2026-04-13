#if os(macOS)
import SwiftUI

struct MacSettingsOverlay: View {
    @Binding var isPresented: Bool
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var cacheSize: String = "..."

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                settingsHeader
                settingsContent
            }
            .frame(width: 360)
            .background(
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: -5)
            )
        }
        .onAppear { updateCacheSize() }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack {
            Text(String(localized: "settings_title"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: { withAnimation { isPresented = false } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Content

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                macSettingsSection(title: String(localized: "settings_appearance")) {
                    macSettingRow(icon: "paintbrush.fill", title: String(localized: "settings_theme_mode")) {
                        Picker("", selection: $settings.themeMode) {
                            Text(String(localized: "theme_system")).tag("system")
                            Text(String(localized: "theme_light")).tag("light")
                            Text(String(localized: "theme_dark")).tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }

                macSettingsSection(title: String(localized: "settings_playback")) {
                    macSettingToggle(icon: "play.circle", title: String(localized: "settings_auto_play"), isOn: $settings.autoPlayNext)
                    macSettingToggle(icon: "lock.open.fill", title: String(localized: "settings_unblock"), isOn: $settings.unblockEnabled)
                    macSettingToggle(icon: "square.and.arrow.down", title: String(localized: "settings_listen_and_save"), isOn: $settings.listenAndSave)
                }

                macSettingsSection(title: String(localized: "settings_cache")) {
                    macSettingRow(icon: "internaldrive", title: String(localized: "settings_cache_size")) {
                        Text(cacheSize)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Button(action: clearCache) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text(String(localized: "settings_clear_cache"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                macSettingsSection(title: String(localized: "settings_other")) {
                    macSettingToggle(icon: "quote.opening", title: String(localized: "settings_hitokoto"), isOn: $settings.hitokotoEnabled)
                    macSettingToggle(icon: "hand.tap", title: String(localized: "settings_haptic"), isOn: $settings.hapticFeedback)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Components

    private func macSettingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.tertiary)
                .tracking(0.8)

            VStack(spacing: 2) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.6))
            )
        }
    }

    private func macSettingRow(icon: String, title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            trailing()
        }
        .padding(.vertical, 4)
    }

    private func macSettingToggle(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        macSettingRow(icon: icon, title: title) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.accentColor)
        }
    }

    private func updateCacheSize() {
        Task { @MainActor in
            let fm = FileManager.default
            var total: Int64 = 0
            if let cacheBase = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let cacheDir = cacheBase.appendingPathComponent("MonologueCache")
                if let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: .skipsHiddenFiles) {
                    for f in files {
                        if let values = try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey]) {
                            total += Int64(values.totalFileAllocatedSize ?? 0)
                        }
                    }
                }
            }
            cacheSize = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        }
    }

    private func clearCache() {
        OptimizedCacheManager.shared.clearAll()
        updateCacheSize()
    }
}
#endif
