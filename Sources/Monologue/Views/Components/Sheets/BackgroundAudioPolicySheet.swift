//  后台播放模式选择：独占 / 自动 / 始终混音。
//  每个模式给出行为细则（锁屏控制、混音、打断行为），替代原来的系统 confirmationDialog。

import SwiftUI

struct BackgroundAudioPolicySheet: View {
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 16) {
            header
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 6)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(BackgroundAudioPolicy.allCases) { policy in
                        policyCard(policy)
                    }

                    footnote
                        .padding(.top, 4)
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 20)
                .iPadContentWidth(500)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    // MARK: - 头部

    private var headerInk: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var headerInkSoft: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var accent: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if MujiStyle.isActive { return MujiStyle.clay }
        return .monologueAccent
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey("settings_background_audio_policy"))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(21, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(21, weight: .semibold) : .system(size: 21, weight: .heavy, design: .rounded)))
                    .foregroundColor(headerInk)

                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)

                    Text(String(localized: "quality_current_prefix"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(headerInkSoft.opacity(0.85))

                    Text(settings.backgroundAudioPolicy.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(headerInk.opacity(0.9))
                }
            }

            Spacer(minLength: 0)

            Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                MonologueIcon(icon: .close, size: 14, color: SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)
                    .padding(10)
                    .background { closeButtonBackground }
            }
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

    // MARK: - 模式卡

    private func policyCard(_ policy: BackgroundAudioPolicy) -> some View {
        let isSelected = settings.backgroundAudioPolicy == policy

        return Button {
            guard settings.backgroundAudioPolicy != policy else { return }
            settings.backgroundAudioPolicy = policy
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 12) {
                    // 模式字标
                    ZStack {
                        tileBackground(isSelected: isSelected)

                        Text(policy.sheetBadge)
                            .font(.system(size: policy.sheetBadge.count > 1 ? 10 : 15, weight: .heavy, design: .rounded))
                            .tracking(policy.sheetBadge.count > 1 ? 0.4 : 0)
                            .foregroundColor(tileInk(isSelected: isSelected))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 3)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(policy.displayName)
                                .font(SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15.5, weight: .semibold) : .system(size: 15.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                                .foregroundColor(headerInk)

                            if policy == .automatic {
                                Text(String(localized: "bg_policy_recommended"))
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(accent)
                                    .padding(.horizontal, 5.5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(accent.opacity(0.12))
                                    )
                            }
                        }

                        Text(policy.detailText)
                            .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(headerInkSoft)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    // 单选圈
                    Circle()
                        .stroke(
                            isSelected ? accent : Color.monologueSeparator.opacity(0.9),
                            lineWidth: isSelected ? 5.5 : 1.4
                        )
                        .frame(width: isSelected ? 14.5 : 19, height: isSelected ? 14.5 : 19)
                        .frame(width: 20, height: 20)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
                }

                // 行为细则
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(policy.sheetTraits.enumerated()), id: \.offset) { _, trait in
                        HStack(alignment: .top, spacing: 7) {
                            Capsule()
                                .fill(isSelected ? accent.opacity(0.75) : headerInkSoft.opacity(0.4))
                                .frame(width: 3, height: 3)
                                .padding(.top, 5.5)

                            Text(trait)
                                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                                .foregroundColor(headerInkSoft.opacity(0.92))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 52)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(cardBackground(isSelected: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985))
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isSelected)
    }

    // MARK: - 背景

    private var panelCornerRadius: CGFloat {
        if SequoiaStyle.isActive { return 22 }
        return NeumorphicStyle.isActive ? 22 : 16
    }

    @ViewBuilder
    private func cardBackground(isSelected: Bool) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: panelCornerRadius,
                elevated: !isSelected,
                pressed: isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(0.10) : nil
            )
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: panelCornerRadius,
                elevated: isSelected,
                fill: isSelected ? SequoiaStyle.accent.opacity(0.10) : SequoiaStyle.materialList,
                role: isSelected ? .selected : .list
            )
        } else {
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .fill(isSelected ? accent.opacity(0.055) : Color.monologueGlassTint)
                .monologueGlass(cornerRadius: panelCornerRadius + 4)
                .overlay(
                    RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                        .stroke(
                            isSelected ? accent.opacity(0.42) : Color.monologueSeparator.opacity(0.4),
                            lineWidth: isSelected ? 1.1 : 0.6
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func tileBackground(isSelected: Bool) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 11,
                elevated: false,
                pressed: isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(0.18) : NeumorphicStyle.surfacePressed.opacity(0.72)
            )
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: 11,
                elevated: isSelected,
                pressed: !isSelected,
                fill: isSelected ? SequoiaStyle.accent.opacity(0.13) : SequoiaStyle.materialList,
                role: isSelected ? .selected : .list
            )
        } else {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? Color.monologueIconBackground : Color.monologueIconBackground.opacity(0.08))
        }
    }

    private func tileInk(isSelected: Bool) -> Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.ink : MangaStyle.inkSub }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.ink }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.accent : SequoiaStyle.inkSoft }
        return isSelected ? .monologueIconForeground : .monologueTextPrimary
    }

    // MARK: - 脚注

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.monologueSeparator.opacity(0.5))
                .frame(height: 0.5)

            Text(String(localized: "bg_policy_sheet_footnote"))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(headerInkSoft.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - 模式展示信息

private extension BackgroundAudioPolicy {
    /// 模式字标（中文单字 / 英文缩写）
    var sheetBadge: String {
        switch self {
        case .exclusive:
            return String(localized: "bg_policy_badge_exclusive")
        case .automatic:
            return String(localized: "bg_policy_badge_automatic")
        case .alwaysMix:
            return String(localized: "bg_policy_badge_always_mix")
        }
    }

    /// 行为细则（每个模式三条）
    var sheetTraits: [String] {
        switch self {
        case .exclusive:
            return [
                String(localized: "bg_policy_trait_exclusive_1"),
                String(localized: "bg_policy_trait_exclusive_2"),
                String(localized: "bg_policy_trait_exclusive_3"),
            ]
        case .automatic:
            return [
                String(localized: "bg_policy_trait_automatic_1"),
                String(localized: "bg_policy_trait_automatic_2"),
                String(localized: "bg_policy_trait_automatic_3"),
            ]
        case .alwaysMix:
            return [
                String(localized: "bg_policy_trait_always_mix_1"),
                String(localized: "bg_policy_trait_always_mix_2"),
                String(localized: "bg_policy_trait_always_mix_3"),
            ]
        }
    }
}
