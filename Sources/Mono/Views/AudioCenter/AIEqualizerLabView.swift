import SwiftUI
import FFmpegSwiftSDK

@MainActor
struct AIEqualizerLabView: View {
    private let isEmbedded: Bool
    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var agent = AIEqualizerAgent.shared
    @StateObject private var eqManager = EQManager.shared
    @StateObject private var coverColors = CoverColorExtractor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.monoSoundCenterLayout) private var centerLayout
    @Namespace private var controlSelectionNamespace
    @State private var expandedMeasurementGroups: Set<AIEqualizerMeasurementGroup> = []
    @State private var isProposalParameterExpanded = false
    @State private var isCalibrationExpanded = false
    @State private var isTuningConfigurationExpanded = false
    @State private var isShowingClearLearningConfirmation = false
    @State private var isShowingClearAllProposalsConfirmation = false
    @State private var comparisonProposal: AIEqualizerSavedProposal?
    @State private var selectedWorkspace: AIEqualizerWorkspace = .tuning

    init(isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
    }

    private var accent: Color { normalizedAIEqualizerAccent(coverColors.dominantColor) }
    private var accentForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: accent,
            light: Color(hex: "111821"),
            dark: .white
        )
    }

    private var currentOutputIdentity: String {
        eqManager.currentOutputName.isEmpty
            ? eqManager.currentOutputKind.rawValue
            : "\(eqManager.currentOutputKind.rawValue):\(eqManager.currentOutputName)"
    }

    var body: some View {
        presentationRoot
        .monoSheet(item: $comparisonProposal, preset: .detail) { historical in
            NavigationStack {
                AIEqualizerProposalComparisonRedesignView(
                    current: agent.proposal,
                    historical: historical,
                    accent: accent
                )
            }
        }
        .alert(
            String(localized: "ai_learning_clear_title"),
            isPresented: $isShowingClearLearningConfirmation
        ) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(String(localized: "ai_learning_clear_action"), role: .destructive) {
                agent.clearLearningHistory()
            }
        } message: {
            Text(String(localized: "ai_learning_clear_message"))
        }
        .alert(
            String(localized: "ai_lab_clear_all_proposals_title"),
            isPresented: $isShowingClearAllProposalsConfirmation
        ) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(String(localized: "ai_lab_clear_all_proposals"), role: .destructive) {
                agent.deleteAllSavedProposals()
            }
        } message: {
            Text(String(localized: "ai_lab_clear_all_proposals_message"))
        }
        .onAppear { refreshCoverAccent() }
        .onChange(of: player.currentSong?.id) { _, _ in
            refreshCoverAccent()
            selectedWorkspace = .tuning
            expandedMeasurementGroups.removeAll()
            isProposalParameterExpanded = false
            isCalibrationExpanded = false
        }
        .onChange(of: agent.proposal?.id) { _, _ in
            isProposalParameterExpanded = false
            isCalibrationExpanded = false
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: agent.phase.isWorking
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.24),
            value: agent.proposal?.id
        )
    }

    private var presentationRoot: AnyView {
        if isEmbedded {
            return AnyView(
                VStack(spacing: 0) {
                    workspaceSwitcher
                    workspaceContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .compatFontDesign(nil)
                .environment(\.colorScheme, .dark)
            )
        }

        return AnyView(MonoAudioCenterView(initialWorkspace: .ai))
    }

    private var workspaceSwitcher: some View {
        HStack(spacing: 12) {
            ForEach(AIEqualizerWorkspace.allCases) { workspace in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        selectedWorkspace = workspace
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 5) {
                            MonoIcon(
                                icon: workspace.icon,
                                size: centerLayout.isCompactWidth ? 10.5 : 12,
                                color: selectedWorkspace == workspace ? accent : .white.opacity(0.38)
                            )
                            Text(workspace.title)
                                .font(.system(size: centerLayout.isCompactWidth ? 10 : 11.5, weight: .bold))
                                .foregroundStyle(
                                    selectedWorkspace == workspace
                                        ? .white.opacity(0.94)
                                        : .white.opacity(0.46)
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            if workspaceHasContent(workspace) {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 4, height: 4)
                            }
                        }

                        Capsule()
                            .fill(selectedWorkspace == workspace ? accent : .clear)
                            .frame(height: 2)
                            .matchedGeometryEffect(
                                id: "ai-workspace-selection",
                                in: controlSelectionNamespace,
                                isSource: selectedWorkspace == workspace
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: centerLayout.isCompactHeight ? 34 : 40, alignment: .bottom)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedWorkspace == workspace ? .isSelected : [])
            }
        }
        .padding(.horizontal, centerLayout.horizontalInset)
        .padding(.bottom, centerLayout.isCompactHeight ? 7 : 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.065))
                .frame(height: 1)
        }
        .frame(maxWidth: centerLayout.workspaceMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private var workspaceContent: AnyView {
        switch selectedWorkspace {
        case .tuning:
            return tuningWorkspace
        case .measurement:
            return measurementWorkspace
        case .result:
            return resultWorkspace
        case .history:
            return historyWorkspace
        }
    }

    private var tuningWorkspace: AnyView {
        AnyView(
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: centerLayout.isCompactHeight ? 12 : 16) {
                    immersiveTuningStage
                    tuningControlSection
                    analysisNotice
                    serviceFooter
                }
                .padding(.horizontal, centerLayout.horizontalInset)
                .padding(.bottom, centerLayout.isCompactHeight ? 22 : 32)
                .frame(maxWidth: centerLayout.workspaceMaxWidth)
                .frame(maxWidth: .infinity)
            }
        )
    }

    private var measurementWorkspace: AnyView {
        AnyView(
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: centerLayout.isCompactHeight ? 12 : 16) {
                    if let features = agent.measuredFeatures {
                        measurementSection(features)
                    } else {
                        workspaceEmptyState(
                            icon: .waveform,
                            title: String(localized: "ai_lab_measurement_empty")
                        )
                    }
                }
                .padding(.horizontal, centerLayout.horizontalInset)
                .padding(.bottom, centerLayout.isCompactHeight ? 22 : 32)
                .frame(maxWidth: centerLayout.workspaceMaxWidth)
                .frame(maxWidth: .infinity)
            }
        )
    }

    private var resultWorkspace: AnyView {
        AnyView(
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: centerLayout.isCompactHeight ? 12 : 16) {
                    if let proposal = agent.proposal {
                        proposalSection(proposal)
                        if let previous = previousSavedProposal(for: proposal) {
                            automaticComparisonSection(
                                current: proposal,
                                previous: previous.proposal
                            )
                        }
                    } else if case let .failed(message) = agent.phase {
                        failureSection(message)
                    } else {
                        workspaceEmptyState(
                            icon: .sparkle,
                            title: String(localized: "ai_lab_result_empty")
                        )
                    }
                }
                .padding(.horizontal, centerLayout.horizontalInset)
                .padding(.bottom, centerLayout.isCompactHeight ? 22 : 32)
                .frame(maxWidth: centerLayout.workspaceMaxWidth)
                .frame(maxWidth: .infinity)
            }
        )
    }

    private var historyWorkspace: AnyView {
        AnyView(
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: centerLayout.isCompactHeight ? 12 : 16) {
                    if agent.savedProposals.isEmpty {
                        workspaceEmptyState(
                            icon: .history,
                            title: String(localized: "ai_lab_history_empty")
                        )
                    } else {
                        savedResultsSection
                    }

                    if agent.hasAnySavedProposals {
                        clearAllProposalsButton
                    }
                }
                .padding(.horizontal, centerLayout.horizontalInset)
                .padding(.bottom, centerLayout.isCompactHeight ? 22 : 32)
                .frame(maxWidth: centerLayout.workspaceMaxWidth)
                .frame(maxWidth: .infinity)
            }
        )
    }

    private func workspaceHasContent(_ workspace: AIEqualizerWorkspace) -> Bool {
        switch workspace {
        case .tuning: return agent.phase.isWorking
        case .measurement: return agent.measuredFeatures != nil
        case .result: return agent.proposal != nil
        case .history: return !agent.savedProposals.isEmpty
        }
    }

    private var immersiveTuningStage: AnyView {
        AnyView(
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    tuningStageIndicator

                    VStack(alignment: .leading, spacing: 3) {
                        Text(tuningStageTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(tuningStageDetail)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    tuningStageProgress
                }
                .padding(.horizontal, centerLayout.isCompactWidth ? 12 : 16)
                .padding(.top, centerLayout.isCompactHeight ? 12 : 16)

                tuningStageVisualization
                    .frame(height: centerLayout.isCompactHeight ? 132 : 172)
                    .padding(.horizontal, centerLayout.isCompactWidth ? 12 : 16)
                    .padding(.top, centerLayout.isCompactHeight ? 9 : 14)

                if let presentation = processPresentation {
                    AIEqualizerPhaseRail(
                        currentStep: presentation.currentStep,
                        accent: accent
                    )
                    .padding(.horizontal, centerLayout.isCompactWidth ? 12 : 16)
                    .padding(.top, 8)
                    .transition(.opacity)
                }

                divider
                    .padding(.top, 14)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "eq_current_device"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.48))

                        Text(tuningStageSummary)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 8)
                    analysisActionButton
                }
                .padding(centerLayout.isCompactHeight ? 12 : 16)
            }
            .background(tuningStageBackground)
        )
    }

    private var tuningStageVisualization: AnyView {
        if let presentation = processPresentation {
            return AnyView(
                AIEqualizerProcessVisualizer(
                    state: presentation.state,
                    mode: agent.measuredFeatures?.graphicEQMode ?? eqManager.graphicEQMode,
                    accent: accent,
                    measuredBands: agent.measuredFeatures?.bandEnergyDB ?? []
                )
                .accessibilityHidden(true)
            )
        }

        let proposal = agent.proposal
        return AnyView(
            AIEqualizerCurveView(
                gains: proposal?.gains ?? eqManager.customGains,
                mode: proposal?.graphicEQMode ?? eqManager.graphicEQMode,
                accent: accent
            )
            .padding(.vertical, 4)
            .accessibilityHidden(true)
        )
    }

    @ViewBuilder
    private var tuningStageProgress: some View {
        if let startedAt = agent.tuningStartedAt, let presentation = processPresentation {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let progress = presentation.state.progress(at: context.date)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(compactElapsed(since: startedAt, now: context.date))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.46))
                }
            }
        } else if let proposal = agent.proposal {
            Text("\(Int(proposal.confidence * 100))%")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
        }
    }

    private var tuningStageTitle: String {
        processPresentation?.title
            ?? agent.proposal?.profileName
            ?? statusText
    }

    private var tuningStageDetail: String {
        if let proposal = agent.proposal, !agent.phase.isWorking {
            let summary = proposal.profileSpecificSummary.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !summary.isEmpty {
                return summary
            }
            return proposal.graphicEQMode == .thirtyTwoBand
                ? String(localized: "eq_thirty_two_band")
                : String(localized: "eq_ten_band")
        }
        return agent.measuredFeatures?.outputDevice
            ?? EQManager.shared.currentOutputKind.title
    }

    private var tuningStageSummary: String {
        let output = agent.measuredFeatures?.outputDevice
            ?? eqManager.currentOutputKind.title
        let mode = (agent.proposal?.graphicEQMode ?? eqManager.graphicEQMode) == .thirtyTwoBand
            ? String(localized: "eq_thirty_two_band")
            : String(localized: "eq_ten_band")
        return "\(output) · \(mode)"
    }

    @ViewBuilder
    private var tuningStageIndicator: some View {
        if agent.phase.isWorking {
            AIEqualizerActivityDot(accent: accent)
        } else {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .frame(width: 12, height: 12)
        }
    }

    private var tuningStageBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.black.opacity(0.26))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.opacity(0.045))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
    }

    private func workspaceEmptyState(
        icon: MonoIcon.IconType,
        title: String
    ) -> some View {
        VStack(spacing: 12) {
            MonoIcon(
                icon: icon,
                size: 24,
                color: accent
            )
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            )

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(
            maxWidth: .infinity,
            minHeight: centerLayout.isCompactHeight ? 190 : 260
        )
    }

    private var trackCard: some View {
        Group {
            if let song = player.currentSong {
                HStack(spacing: 12) {
                    CachedAsyncImage(url: song.coverUrl?.sized(240), width: 66, height: 66) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(MonoIcon(icon: .musicNote, size: 22, color: .white.opacity(0.45)))
                    }
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                accent.opacity(agent.phase.isWorking ? 0.7 : 0.2),
                                lineWidth: agent.phase.isWorking ? 1.5 : 1
                            )
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(String(localized: "ai_lab_title"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accent)
                            .lineLimit(1)

                        Text(song.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(song.artistName)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 14) {
                    MonoIcon(icon: .musicNote, size: 22, color: .white.opacity(0.42))
                        .frame(width: 56, height: 56)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                    Text(String(localized: "ai_error_no_song"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var analysisActionButton: some View {
        Button(action: primaryAnalysisAction) {
            ZStack {
                Circle().fill(accent.opacity(0.78))

                if let presentation = processPresentation {
                    TimelineView(.periodic(from: .now, by: 0.25)) { context in
                        progressRing(
                            presentation.state.progress(at: context.date)
                        )
                    }
                }

                MonoIcon(
                    icon: agent.phase.isWorking ? .close : .sparkle,
                    size: 16,
                    color: accentForeground
                )
            }
            .frame(width: 48, height: 48)
            .contentShape(Circle())
        }
        .buttonStyle(MonoBouncingButtonStyle())
        .accessibilityLabel(
            agent.phase.isWorking
                ? String(localized: "ai_lab_cancel")
                : String(localized: "ai_lab_analyze")
        )
    }

    private func progressRing(_ progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(accentForeground.opacity(0.18), lineWidth: 1.5)
                .padding(4)
            Circle()
                .trim(from: 0, to: max(0.03, progress))
                .stroke(
                    accentForeground,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(4)
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.16),
                    value: progress
                )
        }
    }

    private var tuningControlSection: AnyView {
        AnyView(
            VStack(spacing: 0) {
                automationToggleRow(
                    title: String(localized: "ai_lab_auto_configure"),
                    isOn: $agent.automaticConfigurationEnabled
                )

                divider

                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                        isTuningConfigurationExpanded.toggle()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(spacing: 12) {
                        Text(String(localized: "ai_tuning_settings"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer(minLength: 8)

                        Text("\(agent.tuningProfile.title) · \(agent.tuningIntensity.title) · \(agent.samplingMode.title)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        MonoIcon(
                            icon: .chevronDown,
                            size: 11,
                            color: isTuningConfigurationExpanded ? accent : .white.opacity(0.38),
                            lineWidth: 1.8
                        )
                        .rotationEffect(.degrees(isTuningConfigurationExpanded ? 180 : 0))
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isTuningConfigurationExpanded {
                    divider

                    automationToggleRow(
                        title: String(localized: "ai_learning_enabled"),
                        isOn: $agent.adaptiveLearningEnabled
                    )

                    if agent.learningEvidenceCount > 0 {
                        divider

                        Button {
                            isShowingClearLearningConfirmation = true
                        } label: {
                            HStack(spacing: 12) {
                                Text(
                                    String(
                                        format: String(localized: "ai_learning_evidence_count"),
                                        agent.learningEvidenceCount
                                    )
                                )
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.68))

                                Spacer(minLength: 8)

                                MonoIcon(icon: .trash, size: 13, color: .white.opacity(0.42))
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 46)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    divider

                    automationToggleRow(
                        title: String(localized: "ai_player_status_toggle"),
                        isOn: $agent.showsPlayerTuningStatus
                    )

                    divider

                    tuningParameterControls
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(cardBackground)
        )
    }

    private var tuningParameterControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "ai_tuning_profile"))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 7) {
                ForEach(AIEqualizerTuningProfile.allCases) { profile in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            agent.selectTuningProfile(profile)
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(profile.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(agent.tuningProfile == profile ? accentForeground : .white.opacity(0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background {
                                if agent.tuningProfile == profile {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(accent.opacity(0.78))
                                        .matchedGeometryEffect(
                                            id: "ai-tuning-profile-selection",
                                            in: controlSelectionNamespace
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.045))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(agent.phase.isWorking)
                }
            }

            divider

            Text(String(localized: "ai_tuning_intensity"))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 7) {
                ForEach(AIEqualizerTuningIntensity.allCases) { intensity in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            agent.tuningIntensity = intensity
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(intensity.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(agent.tuningIntensity == intensity ? accentForeground : .white.opacity(0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background {
                                if agent.tuningIntensity == intensity {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(accent.opacity(0.78))
                                        .matchedGeometryEffect(
                                            id: "ai-tuning-intensity-selection",
                                            in: controlSelectionNamespace
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.045))
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(agent.phase.isWorking)
                }
            }

            divider

            Text(String(localized: "ai_sampling_mode"))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 7) {
                ForEach(AIEqualizerSamplingMode.allCases) { mode in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            agent.samplingMode = mode
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(agent.samplingMode == mode ? accentForeground : .white.opacity(0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background {
                                if agent.samplingMode == mode {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(accent.opacity(0.78))
                                        .matchedGeometryEffect(
                                            id: "ai-sampling-mode-selection",
                                            in: controlSelectionNamespace
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.045))
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(agent.phase.isWorking)
                }
            }

            if agent.samplingMode == .custom {
                HStack(spacing: 12) {
                    Slider(value: $agent.customSamplingDuration, in: 10...120, step: 1)
                        .tint(accent)
                        .disabled(agent.phase.isWorking)

                    Text(String(format: String(localized: "ai_sampling_seconds"), Int(agent.customSamplingDuration)))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 54, alignment: .trailing)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
    }

    private func automationToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 10)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    private var analysisNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            MonoIcon(icon: .infoCircle, size: 14, color: accent)
                .frame(width: 18, height: 18)

            Text(String(localized: "ai_lab_result_notice"))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private func progressSection(
        state: AIEqualizerProcessVisualizer.State,
        title: String,
        currentStep: Int
    ) -> AnyView {
        return erasedSection(
            title: String(localized: "ai_lab_analysis_progress"),
            content: AnyView(
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    AIEqualizerActivityDot(accent: accent)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    if let startedAt = agent.tuningStartedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let progress = state.progress(at: context.date)
                            Text(
                                String(
                                    format: String(localized: "ai_tuning_elapsed_format"),
                                    compactElapsed(since: startedAt, now: context.date)
                                ) + " · \(Int(progress * 100))%"
                            )
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                            .contentTransition(.numericText())
                        }
                    } else {
                        Text("\(Int(state.progress(at: .now) * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }

                AIEqualizerProcessVisualizer(
                    state: state,
                    mode: agent.measuredFeatures?.graphicEQMode ?? eqManager.graphicEQMode,
                    accent: accent,
                    measuredBands: agent.measuredFeatures?.bandEnergyDB ?? []
                )
                .frame(height: 126)
                .accessibilityHidden(true)

                AIEqualizerPhaseRail(
                    currentStep: currentStep,
                    accent: accent
                )
            }
            .padding(16)
            .background(cardBackground)
            )
        )
    }

    private func measurementSection(_ features: AIEqualizerAudioFeatures) -> AnyView {
        erasedSection(
            title: String(localized: "ai_lab_measured_parameters"),
            content: AnyView(
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    SpectrumMeasurementView(
                        values: features.bandEnergyDB,
                        frequencies: features.bandFrequenciesHz,
                        mode: features.graphicEQMode,
                        accent: accent
                    )
                    .frame(height: 156)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        measurementCell(
                            String(localized: "ai_lab_bpm"),
                            bpmText(features.estimatedBPM, confidence: features.tempoConfidence)
                        )
                        measurementCell(
                            String(localized: "ai_lab_key"),
                            keyText(features.estimatedKey, confidence: features.keyConfidence)
                        )
                        measurementCell(
                            String(localized: "ai_lab_integrated_loudness"),
                            String(format: "%.1f LUFS", features.integratedLUFS)
                        )
                        measurementCell(
                            String(localized: "ai_lab_dr_value"),
                            String(format: "DR %.1f", features.dynamicRangeDR)
                        )
                    }
                }
                .padding(14)

                divider.padding(.horizontal, 14)

                erasedMeasurementGroup(
                    .music,
                    content: { AnyView(
                    VStack(alignment: .leading, spacing: 14) {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                            spacing: 8
                        ) {
                            measurementCell(String(localized: "ai_lab_main_melody"), pitchText(features.dominantPitchHz))
                            measurementCell(
                                String(localized: "ai_lab_melody_range"),
                                String(format: String(localized: "ai_lab_semitones_format"), features.melodyRangeSemitones)
                            )
                            measurementCell(String(localized: "ai_lab_melodic_activity"), "\(Int(features.melodicActivity * 100))%")
                            measurementCell(
                                String(localized: "ai_lab_transient_density"),
                                String(format: String(localized: "ai_lab_density_format"), features.transientDensity)
                            )
                            measurementCell(String(localized: "ai_lab_tempo_stability"), "\(Int(features.tempoStability * 100))%")
                        }

                        if !features.melodyContourHz.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(localized: "ai_lab_melody_contour"))
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.52))

                                MelodyContourView(frequencies: features.melodyContourHz, accent: accent)
                                    .frame(height: 58)
                                    .accessibilityHidden(true)
                            }
                        }

                        if !features.genreHints.isEmpty {
                            analysisTagRow(
                                title: String(localized: "ai_lab_genre_hints"),
                                values: features.genreHints,
                                localizationPrefix: "ai_genre_"
                            )
                        }
                        if !features.instrumentHints.isEmpty {
                            analysisTagRow(
                                title: String(localized: "ai_lab_instrument_hints"),
                                values: features.instrumentHints,
                                localizationPrefix: "ai_instrument_"
                            )
                        }
                    }
                    ) }
                )

                divider.padding(.horizontal, 14)

                erasedMeasurementGroup(
                    .loudness,
                    content: { AnyView(
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        measurementCell(String(localized: "ai_lab_loudness"), String(format: "%.1f dBFS", features.rmsDBFS))
                        measurementCell(String(localized: "ai_lab_dynamic_range"), String(format: "%.1f dB", features.dynamicSpreadDB))
                        measurementCell(String(localized: "ai_lab_loudness_range"), String(format: "%.1f LU", features.loudnessRangeLU))
                        measurementCell(String(localized: "ai_lab_true_peak"), String(format: "%.1f dBTP", features.estimatedTruePeakDBTP))
                        measurementCell(String(localized: "ai_lab_crest_factor"), String(format: "%.1f dB", features.crestFactorDB))
                        measurementCell(String(localized: "ai_lab_clipping"), String(format: "%.3f%%", features.clippingRatio * 100))
                    }
                    ) }
                )

                divider.padding(.horizontal, 14)

                erasedMeasurementGroup(
                    .spatial,
                    content: { AnyView(
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        measurementCell(String(localized: "ai_lab_phase_correlation"), String(format: "%.2f", features.phaseCorrelation))
                        measurementCell(String(localized: "ai_lab_mono_compatibility"), "\(Int(features.monoCompatibility * 100))%")
                        measurementCell(String(localized: "ai_lab_measured_stereo_width"), String(format: "%.2fx", features.measuredStereoWidth))
                        measurementCell(String(localized: "ai_lab_spectral_centroid"), frequencyText(features.spectralCentroidHz))
                        measurementCell(String(localized: "ai_lab_spectral_bandwidth"), frequencyText(features.spectralBandwidthHz))
                        measurementCell(String(localized: "ai_lab_spectral_rolloff"), frequencyText(features.spectralRolloffHz))
                        measurementCell(String(localized: "ai_lab_spectral_flatness"), "\(Int(features.spectralFlatness * 100))%")
                        measurementCell(String(localized: "ai_lab_low_energy"), "\(Int(features.lowEnergyRatio * 100))%")
                        measurementCell(String(localized: "ai_lab_mid_energy"), "\(Int(features.midEnergyRatio * 100))%")
                        measurementCell(String(localized: "ai_lab_high_energy"), "\(Int(features.highEnergyRatio * 100))%")
                    }
                    ) }
                )

                divider.padding(.horizontal, 14)

                erasedMeasurementGroup(
                    .sample,
                    content: { AnyView(
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        measurementCell(String(localized: "ai_lab_sample_rate"), String(format: "%.1f kHz", features.sampleRate / 1_000))
                        measurementCell(String(localized: "ai_lab_sample_duration"), String(format: "%.1f s", features.sampleDuration))
                        measurementCell(String(localized: "ai_lab_sample_frames"), "\(features.frameCount)")
                    }
                    ) }
                )
            }
            .background(cardBackground)
            )
        )
    }

    private func erasedMeasurementGroup(
        _ group: AIEqualizerMeasurementGroup,
        content: @escaping () -> AnyView
    ) -> AnyView {
        let isExpanded = expandedMeasurementGroups.contains(group)

        return AnyView(VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                    if isExpanded {
                        expandedMeasurementGroups.remove(group)
                    } else {
                        expandedMeasurementGroups.insert(group)
                    }
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 12) {
                    Text(group.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))

                    Spacer()

                    MonoIcon(
                        icon: .chevronDown,
                        size: 11,
                        color: isExpanded ? accent : .white.opacity(0.38),
                        lineWidth: 1.8
                    )
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(
                isExpanded
                    ? String(localized: "ai_lab_measurement_expanded")
                    : String(localized: "ai_lab_measurement_collapsed")
            )

            if isExpanded {
                content()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: isExpanded
        )
        )
    }

    private func measurementCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 5)
    }

    private func analysisTagRow(
        title: String,
        values: [String],
        localizationPrefix: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        Text(NSLocalizedString(localizationPrefix + value, comment: ""))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(Capsule().fill(accent.opacity(0.15)))
                    }
                }
            }
        }
    }

    private func bpmText(_ bpm: Float, confidence: Float) -> String {
        guard bpm > 0 else { return "—" }
        let prefix = confidence < 0.5 ? "≈ " : ""
        return prefix + String(format: "%.0f BPM", bpm)
    }

    private func keyText(_ key: String, confidence: Float) -> String {
        guard !key.isEmpty else { return "—" }
        let localizedKey = key
            .replacingOccurrences(of: " major", with: String(localized: "ai_key_major_suffix"))
            .replacingOccurrences(of: " minor", with: String(localized: "ai_key_minor_suffix"))
        return (confidence < 0.35 ? "≈ " : "") + localizedKey
    }

    private func pitchText(_ frequency: Float) -> String {
        guard frequency.isFinite, frequency > 0 else { return "—" }
        let midi = Int((69 + 12 * log2f(frequency / 440)).rounded())
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let pitchClass = (midi % 12 + 12) % 12
        let octave = midi / 12 - 1
        return "≈ \(names[pitchClass])\(octave) · \(frequencyText(frequency))"
    }

    private func proposalSection(_ proposal: AIEqualizerProposal) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 22) {
            erasedSection(
                title: String(localized: "ai_lab_tuning_result"),
                content: AnyView(
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(proposal.resolvedTuningProfile.title)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(accent)
                                Text(proposal.profileName)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(proposal.profileSpecificSummary)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .fixedSize(horizontal: false, vertical: true)
                                tuningReferenceRows(for: proposal)
                            }
                            Spacer(minLength: 12)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(Int(proposal.confidence * 100))%")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(accent)
                                if let timing = proposal.timing {
                                    Text(
                                        String(
                                            format: String(localized: "ai_tuning_total_time_format"),
                                            tuningDurationText(timing.total)
                                        )
                                    )
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.54))
                                    .lineLimit(1)
                                }
                            }
                        }

                        if let timing = proposal.timing {
                            tuningTimingRow(timing)
                        }

                        AIEqualizerCurveView(
                            gains: proposal.gains,
                            mode: proposal.graphicEQMode,
                            accent: accent
                        )
                            .frame(height: 174)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                            spacing: 8
                        ) {
                            resultCell(
                                String(localized: "ai_tuning_intensity"),
                                (proposal.tuningIntensity ?? .smart).title
                            )
                            resultCell(String(localized: "ai_lab_preamp"), String(format: "%.1f dB", proposal.preampDB))
                            resultCell(String(localized: "eq_bass"), String(format: "%+.1f dB", proposal.tone.bassGain))
                            resultCell(String(localized: "eq_treble"), String(format: "%+.1f dB", proposal.tone.trebleGain))
                            resultCell(String(localized: "eq_surround"), "\(Int(proposal.spatial.surroundLevel * 100))%")
                            resultCell(String(localized: "eq_reverb"), "\(Int(proposal.spatial.reverbLevel * 100))%")
                            if let evidenceCount = proposal.learningEvidenceCount,
                               evidenceCount > 0 {
                                resultCell(
                                    String(localized: "ai_learning_enabled"),
                                    String(
                                        format: String(localized: "ai_learning_applied_value"),
                                        evidenceCount
                                    )
                                )
                            }
                        }
                    }
                    .padding(14)

                    divider.padding(.horizontal, 14)

                    erasedProposalDisclosure(
                        title: String(localized: "ai_lab_more_parameters"),
                        isExpanded: $isProposalParameterExpanded,
                        content: { AnyView(
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                            spacing: 8
                        ) {
                            resultCell(String(localized: "eq_processing_intensity"), String(format: "%.0f%%", proposal.professional.processingIntensity * 100))
                            resultCell(String(localized: "ai_lab_stereo_width"), String(format: "%.2fx", proposal.spatial.stereoWidth))
                            if proposal.effects.loudnessNormalizationEnabled {
                                resultCell(String(localized: "eq_target_lufs"), String(format: "%.1f LUFS", proposal.effects.targetLUFS))
                            }
                            if proposal.effects.compressorEnabled {
                                resultCell(String(localized: "eq_compressor"), String(format: "%.1f:1", proposal.effects.compressorRatio))
                            }
                            if proposal.effects.subboostEnabled {
                                resultCell(String(localized: "eq_subboost"), String(format: "%+.1f dB", proposal.effects.subboostGainDB))
                            }
                            if proposal.effects.virtualBassEnabled {
                                resultCell(String(localized: "eq_virtual_bass"), String(format: "%.1f", proposal.effects.virtualBassStrength))
                            }
                            if proposal.effects.exciterEnabled {
                                resultCell(String(localized: "eq_exciter"), String(format: "%+.1f dB", proposal.effects.exciterAmountDB))
                            }
                            if proposal.effects.bs2bEnabled || proposal.effects.crossfeedEnabled || proposal.effects.haasEnabled {
                                resultCell(String(localized: "eq_headphone_spatial"), headphoneEffectName(proposal.effects))
                            }
                            if proposal.effects.finalLimiterEnabled {
                                resultCell(String(localized: "eq_final_limiter"), String(format: "%.1f dBFS", proposal.effects.finalLimiterCeilingDB))
                            }
                        }
                        ) }
                    )

                    divider.padding(.horizontal, 14)

                    erasedProposalDisclosure(
                        title: String(localized: "eq_mono_calibration"),
                        isExpanded: $isCalibrationExpanded,
                        content: { AnyView(
                        VStack(spacing: 0) {
                            stateRow(String(localized: "eq_output_calibration"), isOn: proposal.calibration.outputCalibrationEnabled)
                            divider
                            stateRow(String(localized: "eq_loudness_matching"), isOn: proposal.calibration.loudnessMatchingEnabled)
                            divider
                            stateRow(String(localized: "eq_smart_song"), isOn: proposal.calibration.smartSongCompensationEnabled)
                            divider
                            stateRow(String(localized: "eq_dynamic_eq"), isOn: proposal.professional.dynamicEQ.enabled)
                            divider
                            stateRow(String(localized: "eq_multiband"), isOn: proposal.professional.multiband.enabled)
                            divider
                            stateRow(String(localized: "eq_parametric_eq"), isOn: proposal.professional.parametricEQ.enabled)
                        }
                        ) }
                    )
                }
                .background(cardBackground)
                )
            )

            HStack(spacing: 10) {
                Button(action: agent.applyCurrentProposal) {
                    Text(agent.isCurrentProposalApplied
                         ? String(localized: "ai_lab_applied")
                         : String(localized: "ai_lab_apply"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(accentForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(accent.opacity(0.78)))
                }
                .buttonStyle(MonoBouncingButtonStyle())
                .disabled(agent.isCurrentProposalApplied)

                Button(action: agent.analyzeCurrentSong) {
                    MonoIcon(icon: .refresh, size: 17, color: .white.opacity(0.86))
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
                }
                .buttonStyle(MonoBouncingButtonStyle())
                .accessibilityLabel(String(localized: "ai_lab_reanalyze"))
            }

            if agent.adaptiveLearningEnabled,
               agent.learnsFromExplicitFeedback,
               agent.isCurrentProposalApplied {
                adaptiveLearningFeedbackRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        })
    }

    private var adaptiveLearningFeedbackRow: some View {
        HStack(spacing: 10) {
            learningFeedbackButton(
                title: String(localized: "ai_learning_positive"),
                feedback: .positive
            )
            learningFeedbackButton(
                title: String(localized: "ai_learning_negative"),
                feedback: .negative
            )
        }
    }

    private func learningFeedbackButton(
        title: String,
        feedback: AIEqualizerLearningFeedback
    ) -> some View {
        let isSelected = agent.currentLearningFeedback == feedback
        return Button {
            agent.recordCurrentProposalFeedback(feedback)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? accentForeground : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.8) : Color.white.opacity(0.055))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(
                                    isSelected ? accent.opacity(0.9) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                )
        }
        .buttonStyle(MonoBouncingButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var savedResultsSection: AnyView {
        erasedSection(
            title: String(localized: "ai_lab_saved_results"),
            content: AnyView(
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(format: String(localized: "ai_lab_history_count"), agent.savedProposals.count))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Button {
                            agent.deleteAllSavedProposalsForCurrentSong()
                        } label: {
                            Text(String(localized: "ai_lab_delete_current_song"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.86))
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(agent.savedProposals) { saved in
                        savedProposalRow(saved)
                    }
                }
                .padding(14)
                .background(cardBackground)
            )
        )
    }

    private var clearAllProposalsButton: some View {
        Button {
            isShowingClearAllProposalsConfirmation = true
        } label: {
            HStack(spacing: 8) {
                MonoIcon(icon: .trash, size: 13, color: .red.opacity(0.88))
                Text(String(localized: "ai_lab_clear_all_proposals"))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.red.opacity(0.88))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red.opacity(0.075))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.red.opacity(0.16), lineWidth: 1)
                    }
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle())
    }

    private func previousSavedProposal(
        for current: AIEqualizerProposal
    ) -> AIEqualizerSavedProposal? {
        agent.savedProposals.first { $0.id != current.id }
    }

    private func automaticComparisonSection(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> AnyView {
        let bandChanges = changedBandCount(current: current, previous: previous)
        let largestChange = largestBandChange(current: current, previous: previous)
        let changes = keyParameterChanges(current: current, previous: previous)

        return erasedSection(
            title: String(localized: "ai_lab_automatic_comparison"),
            content: AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    AIEqualizerComparisonCurve(
                        current: current.gains,
                        previous: previous.gains,
                        accent: accent
                    )
                    .frame(height: 94)

                    HStack(spacing: 8) {
                        comparisonSummaryMetric(
                            title: String(localized: "ai_lab_changed_bands"),
                            value: String(format: String(localized: "ai_lab_changed_bands_format"), bandChanges),
                            color: accent
                        )
                        comparisonSummaryMetric(
                            title: String(localized: "ai_lab_largest_change"),
                            value: largestChange.map {
                                "\(frequencyText($0.frequency)) \(String(format: "%+.1f dB", $0.delta))"
                            } ?? String(localized: "ai_lab_no_change"),
                            color: largestChange == nil ? .white.opacity(0.5) : accent
                        )
                    }

                    if changes.isEmpty {
                        Text(String(localized: "ai_lab_no_key_changes"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.54))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(changes) { change in
                                automaticChangeRow(change)
                                if change.id != changes.last?.id {
                                    divider
                                }
                            }
                        }
                    }

                    Button {
                        comparisonProposal = agent.savedProposals.first { $0.id == previous.id }
                    } label: {
                        HStack(spacing: 6) {
                            Text(String(localized: "ai_lab_view_full_comparison"))
                                .font(.system(size: 12, weight: .bold))
                            MonoIcon(icon: .chevronRight, size: 10, color: accent)
                        }
                        .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(cardBackground)
            )
        )
    }

    private func comparisonSummaryMetric(
        title: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
    }

    private func automaticChangeRow(_ change: AIEqualizerComparisonChange) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Text(change.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(change.previousValue)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))

                MonoIcon(icon: .chevronRight, size: 8, color: .white.opacity(0.26))

                Text(change.currentValue)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)

                Text(change.deltaValue)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(change.delta >= 0 ? accent : .white.opacity(0.54))
                    .frame(width: 48, alignment: .trailing)
            }

            GeometryReader { proxy in
                let magnitude = min(1, abs(CGFloat(change.delta)) / 12)
                ZStack(alignment: change.delta >= 0 ? .leading : .trailing) {
                    Capsule().fill(Color.white.opacity(0.055))
                    Capsule()
                        .fill(change.delta >= 0 ? accent : Color.white.opacity(0.34))
                        .frame(width: max(3, proxy.size.width * magnitude))
                }
            }
            .frame(height: 2)
        }
        .padding(.vertical, 8)
    }

    private func changedBandCount(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> Int {
        guard current.graphicEQMode == previous.graphicEQMode else {
            return current.gains.count
        }
        return zip(current.gains, previous.gains).filter { abs($0 - $1) >= 0.15 }.count
    }

    private func largestBandChange(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> (frequency: Float, delta: Float)? {
        guard current.graphicEQMode == previous.graphicEQMode else { return nil }
        let frequencies = current.graphicEQMode.centerFrequencies
        let count = min(frequencies.count, min(current.gains.count, previous.gains.count))
        guard count > 0 else { return nil }
        let index = (0..<count).max {
            abs(current.gains[$0] - previous.gains[$0])
                < abs(current.gains[$1] - previous.gains[$1])
        }
        guard let index else { return nil }
        let delta = current.gains[index] - previous.gains[index]
        guard abs(delta) >= 0.15 else { return nil }
        return (frequencies[index], delta)
    }

    private func keyParameterChanges(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> [AIEqualizerComparisonChange] {
        var changes: [AIEqualizerComparisonChange] = []
        appendChange(
            &changes,
            title: String(localized: "eq_bass"),
            current: current.tone.bassGain,
            previous: previous.tone.bassGain,
            suffix: " dB"
        )
        appendChange(
            &changes,
            title: String(localized: "eq_treble"),
            current: current.tone.trebleGain,
            previous: previous.tone.trebleGain,
            suffix: " dB"
        )
        appendChange(
            &changes,
            title: String(localized: "eq_surround"),
            current: current.spatial.surroundLevel * 100,
            previous: previous.spatial.surroundLevel * 100,
            suffix: "%"
        )
        appendChange(
            &changes,
            title: String(localized: "eq_reverb"),
            current: current.spatial.reverbLevel * 100,
            previous: previous.spatial.reverbLevel * 100,
            suffix: "%"
        )
        appendChange(
            &changes,
            title: String(localized: "eq_processing_intensity"),
            current: current.professional.processingIntensity * 100,
            previous: previous.professional.processingIntensity * 100,
            suffix: "%"
        )
        return changes
    }

    private func appendChange(
        _ changes: inout [AIEqualizerComparisonChange],
        title: String,
        current: Float,
        previous: Float,
        suffix: String
    ) {
        let delta = current - previous
        guard abs(delta) >= 0.1 else { return }
        changes.append(
            AIEqualizerComparisonChange(
                id: title,
                title: title,
                previousValue: String(format: "%.1f%@", previous, suffix),
                currentValue: String(format: "%.1f%@", current, suffix),
                deltaValue: String(format: "%+.1f", delta),
                delta: delta
            )
        )
    }

    private func savedProposalRow(_ saved: AIEqualizerSavedProposal) -> some View {
        let isCurrent = agent.proposal?.id == saved.id
        let canApply = saved.proposal.graphicEQMode == eqManager.graphicEQMode
            && saved.outputIdentity == currentOutputIdentity

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(saved.proposal.resolvedTuningProfile.title)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(accent)
                    Text(saved.proposal.profileName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if isCurrent {
                        Text(String(localized: "ai_lab_current_result"))
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(accent.opacity(0.15)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(saved.proposal.createdAt, style: .date)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(saved.proposal.profileSpecificSummary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            tuningReferenceRows(for: saved.proposal, compact: true)

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 7) {
                    savedMetadataPill(saved.proposal.graphicEQMode == .thirtyTwoBand
                                      ? String(localized: "eq_thirty_two_band")
                                      : String(localized: "eq_ten_band"))
                    savedMetadataPill(saved.outputIdentity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    agent.applySavedProposal(saved)
                } label: {
                    MonoIcon(icon: .play, size: 13, color: canApply ? .white.opacity(0.86) : .white.opacity(0.28))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .disabled(!canApply)
                .accessibilityLabel(String(localized: "ai_lab_apply_saved"))

                Button(role: .destructive) {
                    agent.deleteSavedProposal(saved)
                } label: {
                    MonoIcon(icon: .trash, size: 13, color: .red.opacity(0.84))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "ai_lab_delete"))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCurrent ? accent.opacity(0.1) : Color.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isCurrent ? accent.opacity(0.28) : Color.white.opacity(0.06), lineWidth: 1)
                }
        )
    }

    private func savedMetadataPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.52))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 7)
            .frame(minHeight: 22)
            .background(Capsule().fill(Color.white.opacity(0.055)))
    }

    @ViewBuilder
    private func tuningReferenceRows(
        for proposal: AIEqualizerProposal,
        compact: Bool = false
    ) -> some View {
        let references = tuningReferences(for: proposal)
        if !references.isEmpty {
            VStack(alignment: .leading, spacing: compact ? 5 : 6) {
                ForEach(references) { reference in
                    HStack(alignment: .top, spacing: 7) {
                        Text(reference.title)
                            .font(.system(size: compact ? 9.5 : 10, weight: .bold))
                            .foregroundStyle(accent.opacity(compact ? 0.72 : 0.86))
                            .fixedSize(horizontal: true, vertical: false)
                        Text(reference.value)
                            .font(.system(size: compact ? 10.5 : 11, weight: .medium))
                            .foregroundStyle(.white.opacity(compact ? 0.48 : 0.54))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, compact ? 1 : 3)
        }
    }

    private func tuningReferences(for proposal: AIEqualizerProposal) -> [AIEqualizerTuningReference] {
        var references: [AIEqualizerTuningReference] = []
        if let artist = proposal.artistStyleReference?.trimmingCharacters(in: .whitespacesAndNewlines),
           !artist.isEmpty {
            references.append(
                AIEqualizerTuningReference(
                    id: "artist",
                    title: String(localized: "ai_lab_artist_reference"),
                    value: artist
                )
            )
        }
        if let vocal = proposal.vocalCharacterReference?.trimmingCharacters(in: .whitespacesAndNewlines),
           !vocal.isEmpty {
            references.append(
                AIEqualizerTuningReference(
                    id: "vocal",
                    title: String(localized: "ai_lab_vocal_reference"),
                    value: vocal
                )
            )
        }
        return references
    }

    private func erasedProposalDisclosure(
        title: String,
        isExpanded: Binding<Bool>,
        content: @escaping () -> AnyView
    ) -> AnyView {
        AnyView(VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                    isExpanded.wrappedValue.toggle()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))

                    Spacer()

                    MonoIcon(
                        icon: .chevronDown,
                        size: 11,
                        color: isExpanded.wrappedValue ? accent : .white.opacity(0.38),
                        lineWidth: 1.8
                    )
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(
                isExpanded.wrappedValue
                    ? String(localized: "ai_lab_measurement_expanded")
                    : String(localized: "ai_lab_measurement_collapsed")
            )

            if isExpanded.wrappedValue {
                content()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: isExpanded.wrappedValue
        )
        )
    }

    private func resultCell(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.54))
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.045)))
    }

    private func tuningTimingRow(_ timing: AIEqualizerTiming) -> some View {
        HStack(spacing: 0) {
            tuningTimingMetric(
                String(localized: "ai_tuning_sampling_time"),
                duration: timing.sampling
            )
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 24)
            tuningTimingMetric(
                String(localized: "ai_tuning_generation_time"),
                duration: timing.generation
            )
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 24)
            tuningTimingMetric(
                String(localized: "ai_tuning_applying_time"),
                duration: timing.applying
            )
        }
        .padding(.vertical, 2)
    }

    private func tuningTimingMetric(_ title: String, duration: TimeInterval) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
            Text(tuningDurationText(duration))
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func headphoneEffectName(_ effects: MonoEffectTuningConfiguration) -> String {
        if effects.bs2bEnabled { return String(localized: "eq_bs2b") }
        if effects.crossfeedEnabled { return String(localized: "eq_crossfeed") }
        if effects.haasEnabled { return String(localized: "eq_haas") }
        return "—"
    }

    private func stateRow(_ title: String, isOn: Bool) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
            Circle()
                .fill(isOn ? accent : Color.white.opacity(0.18))
                .frame(width: 7, height: 7)
        }
        .frame(height: 44)
    }

    private func failureSection(_ message: String) -> AnyView {
        erasedSection(
            title: String(localized: "ai_lab_failed"),
            content: AnyView(
            HStack(alignment: .top, spacing: 12) {
                MonoIcon(icon: .warning, size: 17, color: .red.opacity(0.9))
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(cardBackground)
            )
        )
    }

    private var statusLabel: some View {
        Text(statusText)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(statusColor.opacity(0.13)))
    }

    private var statusText: String {
        switch agent.phase {
        case .sampling: return agent.samplingStage.title
        case .requesting: return agent.generationStage.title
        case .applying: return String(localized: "ai_lab_applying")
        case .ready:
            return agent.isCurrentProposalApplied
                ? String(localized: "ai_lab_applied")
                : String(localized: "ai_lab_ready")
        case .failed: return String(localized: "ai_lab_failed")
        case .idle: return String(localized: "ai_lab_not_analyzed")
        }
    }

    private var statusColor: Color {
        switch agent.phase {
        case .failed: return .red.opacity(0.9)
        case .ready where agent.isCurrentProposalApplied: return .green.opacity(0.9)
        default: return accent
        }
    }

    private var processPresentation: (
        state: AIEqualizerProcessVisualizer.State,
        title: String,
        currentStep: Int
    )? {
        switch agent.phase {
        case let .sampling(progress):
            return (
                .sampling(progress: progress, stage: agent.samplingStage),
                agent.samplingStage.title,
                0
            )
        case .requesting:
            return (
                .generating(
                    stage: agent.generationStage,
                    startedAt: agent.generationStartedAt
                ),
                agent.generationStage.title,
                1
            )
        case .applying:
            return (
                .applying,
                String(localized: "ai_lab_applying"),
                2
            )
        case .idle, .ready, .failed:
            return nil
        }
    }

    private var serviceFooter: some View {
        Text(String(localized: "ai_lab_service_credit"))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.52))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    /// Heavy measurement content is intentionally erased before it is inserted
    /// into the page. Keeping its deeply nested disclosure/grid tree as one
    /// concrete SwiftUI type can overflow Swift's runtime metadata demangler on
    /// device when measured features first become available.
    private func erasedSection(title: String, content: AnyView) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.56))
                content
            }
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
    }

    private var backdrop: some View {
        ZStack {
            PlaylistColorBackground(
                coverUrl: player.currentSong?.coverUrl?.sized(720)
            )
            .saturation(0.78)

            Color.black.opacity(0.48)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.26),
                    Color.black.opacity(0.54),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func refreshCoverAccent() {
        coverColors.extract(from: player.currentSong?.coverUrl?.sized(200).absoluteString)
    }

    private func primaryAnalysisAction() {
        selectedWorkspace = .tuning
        agent.phase.isWorking ? agent.cancelAnalysis() : agent.analyzeCurrentSong()
    }

    private func frequencyText(_ frequency: Float) -> String {
        frequency >= 1_000
            ? String(format: "%.2f kHz", frequency / 1_000)
            : String(format: "%.0f Hz", frequency)
    }

    private func compactElapsed(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func tuningDurationText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        guard totalSeconds >= 60 else {
            return String(
                format: String(localized: "ai_tuning_seconds_format"),
                totalSeconds
            )
        }
        return String(
            format: String(localized: "ai_tuning_minutes_seconds_format"),
            totalSeconds / 60,
            totalSeconds % 60
        )
    }
}

private enum AIEqualizerWorkspace: String, CaseIterable, Identifiable {
    case tuning
    case measurement
    case result
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tuning: return String(localized: "ai_lab_workspace_tuning")
        case .measurement: return String(localized: "ai_lab_workspace_measurement")
        case .result: return String(localized: "ai_lab_workspace_result")
        case .history: return String(localized: "ai_lab_workspace_history")
        }
    }

    var icon: MonoIcon.IconType {
        switch self {
        case .tuning: return .equalizer
        case .measurement: return .waveform
        case .result: return .sparkle
        case .history: return .history
        }
    }
}

private struct AIEqualizerComparisonChange: Identifiable {
    let id: String
    let title: String
    let previousValue: String
    let currentValue: String
    let deltaValue: String
    let delta: Float
}

private struct AIEqualizerTuningReference: Identifiable {
    let id: String
    let title: String
    let value: String
}

private struct AIEqualizerProposalComparisonView: View {
    let current: AIEqualizerProposal?
    let historical: AIEqualizerSavedProposal
    let accent: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.055, blue: 0.072)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(historical.proposal.resolvedTuningProfile.title)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(accent)
                        Text(historical.proposal.profileName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(String(localized: "ai_lab_compare_subtitle"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.52))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let current, current.id != historical.id {
                        comparisonHeader(current: current, previous: historical.proposal)
                        comparisonMetrics(current: current, previous: historical.proposal)
                        if current.graphicEQMode == historical.proposal.graphicEQMode {
                            bandComparison(current: current, previous: historical.proposal)
                        }
                    } else {
                        HStack(spacing: 10) {
                            MonoIcon(icon: .infoCircle, size: 16, color: accent)
                            Text(String(localized: "ai_lab_no_comparison"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(cardBackground)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .iPadContentWidth(720)
            }
        }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .navigationTitle(String(localized: "ai_lab_compare_title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                MonoToolbarBackButton(iconColor: .white)
            }
        }
    }

    private func comparisonHeader(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> some View {
        HStack(spacing: 8) {
            comparisonLegend(
                title: String(localized: "ai_lab_current_result"),
                profile: current.resolvedTuningProfile.title,
                value: current.profileName,
                color: accent
            )
            comparisonLegend(
                title: String(localized: "ai_lab_previous_result"),
                profile: previous.resolvedTuningProfile.title,
                value: previous.profileName,
                color: .white.opacity(0.46)
            )
        }
    }

    private func comparisonLegend(
        title: String,
        profile: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(profile)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(cardBackground)
    }

    private func comparisonMetrics(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> some View {
        VStack(spacing: 0) {
            comparisonMetric(
                String(localized: "ai_lab_preamp"),
                current: current.preampDB,
                previous: previous.preampDB,
                suffix: " dB"
            )
            divider
            comparisonMetric(
                String(localized: "eq_bass"),
                current: current.tone.bassGain,
                previous: previous.tone.bassGain,
                suffix: " dB"
            )
            divider
            comparisonMetric(
                String(localized: "eq_treble"),
                current: current.tone.trebleGain,
                previous: previous.tone.trebleGain,
                suffix: " dB"
            )
            divider
            comparisonMetric(
                String(localized: "eq_surround"),
                current: current.spatial.surroundLevel * 100,
                previous: previous.spatial.surroundLevel * 100,
                suffix: "%"
            )
            divider
            comparisonMetric(
                String(localized: "eq_reverb"),
                current: current.spatial.reverbLevel * 100,
                previous: previous.spatial.reverbLevel * 100,
                suffix: "%"
            )
            divider
            comparisonMetric(
                String(localized: "ai_lab_stereo_width"),
                current: current.spatial.stereoWidth,
                previous: previous.spatial.stereoWidth,
                suffix: "x"
            )
            divider
            comparisonMetric(
                String(localized: "eq_processing_intensity"),
                current: current.professional.processingIntensity * 100,
                previous: previous.professional.processingIntensity * 100,
                suffix: "%"
            )
        }
        .padding(14)
        .background(cardBackground)
    }

    private func comparisonMetric(
        _ title: String,
        current: Float,
        previous: Float,
        suffix: String
    ) -> some View {
        let delta = current - previous
        return HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 92, alignment: .leading)
            Text(String(format: "%.1f%@", current, suffix))
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.1f%@", previous, suffix))
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.56))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%+.1f", delta))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(delta >= 0 ? accent : .white.opacity(0.46))
                .frame(width: 48, alignment: .trailing)
        }
        .frame(minHeight: 36)
    }

    private func bandComparison(
        current: AIEqualizerProposal,
        previous: AIEqualizerProposal
    ) -> some View {
        let frequencies = current.graphicEQMode.centerFrequencies
        let count = min(frequencies.count, min(current.gains.count, previous.gains.count))

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "ai_lab_eq_band_comparison"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text(String(localized: "ai_lab_frequency"))
                            .frame(width: 74, alignment: .leading)
                        Text(String(localized: "ai_lab_current_short"))
                            .frame(width: 78, alignment: .trailing)
                        Text(String(localized: "ai_lab_previous_short"))
                            .frame(width: 78, alignment: .trailing)
                        Text(String(localized: "ai_lab_difference_short"))
                            .frame(width: 78, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.bottom, 8)

                    ForEach(0..<count, id: \.self) { index in
                        let delta = current.gains[index] - previous.gains[index]
                        HStack(spacing: 0) {
                            Text(frequencyText(frequencies[index]))
                                .frame(width: 74, alignment: .leading)
                            Text(String(format: "%+.1f dB", current.gains[index]))
                                .foregroundStyle(accent)
                                .frame(width: 78, alignment: .trailing)
                            Text(String(format: "%+.1f dB", previous.gains[index]))
                                .foregroundStyle(.white.opacity(0.56))
                                .frame(width: 78, alignment: .trailing)
                            Text(String(format: "%+.1f", delta))
                                .foregroundStyle(delta >= 0 ? accent : .white.opacity(0.46))
                                .frame(width: 78, alignment: .trailing)
                        }
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .frame(height: 27)
                    }
                }
                .frame(minWidth: 308, alignment: .leading)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
    }

    private func frequencyText(_ frequency: Float) -> String {
        frequency >= 1_000
            ? String(format: "%.1f kHz", frequency / 1_000)
            : String(format: "%.0f Hz", frequency)
    }
}

private enum AIEqualizerMeasurementGroup: String, Hashable {
    case music
    case loudness
    case spatial
    case sample

    var title: String {
        switch self {
        case .music: return String(localized: "ai_lab_measurement_music")
        case .loudness: return String(localized: "ai_lab_measurement_loudness")
        case .spatial: return String(localized: "ai_lab_measurement_spatial")
        case .sample: return String(localized: "ai_lab_measurement_sample")
        }
    }
}

private struct AIEqualizerActivityDot: View {
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            AppFrameRate.throttledTimeline(
                maximumFramesPerSecond: 12,
                paused: reduceMotion
            )
        ) { timeline in
            let pulse: CGFloat = reduceMotion
                ? 0.5
                : CGFloat((sin(timeline.date.timeIntervalSinceReferenceDate * 3.2) + 1) * 0.5)

            ZStack {
                Circle()
                    .fill(accent.opacity(0.16 + 0.12 * Double(pulse)))
                    .scaleEffect(1 + 0.7 * pulse)
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }
}

private struct AIEqualizerPhaseRail: View {
    let currentStep: Int
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var labels: [String] {
        [
            String(localized: "ai_tuning_sampling_time"),
            String(localized: "ai_tuning_generation_time"),
            String(localized: "ai_tuning_applying_time")
        ]
    }

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(height: 1)
                .padding(.horizontal, 48)
                .offset(y: 5.5)

            HStack(spacing: 8) {
                ForEach(labels.indices, id: \.self) { index in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(index <= currentStep ? accent : Color.white.opacity(0.16))
                            .frame(
                                width: index == currentStep ? 11 : 9,
                                height: index == currentStep ? 11 : 9
                            )
                            .overlay {
                                if index == currentStep {
                                    Circle().stroke(accent.opacity(0.26), lineWidth: 4)
                                }
                            }

                        Text(labels[index])
                            .font(.system(size: 10, weight: index == currentStep ? .bold : .semibold))
                            .foregroundStyle(index <= currentStep ? .white.opacity(0.82) : .white.opacity(0.52))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: currentStep
        )
        .accessibilityElement(children: .combine)
    }
}

private struct MelodyContourView: View {
    let frequencies: [Float]
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let notes = frequencies.compactMap { frequency -> CGFloat? in
                guard frequency.isFinite, frequency > 0 else { return nil }
                return CGFloat(69 + 12 * log2f(frequency / 440))
            }
            guard notes.count >= 2 else { return }

            let lower = notes.min() ?? 0
            let upper = notes.max() ?? lower
            let span = max(4, upper - lower)
            let horizontalInset: CGFloat = 3
            let verticalInset: CGFloat = 5
            let width = max(1, size.width - horizontalInset * 2)
            let height = max(1, size.height - verticalInset * 2)

            for index in 0..<3 {
                let y = verticalInset + height * CGFloat(index) / 2
                var gridLine = Path()
                gridLine.move(to: CGPoint(x: horizontalInset, y: y))
                gridLine.addLine(to: CGPoint(x: size.width - horizontalInset, y: y))
                context.stroke(gridLine, with: .color(.white.opacity(0.05)), lineWidth: 1)
            }

            var contour = Path()
            for (index, note) in notes.enumerated() {
                let x = horizontalInset + width * CGFloat(index) / CGFloat(max(1, notes.count - 1))
                let normalized = (note - lower) / span
                let y = verticalInset + height * (1 - normalized)
                if index == 0 {
                    contour.move(to: CGPoint(x: x, y: y))
                } else {
                    contour.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(
                contour,
                with: .color(accent.opacity(0.86)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

private struct AIEqualizerProcessVisualizer: View {
    enum State {
        case sampling(progress: Double, stage: AIEqualizerSamplingStage)
        case generating(stage: AIEqualizerGenerationStage, startedAt: Date?)
        case applying

        func progress(at date: Date) -> Double {
            switch self {
            case let .sampling(progress, _):
                return 0.04 + min(1, max(0, progress)) * 0.36
            case let .generating(stage, startedAt):
                let elapsed = max(
                    0,
                    startedAt.map { date.timeIntervalSince($0) } ?? 0
                )
                let advancement = 1 - exp(-elapsed / 42)
                let estimatedGenerationProgress = min(
                    0.88,
                    0.45 + advancement * 0.43
                )
                switch stage {
                case .preparing:
                    return elapsed > 1
                        ? estimatedGenerationProgress
                        : 0.42
                case .generating:
                    return estimatedGenerationProgress
                case .validating:
                    return 0.91
                case .finalizing:
                    return 0.96
                }
            case .applying:
                return 0.99
            }
        }

        var progress: Double { progress(at: .now) }

        var movement: Double {
            switch self {
            case let .sampling(_, stage):
                switch stage {
                case .preparing, .waitingForAudio: return 0.08
                case .collectingSpectrum: return 0.28
                case .measuringDynamics: return 0.2
                case .organizingFeatures: return 0.1
                case .finalizing: return 0.04
                }
            case let .generating(stage, _):
                switch stage {
                case .preparing: return 0.08
                case .generating: return 0.15
                case .validating: return 0.06
                case .finalizing: return 0.025
                }
            case .applying:
                return 0.015
            }
        }

        var isGenerating: Bool {
            switch self {
            case .generating, .applying: return true
            case .sampling: return false
            }
        }
    }

    let state: State
    let mode: GraphicEQMode
    let accent: Color
    let measuredBands: [Float]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var performance = AriaPerformanceGovernor.shared

    private var animationFramesPerSecond: Int {
        switch performance.tier {
        case .high: return 18
        case .medium: return 10
        case .low: return 6
        }
    }

    var body: some View {
        TimelineView(
            AppFrameRate.throttledTimeline(
                maximumFramesPerSecond: animationFramesPerSecond,
                paused: reduceMotion
            )
        ) { timeline in
            let progress = state.progress(at: timeline.date)

            VStack(spacing: 12) {
                Canvas { context, size in
                    drawFrequencyRail(
                        in: &context,
                        size: size,
                        time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                        progress: progress
                    )
                }

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(accent.opacity(0.88))
                        .scaleEffect(x: max(0.012, progress), y: 1, anchor: .leading)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.2),
                            value: progress
                        )
                }
                .frame(height: 2)
            }
        }
    }

    private func drawFrequencyRail(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        progress: Double
    ) {
        guard size.width > 0, size.height > 0 else { return }

        let bandCount = mode.bandCount
        let divisor = max(1, bandCount - 1)
        let slotWidth = size.width / CGFloat(bandCount)
        let maximumBarWidth: CGFloat = mode == .tenBand ? 6 : 4
        let barWidth = min(maximumBarWidth, max(2, slotWidth * 0.38))
        let plotHeight = size.height - 8
        let baselineY = size.height - 4
        let scanPosition = reduceMotion
            ? progress
            : time.truncatingRemainder(dividingBy: 1.7) / 1.7

        for lineIndex in 0..<3 {
            let y = 4 + plotHeight * CGFloat(lineIndex) / 2
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(.white.opacity(lineIndex == 2 ? 0.08 : 0.045)), lineWidth: 1)
        }

        for index in 0..<bandCount {
            let position = Double(index) / Double(divisor)
            let height = plotHeight * CGFloat(
                bandHeight(index: index, divisor: divisor, time: time)
            )
            let x = slotWidth * (CGFloat(index) + 0.5)
            let isResolved = position <= progress
            let isScanning = abs(position - scanPosition) < 0.045
            let rect = CGRect(
                x: x - barWidth * 0.5,
                y: baselineY - height,
                width: barWidth,
                height: max(3, height)
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: barWidth * 0.5),
                with: .color(
                    isResolved
                        ? accent.opacity(isScanning ? 1 : 0.82)
                        : Color.white.opacity(isScanning ? 0.28 : 0.11)
                )
            )
        }

        let scanX = size.width * CGFloat(scanPosition)
        var scanLine = Path()
        scanLine.move(to: CGPoint(x: scanX, y: 2))
        scanLine.addLine(to: CGPoint(x: scanX, y: baselineY))
        context.stroke(scanLine, with: .color(accent.opacity(0.28)), lineWidth: 1)
    }

    private func bandHeight(index: Int, divisor: Int, time: TimeInterval) -> Double {
        let position = Double(index) / Double(divisor)
        let measured = normalizedMeasuredHeight(at: index, divisor: divisor)
        let envelope = 0.55 + 0.45 * sin(position * .pi)
        let base: Double
        if state.isGenerating, let measured {
            base = measured
        } else {
            base = 0.2 + 0.34 * envelope + 0.08 * sin(Double(index) * 1.37)
        }
        let motion = reduceMotion
            ? 0
            : state.movement * sin(time * 1.7 + Double(index) * 0.74)
        return min(0.96, max(0.08, base + motion))
    }

    private func normalizedMeasuredHeight(at index: Int, divisor: Int) -> Double? {
        guard !measuredBands.isEmpty else { return nil }
        let sourceIndex = Int(
            (Double(index) / Double(divisor) * Double(max(0, measuredBands.count - 1))).rounded()
        )
        guard measuredBands.indices.contains(sourceIndex) else { return nil }
        return min(0.92, max(0.12, Double((measuredBands[sourceIndex] + 60) / 60)))
    }
}

private func normalizedAIEqualizerAccent(_ color: Color) -> Color {
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
        return Color(red: 0.53, green: 0.62, blue: 1)
    }

    let adjustedSaturation = saturation < 0.08 ? saturation : min(saturation, 0.82)
    let candidate = Color(
        hue: Double(hue),
        saturation: Double(adjustedSaturation),
        brightness: Double(max(brightness, 0.82)),
        opacity: Double(alpha)
    )
    let background = Color(red: 0.055, green: 0.055, blue: 0.072)

    guard ThemeColorCustomization.contrastRatio(between: candidate, and: background) < 4.5 else {
        return candidate
    }

    return Color(
        hue: Double(hue),
        saturation: Double(saturation < 0.08 ? saturation : min(saturation, 0.56)),
        brightness: 0.96,
        opacity: Double(alpha)
    )
}

private struct SpectrumMeasurementView: View {
    let values: [Float]
    let frequencies: [Float]
    let mode: GraphicEQMode
    let accent: Color

    @State private var selectedIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bandCount: Int {
        min(values.count, frequencies.count)
    }

    private var resolvedSelection: Int? {
        if let selectedIndex, selectedIndex < bandCount { return selectedIndex }
        return values.prefix(bandCount).enumerated().max(by: { $0.element < $1.element })?.offset
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(mode == .thirtyTwoBand ? String(localized: "eq_thirty_two_band") : String(localized: "eq_ten_band"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.56))

                Spacer()

                if let index = resolvedSelection {
                    Text("\(frequencyLabel(frequencies[index]))  ·  \(String(format: "%.1f dB", values[index]))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }

            GeometryReader { proxy in
                let minimumColumnWidth: CGFloat = mode == .thirtyTwoBand ? 28 : 24
                let contentWidth = max(proxy.size.width, CGFloat(max(1, bandCount)) * minimumColumnWidth)

                ScrollView(.horizontal, showsIndicators: mode == .thirtyTwoBand) {
                    ZStack(alignment: .bottomLeading) {
                        spectrumGrid
                        spectrumBands(columnWidth: contentWidth / CGFloat(max(1, bandCount)))
                    }
                    .frame(width: contentWidth, height: proxy.size.height)
                }
            }
        }
    }

    private var spectrumGrid: some View {
        GeometryReader { proxy in
            ForEach(0..<3, id: \.self) { index in
                Path { path in
                    let y = CGFloat(index) * (proxy.size.height - 21) / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                .stroke(Color.white.opacity(index == 2 ? 0.08 : 0.04), lineWidth: 1)
            }
        }
        .padding(.bottom, 21)
        .allowsHitTesting(false)
    }

    private func spectrumBands(columnWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<bandCount, id: \.self) { index in
                let value = values[index]
                let normalized = CGFloat(min(1, max(0.05, (value + 60) / 60)))
                let isSelected = resolvedSelection == index

                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        selectedIndex = index
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(isSelected ? accent : accent.opacity(0.5))
                            .frame(width: isSelected ? 5 : 3, height: 82 * normalized)
                            .frame(height: 82, alignment: .bottom)
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.18),
                                value: isSelected
                            )

                        Text(frequencyLabel(frequencies[index]))
                            .font(.system(size: 7.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                            .foregroundStyle(isSelected ? .white.opacity(0.86) : .white.opacity(0.54))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                    .frame(width: columnWidth)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func frequencyLabel(_ frequency: Float) -> String {
        if frequency >= 1_000 {
            let value = frequency / 1_000
            return value.rounded() == value
                ? String(format: "%.0fk", value)
                : String(format: "%.1fk", value)
        }
        return String(format: "%.0f", frequency)
    }
}

private struct AIEqualizerCurveView: View {
    let gains: [Float]
    let mode: GraphicEQMode
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let midY = proxy.size.height * 0.45
            let usableHeight = proxy.size.height * 0.34

            ZStack(alignment: .topLeading) {
                ForEach([-6, 0, 6], id: \.self) { gain in
                    let normalized = CGFloat(gain) / 9
                    let y = midY - normalized * usableHeight

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    .stroke(
                        Color.white.opacity(gain == 0 ? 0.1 : 0.045),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: gain == 0 ? [4, 4] : []
                        )
                    )
                }

                responsePath(
                    size: proxy.size,
                    midY: midY,
                    usableHeight: usableHeight
                )
                .trim(from: 0, to: revealProgress)
                .stroke(
                    accent,
                    style: StrokeStyle(
                        lineWidth: 2.25,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                ForEach(Array(gains.enumerated()), id: \.offset) { index, _ in
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(1, gains.count - 1))

                    if shouldShowLabel(at: index) {
                        Rectangle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 1, height: 5)
                            .position(x: x, y: proxy.size.height - 22)

                        Text(index < mode.frequencyLabels.count ? mode.frequencyLabels[index] : "")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.56))
                            .position(x: x, y: proxy.size.height - 9)
                    }
                }
            }
            .padding(.horizontal, 7)
        }
        .onAppear { revealCurve() }
        .onChange(of: gains) { _, _ in revealCurve() }
    }

    private func responsePath(
        size: CGSize,
        midY: CGFloat,
        usableHeight: CGFloat
    ) -> Path {
        let points = gains.enumerated().map { index, gain in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(max(1, gains.count - 1)),
                y: midY - CGFloat(min(9, max(-9, gain))) / 9 * usableHeight
            )
        }

        guard let first = points.first else { return Path() }

        var path = Path()
        path.move(to: first)
        guard points.count > 1 else { return path }

        guard points.count > 2 else {
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return path
        }

        let smoothing: CGFloat = 0.14
        for index in 0..<(points.count - 1) {
            let previous = points[max(0, index - 1)]
            let current = points[index]
            let next = points[index + 1]
            let following = points[min(points.count - 1, index + 2)]
            let firstControl = CGPoint(
                x: current.x + (next.x - previous.x) * smoothing,
                y: current.y + (next.y - previous.y) * smoothing
            )
            let secondControl = CGPoint(
                x: next.x - (following.x - current.x) * smoothing,
                y: next.y - (following.y - current.y) * smoothing
            )
            path.addCurve(
                to: next,
                control1: firstControl,
                control2: secondControl
            )
        }
        return path
    }

    private func shouldShowLabel(at index: Int) -> Bool {
        guard mode == .thirtyTwoBand else { return true }
        return index == gains.count - 1 || index.isMultiple(of: 4)
    }

    private func revealCurve() {
        revealProgress = reduceMotion ? 1 : 0
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.55)) {
            revealProgress = 1
        }
    }
}
