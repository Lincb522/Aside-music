import SwiftUI
import FFmpegSwiftSDK

@MainActor
struct AIEqualizerLabView: View {
    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var agent = AIEqualizerAgent.shared
    @StateObject private var coverColors = CoverColorExtractor()

    private var accent: Color { normalizedAIEqualizerAccent(coverColors.dominantColor) }
    private var accentForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: accent,
            light: Color(hex: "111821"),
            dark: .white
        )
    }

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "ai_lab_title"),
                        eyebrow: "MONO AUDIO",
                        icon: .sparkle
                    )

                    VStack(alignment: .leading, spacing: 22) {
                        trackCard
                        automaticSection
                        samplingSection

                        if case let .sampling(progress) = agent.phase {
                            progressSection(
                                progress: progress,
                                title: agent.samplingStage.title,
                                stage: agent.samplingStage
                            )
                        } else if agent.phase == .requesting {
                            progressSection(
                                progress: nil,
                                title: agent.generationStage.title,
                                stage: nil
                            )
                        }

                        if let features = agent.measuredFeatures {
                            measurementSection(features)
                        }

                        if let proposal = agent.proposal {
                            proposalSection(proposal)
                        } else if case let .failed(message) = agent.phase {
                            failureSection(message)
                        }

                        serviceFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 44)
                    .iPadContentWidth(720)
                }
            }
        }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                MonologueToolbarBackButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                statusLabel
            }
        }
        .onAppear { refreshCoverAccent() }
        .onChange(of: player.currentSong?.id) { _, _ in refreshCoverAccent() }
    }

    private var trackCard: some View {
        Group {
            if let song = player.currentSong {
                HStack(spacing: 14) {
                    CachedAsyncImage(url: song.coverUrl?.sized(240), width: 72, height: 72) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(MonologueIcon(icon: .musicNote, size: 22, color: .white.opacity(0.45)))
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(song.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)

                        Text(agent.measuredFeatures?.outputDevice ?? EQManager.shared.currentOutputKind.title)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Button(action: primaryAnalysisAction) {
                        MonologueIcon(
                            icon: agent.phase.isWorking ? .close : .sparkle,
                            size: 17,
                            color: accentForeground
                        )
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(accent.opacity(0.72)))
                        .overlay(Circle().stroke(accent, lineWidth: 1))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
            } else {
                HStack(spacing: 14) {
                    MonologueIcon(icon: .musicNote, size: 22, color: .white.opacity(0.42))
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
        .padding(14)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        }
    }

    private var automaticSection: some View {
        section(title: String(localized: "ai_lab_automation")) {
            VStack(spacing: 0) {
                automationToggleRow(
                    title: String(localized: "ai_lab_auto_configure"),
                    isOn: $agent.automaticConfigurationEnabled
                )

                divider

                automationToggleRow(
                    title: String(localized: "ai_player_status_toggle"),
                    isOn: $agent.showsPlayerTuningStatus
                )
            }
            .background(cardBackground)
        }
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

    private var samplingSection: some View {
        section(title: String(localized: "ai_sampling_mode")) {
            VStack(spacing: 12) {
                HStack(spacing: 7) {
                    ForEach(AIEqualizerSamplingMode.allCases) { mode in
                        Button {
                            agent.samplingMode = mode
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Text(mode.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(agent.samplingMode == mode ? accentForeground : .white.opacity(0.62))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(agent.samplingMode == mode ? accent.opacity(0.78) : Color.white.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if agent.samplingMode == .custom {
                    HStack(spacing: 12) {
                        Slider(value: $agent.customSamplingDuration, in: 8...90, step: 1)
                            .tint(accent)

                        Text(String(format: String(localized: "ai_sampling_seconds"), Int(agent.customSamplingDuration)))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 54, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private func progressSection(
        progress: Double?,
        title: String,
        stage: AIEqualizerSamplingStage?
    ) -> some View {
        section(title: String(localized: "ai_lab_analysis_progress")) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    if let progress {
                        Text("\(Int(min(1, max(0, progress)) * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }

                if let progress, let stage {
                    AIEqualizerSamplingVisualizer(
                        progress: progress,
                        stage: stage,
                        accent: accent
                    )
                    .frame(height: 126)
                    .accessibilityHidden(true)
                } else {
                    AIEqualizerGenerationVisualizer(
                        stage: agent.generationStage,
                        accent: accent,
                        measuredBands: agent.measuredFeatures?.bandEnergyDB ?? []
                    )
                    .frame(height: 126)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func measurementSection(_ features: AIEqualizerAudioFeatures) -> some View {
        section(title: String(localized: "ai_lab_measured_parameters")) {
            VStack(spacing: 16) {
                SpectrumMeasurementView(values: features.bandEnergyDB, accent: accent)
                    .frame(height: 126)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    measurementCell(String(localized: "ai_lab_loudness"), String(format: "%.1f dBFS", features.rmsDBFS))
                    measurementCell(String(localized: "ai_lab_dynamic_range"), String(format: "%.1f dB", features.dynamicSpreadDB))
                    measurementCell(String(localized: "ai_lab_spectral_centroid"), frequencyText(features.spectralCentroidHz))
                    measurementCell(String(localized: "ai_lab_spectral_rolloff"), frequencyText(features.spectralRolloffHz))
                    measurementCell(String(localized: "ai_lab_spectral_flatness"), "\(Int(features.spectralFlatness * 100))%")
                    measurementCell(String(localized: "ai_lab_sample_rate"), String(format: "%.1f kHz", features.sampleRate / 1_000))
                    measurementCell(String(localized: "ai_lab_sample_duration"), String(format: "%.1f s", features.sampleDuration))
                    measurementCell(String(localized: "ai_lab_sample_frames"), "\(features.frameCount)")
                }
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private func measurementCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.045)))
    }

    private func proposalSection(_ proposal: AIEqualizerProposal) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            section(title: String(localized: "ai_lab_tuning_result")) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(proposal.profileName)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                            Text(proposal.summary)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.48))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Text("\(Int(proposal.confidence * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(accent)
                    }

                    AIEqualizerCurveView(gains: proposal.gains, accent: accent)
                        .frame(height: 174)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        resultCell(String(localized: "ai_lab_preamp"), String(format: "%.1f dB", proposal.preampDB))
                        resultCell(String(localized: "eq_processing_intensity"), String(format: "%.0f%%", proposal.professional.processingIntensity * 100))
                        resultCell(String(localized: "eq_bass"), String(format: "%+.1f dB", proposal.tone.bassGain))
                        resultCell(String(localized: "eq_treble"), String(format: "%+.1f dB", proposal.tone.trebleGain))
                        resultCell(String(localized: "eq_surround"), "\(Int(proposal.spatial.surroundLevel * 100))%")
                        resultCell(String(localized: "eq_reverb"), "\(Int(proposal.spatial.reverbLevel * 100))%")
                        resultCell(String(localized: "ai_lab_stereo_width"), String(format: "%.2fx", proposal.spatial.stereoWidth))
                        resultCell(String(localized: "ai_lab_confidence"), "\(Int(proposal.confidence * 100))%")
                    }
                }
                .padding(14)
                .background(cardBackground)
            }

            section(title: String(localized: "eq_mono_calibration")) {
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
                .padding(.horizontal, 14)
                .background(cardBackground)
            }

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
                .buttonStyle(MonologueBouncingButtonStyle())
                .disabled(agent.isCurrentProposalApplied)

                Button(action: agent.analyzeCurrentSong) {
                    MonologueIcon(icon: .refresh, size: 17, color: .white.opacity(0.86))
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }

    private func resultCell(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.44))
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

    private func failureSection(_ message: String) -> some View {
        section(title: String(localized: "ai_lab_failed")) {
            HStack(alignment: .top, spacing: 12) {
                MonologueIcon(icon: .warning, size: 17, color: .red.opacity(0.9))
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(cardBackground)
        }
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

    private var serviceFooter: some View {
        Text(String(localized: "ai_lab_service_credit"))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.34))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
            content()
        }
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
        Color(red: 0.055, green: 0.055, blue: 0.072)
    }

    private func refreshCoverAccent() {
        coverColors.extract(from: player.currentSong?.coverUrl?.sized(200).absoluteString)
    }

    private func primaryAnalysisAction() {
        agent.phase.isWorking ? agent.cancelAnalysis() : agent.analyzeCurrentSong()
    }

    private func frequencyText(_ frequency: Float) -> String {
        frequency >= 1_000
            ? String(format: "%.2f kHz", frequency / 1_000)
            : String(format: "%.0f Hz", frequency)
    }
}

private struct AIEqualizerSamplingVisualizer: View {
    let progress: Double
    let stage: AIEqualizerSamplingStage
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var normalizedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(
                AppFrameRate.throttledTimeline(
                    maximumFramesPerSecond: 20,
                    paused: reduceMotion
                )
            ) { timeline in
                Canvas { context, size in
                    drawWaveform(
                        in: &context,
                        size: size,
                        time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            }

            progressRail
        }
    }

    private var progressRail: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.1))

            Capsule()
                .fill(accent.opacity(0.88))
                .scaleEffect(
                    x: max(0.012, normalizedProgress),
                    y: 1,
                    anchor: .leading
                )
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.18),
                    value: normalizedProgress
                )
        }
        .frame(height: 2)
    }

    private func drawWaveform(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        guard size.width > 0, size.height > 0 else { return }

        let count = max(30, min(52, Int(size.width / 6.2)))
        let slotWidth = size.width / CGFloat(count)
        let barWidth = min(3.2, max(1.8, slotWidth * 0.4))
        let centerY = size.height * 0.5
        let maximumBarHeight = size.height * 0.74

        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: centerY))
        baseline.addLine(to: CGPoint(x: size.width, y: centerY))
        context.stroke(baseline, with: .color(.white.opacity(0.055)), lineWidth: 1)

        for index in 0..<count {
            let position = Double(index) / Double(max(1, count - 1))
            let height = maximumBarHeight * CGFloat(
                waveformHeight(at: position, index: index, time: time)
            )
            let x = slotWidth * (CGFloat(index) + 0.5)
            let rect = CGRect(
                x: x - barWidth * 0.5,
                y: centerY - height * 0.5,
                width: barWidth,
                height: height
            )
            let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.5)
            let captured = position <= normalizedProgress
            context.fill(
                path,
                with: .color(captured ? accent.opacity(0.82) : Color.white.opacity(0.11))
            )
        }
    }

    private func waveformHeight(at position: Double, index: Int, time: TimeInterval) -> Double {
        let staticTime = reduceMotion ? 0 : time
        let slow = sin(staticTime * 1.35 + position * 9.2)
        let detail = sin(staticTime * 2.15 + Double(index) * 0.71)

        switch stage {
        case .preparing:
            return 0.08 + 0.08 * abs(slow)
        case .waitingForAudio:
            return 0.06 + 0.055 * abs(sin(staticTime * 0.7 + position * 5))
        case .collectingSpectrum:
            let envelope = 0.58 + 0.42 * sin(position * .pi)
            return 0.12 + (0.46 * abs(slow) + 0.22 * abs(detail)) * envelope
        case .measuringDynamics:
            let broad = abs(sin(staticTime * 0.92 + position * 5.4))
            let envelope = 0.5 + 0.5 * sin(position * .pi)
            return 0.12 + 0.7 * broad * envelope
        case .organizingFeatures:
            let stepped = Double((index / 3) % 4) / 3
            return 0.16 + 0.34 * stepped + 0.08 * abs(slow)
        case .finalizing:
            let settled = 0.22 + 0.3 * sin(position * .pi)
            return settled + 0.025 * abs(detail)
        }
    }
}

private struct AIEqualizerGenerationVisualizer: View {
    let stage: AIEqualizerGenerationStage
    let accent: Color
    let measuredBands: [Float]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stageIndex: Int {
        switch stage {
        case .preparing: return 0
        case .generating: return 1
        case .validating: return 2
        case .finalizing: return 3
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(
                AppFrameRate.throttledTimeline(
                    maximumFramesPerSecond: 20,
                    paused: reduceMotion
                )
            ) { timeline in
                Canvas { context, size in
                    drawEqualizerCurve(
                        in: &context,
                        size: size,
                        time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            }

            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index <= stageIndex ? accent.opacity(0.88) : Color.white.opacity(0.1))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 2)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.22),
                value: stageIndex
            )
        }
    }

    private func drawEqualizerCurve(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        guard size.width > 0, size.height > 0 else { return }

        let horizontalInset: CGFloat = 6
        let topInset: CGFloat = 8
        let bottomInset: CGFloat = 8
        let plotWidth = max(1, size.width - horizontalInset * 2)
        let plotHeight = max(1, size.height - topInset - bottomInset)
        let centerY = topInset + plotHeight * 0.5
        let target = curveTarget()
        let settlement: Double
        let movement: Double

        switch stage {
        case .preparing:
            settlement = 0.16
            movement = 0.11
        case .generating:
            settlement = 0.54
            movement = 0.075
        case .validating:
            settlement = 0.86
            movement = 0.025
        case .finalizing:
            settlement = 1
            movement = 0
        }

        for lineIndex in 0..<3 {
            let y = topInset + plotHeight * CGFloat(lineIndex) * 0.5
            var line = Path()
            line.move(to: CGPoint(x: horizontalInset, y: y))
            line.addLine(to: CGPoint(x: size.width - horizontalInset, y: y))
            context.stroke(
                line,
                with: .color(.white.opacity(lineIndex == 1 ? 0.09 : 0.045)),
                lineWidth: 1
            )
        }

        let points = target.enumerated().map { index, targetValue -> CGPoint in
            let position = Double(index) / Double(target.count - 1)
            let motion = reduceMotion
                ? 0
                : sin(time * 1.15 + Double(index) * 0.82) * movement
            let value = targetValue * settlement + motion
            return CGPoint(
                x: horizontalInset + plotWidth * CGFloat(position),
                y: centerY - plotHeight * CGFloat(value)
            )
        }

        var curve = Path()
        if let first = points.first {
            curve.move(to: first)
            for index in 1..<points.count {
                let previous = points[index - 1]
                let point = points[index]
                let middleX = (previous.x + point.x) * 0.5
                curve.addCurve(
                    to: point,
                    control1: CGPoint(x: middleX, y: previous.y),
                    control2: CGPoint(x: middleX, y: point.y)
                )
            }
        }
        context.stroke(
            curve,
            with: .color(accent.opacity(0.88)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )

        let activeNodeCount = min(points.count, [2, 6, 9, 10][stageIndex])
        for (index, point) in points.enumerated() {
            let radius: CGFloat = index < activeNodeCount ? 2.6 : 1.8
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: point.x - radius,
                        y: point.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                ),
                with: .color(
                    index < activeNodeCount
                        ? accent.opacity(0.94)
                        : Color.white.opacity(0.16)
                )
            )
        }
    }

    private func curveTarget() -> [Double] {
        let values = Array(measuredBands.prefix(10))
        guard values.count == 10 else {
            return [0.05, -0.12, -0.2, -0.08, 0.1, 0.19, 0.12, -0.02, -0.14, -0.04]
        }

        let mean = values.reduce(Float(0), +) / Float(values.count)
        return values.map { value in
            min(0.24, max(-0.24, Double(mean - value) / 24 * 0.22))
        }
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

    guard ThemeColorCustomization.contrastRatio(between: candidate, and: background) < 3 else {
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
    let accent: Color
    private let bands = EQBand.allCases

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = proxy.size.width / CGFloat(max(1, values.count))
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let normalized = CGFloat(min(1, max(0.04, (value + 60) / 60)))
                    VStack(spacing: 5) {
                        Text(String(format: "%.0f", value))
                            .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.34))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.38), accent],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: max(4, columnWidth * 0.34), height: 70 * normalized)
                            .frame(height: 70, alignment: .bottom)

                        Text(index < bands.count ? bands[index].label : "")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.42))
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct AIEqualizerCurveView: View {
    let gains: [Float]
    let accent: Color
    private let bands = EQBand.allCases

    var body: some View {
        GeometryReader { proxy in
            let midY = proxy.size.height * 0.45
            let usableHeight = proxy.size.height * 0.34

            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: midY))
                }
                .stroke(Color.white.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Path { path in
                    guard !gains.isEmpty else { return }
                    for index in gains.indices {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(max(1, gains.count - 1))
                        let normalized = CGFloat(min(6, max(-6, gains[index]))) / 6
                        let y = midY - normalized * usableHeight
                        if index == gains.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(Array(gains.enumerated()), id: \.offset) { index, gain in
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(1, gains.count - 1))
                    let normalized = CGFloat(min(6, max(-6, gain))) / 6
                    let y = midY - normalized * usableHeight

                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                        .position(x: x, y: y)

                    Text(index < bands.count ? bands[index].label : "")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                        .position(x: x, y: proxy.size.height - 9)
                }
            }
            .padding(.horizontal, 7)
        }
    }
}
