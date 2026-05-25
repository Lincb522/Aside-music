import SwiftUI

struct QishuiQualityPickerSheet: View {
    let currentQuality: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    private static let qualities: [(key: String, name: String, subtitle: String, badge: String?)] = [
        ("lossless", "无损", "FLAC · ~820kbps", SoundQuality.lossless.badgeText),
        ("spatial", "空间音频", "AAC · ~324kbps", SoundQuality.sky.badgeText),
        ("hi_res", "高解析度", "AAC · ~320kbps", SoundQuality.hires.badgeText),
        ("highest", "超清", "AAC · ~260kbps", SoundQuality.exhigh.badgeText),
        ("higher", "较高", "AAC · ~132kbps", SoundQuality.higher.badgeText),
        ("medium", "标准", "AAC · ~64kbps", SoundQuality.standard.badgeText),
    ]

    static func displayName(for quality: String) -> String {
        qualities.first { $0.key == quality }?.name ?? quality
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 20) {
            HStack {
                Text("QSM 音质")
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(20, weight: .semibold) : .system(size: 20, weight: .bold, design: .rounded)))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))

                PlatformBadgeLabel(text: "QSM", source: .qishui)

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 14, color: SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)
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
                                    HStack(spacing: 6) {
                                        Text(item.name)
                                            .font(SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)

                                        if let badge = item.badge {
                                            Text(badge)
                                                .font(qualityBadgeFont)
                                                .foregroundColor(qualityBadgeForeground)
                                                .tracking(MujiStyle.isActive ? 0.5 : 0)
                                                .padding(.horizontal, qualityBadgeHorizontalPadding)
                                                .padding(.vertical, qualityBadgeVerticalPadding)
                                                .background {
                                                    qualityBadgeBackground
                                                }
                                                .overlay {
                                                    qualityBadgeStroke
                                                }
                                        }
                                    }

                                    Text(item.subtitle)
                                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)
                                }

                                Spacer()

                                if currentQuality == item.key {
                                    MonologueIcon(icon: .checkmark, size: 14, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.accent : .monologueTextPrimary))
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
            .themeRenderScrollLayer()
        }
    }

    private var qualityPanelCornerRadius: CGFloat {
        if SequoiaStyle.isActive { return 22 }
        return NeumorphicStyle.isActive ? 22 : 16
    }

    private var selectedIconColor: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueIconForeground
    }

    private var defaultIconColor: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
    }

    private var qualityBadgeFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(9, weight: .semibold) }
        return .system(size: 9, weight: .semibold, design: .rounded)
    }

    private var qualityBadgeForeground: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return .monologueTextPrimary.opacity(0.72)
    }

    private var qualityBadgeHorizontalPadding: CGFloat {
        MujiStyle.isActive ? 6 : 5
    }

    private var qualityBadgeVerticalPadding: CGFloat {
        MujiStyle.isActive ? 2.5 : 2
    }

    @ViewBuilder
    private var qualityBadgeBackground: some View {
        if SequoiaStyle.isActive {
            Capsule().fill(SequoiaStyle.accent.opacity(0.12))
        } else if NeumorphicStyle.isActive {
            Capsule().fill(NeumorphicStyle.accent.opacity(colorScheme == .dark ? 0.16 : 0.1))
        } else {
            Capsule().fill(Color.monologueSeparator.opacity(0.55))
        }
    }

    @ViewBuilder
    private var qualityBadgeStroke: some View {
        if SequoiaStyle.isActive {
            Capsule().stroke(SequoiaStyle.accent.opacity(0.22), lineWidth: 0.7)
        } else if NeumorphicStyle.isActive {
            Capsule().stroke(NeumorphicStyle.accent.opacity(0.16), lineWidth: 0.6)
        } else {
            Capsule().stroke(Color.monologueTextSecondary.opacity(0.08), lineWidth: 0.6)
        }
    }

    @ViewBuilder
    private var qualityPanelBackground: some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: qualityPanelCornerRadius, elevated: false)
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: qualityPanelCornerRadius, elevated: true, role: .chrome)
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
            NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, lightweight: true)
                .clipShape(Circle())
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, role: .list)
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
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: 10,
                elevated: isSelected,
                pressed: !isSelected,
                fill: isSelected ? SequoiaStyle.accent.opacity(0.13) : SequoiaStyle.materialList,
                role: isSelected ? .selected : .list
            )
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.monologueIconBackground : Color.monologueIconBackground.opacity(0.08))
        }
    }
}
