import SwiftUI

struct QishuiQualityPickerSheet: View {
    let currentQuality: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @Environment(\.colorScheme) private var colorScheme

    private static let qualities: [(key: String, name: String, subtitle: String)] = [
        ("lossless", "无损", "FLAC · ~820kbps"),
        ("spatial", "空间音频", "AAC · ~324kbps"),
        ("hi_res", "高解析度", "AAC · ~320kbps"),
        ("highest", "超清", "AAC · ~260kbps"),
        ("higher", "较高", "AAC · ~132kbps"),
        ("medium", "标准", "AAC · ~64kbps"),
    ]

    static func displayName(for quality: String) -> String {
        qualities.first { $0.key == quality }?.name ?? quality
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("QSM 音质")
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)

                PlatformBadgeLabel(text: "QSM", source: .qishui)

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 14, color: .monologueTextSecondary)
                        .padding(10)
                        .background { closeButtonBackground }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(Self.qualities.enumerated()), id: \.element.key) { index, item in
                        Button(action: { onSelect(item.key) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.clear)
                                        .frame(width: 32, height: 32)
                                        .background {
                                            qualityIconTileBackground(isSelected: currentQuality == item.key)
                                        }

                                    MonologueIcon(icon: .soundQuality, size: 16, color: currentQuality == item.key ? selectedIconColor : defaultIconColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.monologueTextPrimary)

                                    Text(item.subtitle)
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(.monologueTextSecondary)
                                }

                                Spacer()

                                if currentQuality == item.key {
                                    MonologueIcon(icon: .checkmark, size: 14, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextPrimary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if index < Self.qualities.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(
                    qualityPanelBackground
                )
                .clipShape(RoundedRectangle(cornerRadius: qualityPanelCornerRadius, style: .continuous))
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 20)
                .iPadContentWidth(500)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var qualityPanelCornerRadius: CGFloat {
        NeumorphicStyle.isActive ? 22 : 16
    }

    private var selectedIconColor: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueIconForeground
    }

    private var defaultIconColor: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
    }

    @ViewBuilder
    private var qualityPanelBackground: some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: qualityPanelCornerRadius, elevated: false)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private var closeButtonBackground: some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.monologueSeparator)
                .monologueGlassCircle()
        }
    }

    @ViewBuilder
    private func qualityIconTileBackground(isSelected: Bool) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 10,
                elevated: false,
                pressed: isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(colorScheme == .dark ? 0.2 : 0.16) : NeumorphicStyle.surfacePressed.opacity(0.72)
            )
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.monologueIconBackground : Color.monologueIconBackground.opacity(0.08))
        }
    }
}
