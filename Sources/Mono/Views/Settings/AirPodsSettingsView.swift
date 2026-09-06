import SwiftUI
import UIKit

@MainActor
struct AirPodsSettingsView: View {
    private let isEmbedded: Bool
    @ObservedObject private var airPods = AirPodsExperienceManager.shared
    @ObservedObject private var suite = MonoNextSuiteManager.shared
    @ObservedObject private var player = CurrentSongPresentationModel.shared
    @StateObject private var coverColors = CoverColorExtractor()
    @Environment(\.monoSoundCenterLayout) private var centerLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
    }

    private var accent: Color {
        normalizedAirPodsAccent(coverColors.dominantColor)
    }

    private var accentForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: accent,
            light: Color(hex: "111318"),
            dark: .white
        )
    }

    var body: some View {
        presentationRoot
            .onAppear {
                airPods.activateRuntimeIfNeeded()
                refreshAccent()
            }
            .onChange(of: player.currentSong?.id) { _, _ in
                refreshAccent()
            }
    }

    private var presentationRoot: AnyView {
        if isEmbedded {
            return AnyView(
                workspace
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .compatFontDesign(nil)
                    .environment(\.colorScheme, .dark)
            )
        }
        return AnyView(MonoAudioCenterView(initialWorkspace: .output))
    }

    private var workspace: some View {
        ScrollView {
            LazyVStack(spacing: centerLayout.isCompactHeight ? 12 : 16) {
                connectionStrip
                modelSection
                aiTuningSection
                profileSection
                behaviorSection
                spatialActions
                FloatingBarBottomSpacer()
            }
            .padding(.horizontal, centerLayout.horizontalInset)
            .padding(.top, centerLayout.isCompactHeight ? 3 : 7)
            .padding(.bottom, 28)
            .frame(maxWidth: centerLayout.workspaceMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var connectionStrip: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(airPods.connection.isConnected ? 0.18 : 0.08))
                MonoIcon(
                    icon: .headphones,
                    size: 23,
                    color: airPods.connection.isConnected ? accent : .white.opacity(0.42)
                )
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(airPods.connectionTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(airPods.selectedDeviceModel.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
            }

            Spacer(minLength: 4)

            Text(
                airPods.connection.isConnected
                    ? String(localized: "airpods_connected")
                    : String(localized: "airpods_unavailable")
            )
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(airPods.connection.isConnected ? accent : .white.opacity(0.42))
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Capsule().fill(Color.white.opacity(0.06)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(panelBackground)
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "airpods_model_section"))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(AirPodsDeviceModel.allCases) { model in
                    modelButton(model)
                }
            }

            Text(String(localized: "airpods_model_manual_hint"))
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.44))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private func modelButton(_ model: AirPodsDeviceModel) -> some View {
        let selected = airPods.selectedDeviceModel == model
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                airPods.selectDeviceModel(model)
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.title)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(selected ? accentForeground : .white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(model.subtitle)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(selected ? accentForeground.opacity(0.68) : .white.opacity(0.40))
                        .lineLimit(1)
                }

                Spacer(minLength: 3)

                if selected {
                    MonoIcon(icon: .checkmark, size: 12, color: accentForeground)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? accent.opacity(0.92) : Color.white.opacity(0.055))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var aiTuningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "airpods_ai_section"))
            soundToggleRow(
                icon: .sparkle,
                title: String(localized: "airpods_ai_model_tuning"),
                subtitle: String(
                    format: String(localized: "airpods_ai_model_tuning_desc"),
                    airPods.selectedDeviceModel.title
                ),
                isOn: Binding(
                    get: { airPods.modelAwareAITuningEnabled },
                    set: { airPods.setModelAwareAITuningEnabled($0) }
                )
            )
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "airpods_profile_section"))

            HStack(spacing: 7) {
                ForEach(AirPodsListeningProfile.allCases) { profile in
                    let selected = airPods.selectedProfile == profile
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                            airPods.selectProfile(profile)
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 4) {
                            Text(profile.title)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(selected ? accentForeground : .white.opacity(0.78))
                            Text(profile.subtitle)
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundStyle(selected ? accentForeground.opacity(0.64) : .white.opacity(0.38))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 5)
                        .frame(maxWidth: .infinity, minHeight: 67)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? accent.opacity(0.92) : Color.white.opacity(0.055))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!airPods.isEnabled)
                    .opacity(airPods.isEnabled ? 1 : 0.4)
                }
            }
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "airpods_experience_section"))
            VStack(spacing: 0) {
                soundToggleRow(
                    icon: .headphones,
                    title: String(localized: "airpods_experience_enable"),
                    subtitle: String(localized: "airpods_experience_enable_desc"),
                    isOn: Binding(
                        get: { airPods.isEnabled },
                        set: { airPods.setEnabled($0) }
                    )
                )
                panelDivider
                soundToggleRow(
                    icon: .refresh,
                    title: String(localized: "airpods_auto_apply"),
                    subtitle: String(localized: "airpods_auto_apply_desc"),
                    isOn: Binding(
                        get: { airPods.autoApplyOnConnect },
                        set: { airPods.setAutoApplyOnConnect($0) }
                    ),
                    isEnabled: airPods.isEnabled
                )
                panelDivider
                soundToggleRow(
                    icon: .waveform,
                    title: String(localized: "airpods_motion_adaptation"),
                    subtitle: motionAdaptationSubtitle,
                    isOn: Binding(
                        get: { airPods.adaptsToMotion },
                        set: { airPods.setAdaptsToMotion($0) }
                    ),
                    isEnabled: airPods.isEnabled && airPods.supportsAdaptiveMotion
                )
            }
            .background(panelBackground)
        }
    }

    private var spatialActions: some View {
        HStack(spacing: 8) {
            actionButton(
                title: String(localized: "airpods_apply_now"),
                icon: .playCircle,
                enabled: airPods.isEnabled && airPods.connection.isConnected
            ) {
                airPods.applyNow()
            }
            actionButton(
                title: String(localized: "airpods_recenter"),
                icon: .immersive,
                enabled: suite.isHeadTrackingAvailable
            ) {
                airPods.recenterHeadTracking()
            }
        }
    }

    private func soundToggleRow(
        icon: MonoIcon.IconType,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) -> some View {
        HStack(spacing: 11) {
            MonoIcon(icon: icon, size: 17, color: isEnabled ? accent : .white.opacity(0.28))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.90 : 0.38))
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.44 : 0.24))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent)
                .scaleEffect(0.82)
                .frame(width: 42)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(panelBackground)
        .opacity(isEnabled ? 1 : 0.64)
    }

    private func actionButton(
        title: String,
        icon: MonoIcon.IconType,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                MonoIcon(icon: icon, size: 14, color: enabled ? accent : .white.opacity(0.28))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(enabled ? 0.82 : 0.3))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(panelBackground)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.52))
            .padding(.horizontal, 2)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.black.opacity(0.24))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            }
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.065))
            .frame(height: 1)
            .padding(.leading, 48)
    }

    private var motionAdaptationSubtitle: String {
        guard #available(iOS 18.0, *) else {
            return String(localized: "airpods_motion_requires_ios18")
        }
        if airPods.supportsAdaptiveMotion {
            return String(
                format: String(localized: "airpods_motion_state_format"),
                airPods.motionState.title
            )
        }
        return String(localized: "airpods_motion_unavailable_desc")
    }

    private func refreshAccent() {
        coverColors.extract(from: player.currentSong?.coverUrl?.sized(220).absoluteString)
    }
}

private func normalizedAirPodsAccent(_ color: Color) -> Color {
    let uiColor = UIColor(color)
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 1
    guard uiColor.getHue(
        &hue,
        saturation: &saturation,
        brightness: &brightness,
        alpha: &alpha
    ) else {
        return Color(red: 0.48, green: 0.7, blue: 1)
    }
    return Color(
        hue: Double(hue),
        saturation: Double(saturation < 0.08 ? 0.18 : min(0.74, saturation)),
        brightness: Double(max(0.82, brightness)),
        opacity: Double(alpha)
    )
}
