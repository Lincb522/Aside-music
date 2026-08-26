import SwiftUI

@MainActor
struct MonoAudioAdaptiveLearningView: View {
    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var agent = AIEqualizerAgent.shared
    @State private var selectedFilter: LearningRecordFilter = .all
    @State private var showsClearConfirmation = false

    let accent: Color

    private var filteredRecords: [AIEqualizerLearningRecord] {
        agent.learningRecords.filter(selectedFilter.includes)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = MonoSoundCenterLayout(size: proxy.size)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: layout.isCompactHeight ? 18 : 24) {
                        header(layout: layout)
                        learningSettings(layout: layout)
                        learningSources(layout: layout)
                        storageNotice
                        learningRecords(layout: layout)
                    }
                    .padding(.horizontal, layout.horizontalInset)
                    .padding(.top, layout.isCompactHeight ? 8 : 12)
                    .padding(.bottom, layout.isCompactHeight ? 24 : 36)
                    .frame(width: layout.workspaceMaxWidth)
                }
                .frame(width: layout.contentMaxWidth)

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .background { learningBackdrop }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .navigationTitle(String(localized: "audio_agent_learning_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .monoNavigationBackButton(iconColor: .white)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsClearConfirmation = true
                } label: {
                    MonoIcon(
                        icon: .trash,
                        size: 15,
                        color: agent.learningRecords.isEmpty ? .white.opacity(0.25) : .red
                    )
                    .frame(width: 44, height: 44)
                }
                .disabled(agent.learningRecords.isEmpty)
                .accessibilityLabel(String(localized: "ai_learning_clear_action"))
            }
        }
        .alert(
            String(localized: "ai_learning_clear_title"),
            isPresented: $showsClearConfirmation
        ) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(String(localized: "ai_learning_clear_action"), role: .destructive) {
                agent.clearLearningHistory()
            }
        } message: {
            Text(String(localized: "ai_learning_clear_message"))
        }
    }

    private func header(layout: MonoSoundCenterLayout) -> some View {
        HStack(spacing: 14) {
            MonoIcon(icon: .history, size: 22, color: accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "ai_learning_title"))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(learningSummary)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(agent.adaptiveLearningEnabled
                 ? String(localized: "audio_agent_learning_enabled_status")
                 : String(localized: "settings_off"))
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(agent.adaptiveLearningEnabled ? accent : .white.opacity(0.42))
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(Color.black.opacity(0.25), in: Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .padding(.vertical, layout.isCompactHeight ? 2 : 4)
    }

    private func learningSettings(layout: MonoSoundCenterLayout) -> some View {
        settingsSection(
            title: String(localized: "audio_agent_learning_general"),
            layout: layout
        ) {
            toggleRow(
                icon: .sparkle,
                title: String(localized: "ai_learning_enabled"),
                detail: String(localized: "audio_agent_learning_enabled_detail"),
                isOn: $agent.adaptiveLearningEnabled,
                layout: layout
            )

            rowDivider

            menuRow(
                icon: .equalizer,
                title: String(localized: "audio_agent_learning_strength"),
                detail: String(localized: "audio_agent_learning_strength_detail"),
                value: agent.learningStrength.localizedTitle,
                layout: layout
            ) {
                ForEach(AIEqualizerLearningStrength.allCases) { strength in
                    Button {
                        agent.learningStrength = strength
                    } label: {
                        if strength == agent.learningStrength {
                            Label(strength.localizedTitle, systemImage: "checkmark")
                        } else {
                            Text(strength.localizedTitle)
                        }
                    }
                }
            }
            .disabled(!agent.adaptiveLearningEnabled)
            .opacity(agent.adaptiveLearningEnabled ? 1 : 0.45)

            rowDivider

            menuRow(
                icon: .clock,
                title: String(localized: "audio_agent_learning_retention"),
                detail: String(localized: "audio_agent_learning_retention_detail"),
                value: agent.learningRetention.localizedTitle,
                layout: layout
            ) {
                ForEach(AIEqualizerLearningRetention.allCases) { retention in
                    Button {
                        agent.learningRetention = retention
                    } label: {
                        if retention == agent.learningRetention {
                            Label(retention.localizedTitle, systemImage: "checkmark")
                        } else {
                            Text(retention.localizedTitle)
                        }
                    }
                }
            }
        }
    }

    private func learningSources(layout: MonoSoundCenterLayout) -> some View {
        settingsSection(
            title: String(localized: "audio_agent_learning_sources"),
            layout: layout
        ) {
            toggleRow(
                icon: .checkmark,
                title: String(localized: "audio_agent_learning_source_feedback"),
                detail: String(localized: "audio_agent_learning_source_feedback_detail"),
                isOn: $agent.learnsFromExplicitFeedback,
                layout: layout
            )
            rowDivider
            toggleRow(
                icon: .playCircle,
                title: String(localized: "audio_agent_learning_source_listening"),
                detail: String(localized: "audio_agent_learning_source_listening_detail"),
                isOn: $agent.learnsFromListeningBehavior,
                layout: layout
            )
            rowDivider
            toggleRow(
                icon: .refresh,
                title: String(localized: "audio_agent_learning_source_adjustments"),
                detail: String(localized: "audio_agent_learning_source_adjustments_detail"),
                isOn: $agent.learnsFromAdjustmentActions,
                layout: layout
            )
        }
        .disabled(!agent.adaptiveLearningEnabled)
        .opacity(agent.adaptiveLearningEnabled ? 1 : 0.45)
    }

    private var storageNotice: some View {
        HStack(alignment: .top, spacing: 11) {
            MonoIcon(icon: .storage, size: 16, color: accent)
                .frame(width: 22)
            Text(String(localized: "audio_agent_learning_storage_notice"))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(sectionSurface)
    }

    private func learningRecords(layout: MonoSoundCenterLayout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(localized: "audio_agent_learning_records"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))

                Spacer(minLength: 8)

                Text(
                    String(
                        format: String(localized: "audio_agent_learning_record_count"),
                        agent.learningRecords.count
                    )
                )
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            }

            filterBar

            VStack(spacing: 0) {
                if filteredRecords.isEmpty {
                    emptyRecords
                } else {
                    ForEach(Array(filteredRecords.enumerated()), id: \.element.id) { index, record in
                        NavigationLink {
                            MonoAudioLearningRecordDetailView(recordID: record.id, accent: accent)
                        } label: {
                            recordRow(record, layout: layout)
                        }
                        .buttonStyle(.plain)

                        if index < filteredRecords.count - 1 {
                            rowDivider
                        }
                    }
                }
            }
            .padding(.horizontal, layout.isCompactWidth ? 12 : 14)
            .background(sectionSurface)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(LearningRecordFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.localizedTitle)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(selectedFilter == filter ? .black.opacity(0.82) : .white.opacity(0.58))
                            .padding(.horizontal, 13)
                            .frame(minHeight: 32)
                            .background(
                                selectedFilter == filter ? accent.opacity(0.9) : Color.white.opacity(0.055),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var emptyRecords: some View {
        VStack(spacing: 10) {
            MonoIcon(icon: .history, size: 24, color: accent.opacity(0.85))
            Text(String(localized: "audio_agent_learning_empty_title"))
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.86))
            Text(String(localized: "audio_agent_learning_empty_message"))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.44))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
    }

    private func recordRow(
        _ record: AIEqualizerLearningRecord,
        layout: MonoSoundCenterLayout
    ) -> some View {
        HStack(spacing: 12) {
            MonoIcon(icon: record.feedback.icon, size: 16, color: record.feedback.tint)
                .frame(width: 40, height: 40)
                .background(record.feedback.tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(record.displayTitle)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)

                    Text(record.feedback.localizedTitle)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(record.feedback.tint)
                        .padding(.horizontal, 7)
                        .frame(minHeight: 20)
                        .background(record.feedback.tint.opacity(0.1), in: Capsule())
                }

                Text(record.secondaryText)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)

                Text(record.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer(minLength: 5)
            MonoIcon(icon: .chevronRight, size: 11, color: .white.opacity(0.28))
        }
        .padding(.vertical, layout.isCompactHeight ? 11 : 13)
        .contentShape(Rectangle())
    }

    private func toggleRow(
        icon: MonoIcon.IconType,
        title: String,
        detail: String,
        isOn: Binding<Bool>,
        layout: MonoSoundCenterLayout
    ) -> some View {
        HStack(spacing: 12) {
            MonoIcon(icon: icon, size: 17, color: accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(detail)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.vertical, layout.isCompactHeight ? 11 : 13)
    }

    private func menuRow<MenuContent: View>(
        icon: MonoIcon.IconType,
        title: String,
        detail: String,
        value: String,
        layout: MonoSoundCenterLayout,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        Menu(content: menuContent) {
            HStack(spacing: 12) {
                MonoIcon(icon: icon, size: 17, color: accent).frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(detail)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.82))
                    .multilineTextAlignment(.trailing)
                MonoIcon(icon: .chevronRight, size: 11, color: .white.opacity(0.3))
            }
            .padding(.vertical, layout.isCompactHeight ? 11 : 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func settingsSection<Content: View>(
        title: String,
        layout: MonoSoundCenterLayout,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))
            VStack(spacing: 0) { content() }
                .padding(.horizontal, layout.isCompactWidth ? 12 : 14)
                .background(sectionSurface)
        }
    }

    private var sectionSurface: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color.black.opacity(0.24))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 34)
    }

    private var learningSummary: String {
        String(
            format: String(localized: "audio_agent_learning_summary"),
            agent.learningRecords.filter { $0.feedback == .positive }.count,
            agent.learningRecords.filter { $0.feedback == .negative }.count,
            agent.learningRecords.filter { $0.feedback == .manualEqualizer }.count,
            agent.learningRecords.filter { $0.feedback.isAutomatic }.count
        )
    }

    private var learningBackdrop: some View {
        ZStack {
            Color(red: 0.035, green: 0.038, blue: 0.048)

            if let url = player.currentSong?.coverUrl?.sized(720) {
                CachedAsyncImage(url: url) { Color.clear }
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(1.16)
                    .blur(radius: 70)
                    .saturation(0.72)
                    .opacity(0.22)
                    .clipped()
            }

            Color.black.opacity(0.58)
        }
        .ignoresSafeArea()
    }
}

@MainActor
private struct MonoAudioLearningRecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var agent = AIEqualizerAgent.shared
    @State private var showsDeleteConfirmation = false

    let recordID: UUID
    let accent: Color

    private var record: AIEqualizerLearningRecord? {
        agent.learningRecords.first { $0.id == recordID }
    }

    var body: some View {
        ZStack {
            detailBackdrop

            if let record {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        detailHeader(record)
                        summarySection(record)
                        contextSection(record)
                        parameterSection(record)
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                    .iPadContentWidth(SettingsPageLayout.contentWidth)
                }
            } else {
                Text(String(localized: "audio_agent_learning_record_missing"))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .navigationTitle(String(localized: "audio_agent_learning_record_detail_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .monoNavigationBackButton(iconColor: .white)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsDeleteConfirmation = true
                } label: {
                    MonoIcon(icon: .trash, size: 15, color: record == nil ? .white.opacity(0.25) : .red)
                        .frame(width: 44, height: 44)
                }
                .disabled(record == nil)
                .accessibilityLabel(String(localized: "audio_agent_learning_delete_record"))
            }
        }
        .alert(
            String(localized: "audio_agent_learning_delete_record_title"),
            isPresented: $showsDeleteConfirmation
        ) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(String(localized: "delete"), role: .destructive) {
                agent.deleteLearningRecord(id: recordID)
                dismiss()
            }
        } message: {
            Text(String(localized: "audio_agent_learning_delete_record_message"))
        }
    }

    private func detailHeader(_ record: AIEqualizerLearningRecord) -> some View {
        HStack(spacing: 14) {
            MonoIcon(icon: record.feedback.icon, size: 20, color: record.feedback.tint)
                .frame(width: 48, height: 48)
                .background(record.feedback.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.displayTitle)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(record.feedback.localizedTitle)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(record.feedback.tint)
            }

            Spacer(minLength: 0)
        }
    }

    private func summarySection(_ record: AIEqualizerLearningRecord) -> some View {
        detailSection(String(localized: "audio_agent_learning_record_summary")) {
            detailValueRow(String(localized: "audio_agent_learning_record_artist"), record.artist)
            detailDivider
            detailValueRow(String(localized: "audio_agent_learning_record_source"), record.songIdentifier)
            detailDivider
            detailValueRow(String(localized: "audio_agent_learning_record_output"), record.displayOutput)
            detailDivider
            detailValueRow(
                String(localized: "audio_agent_learning_record_feedback"),
                record.feedback.localizedTitle
            )
            if record.feedback != .manualEqualizer {
                detailDivider
                detailValueRow(
                    String(localized: "audio_agent_learning_record_listened"),
                    record.listenedSeconds.localizedDuration
                )
            }
            detailDivider
            detailValueRow(
                String(localized: "audio_agent_learning_record_time"),
                record.recordedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }

    @ViewBuilder
    private func contextSection(_ record: AIEqualizerLearningRecord) -> some View {
        if !record.genreHints.isEmpty || !record.instrumentHints.isEmpty {
            detailSection(String(localized: "audio_agent_learning_record_context")) {
                if !record.genreHints.isEmpty {
                    detailValueRow(
                        String(localized: "audio_agent_learning_record_genres"),
                        record.genreHints.joined(separator: " · ")
                    )
                }
                if !record.genreHints.isEmpty, !record.instrumentHints.isEmpty {
                    detailDivider
                }
                if !record.instrumentHints.isEmpty {
                    detailValueRow(
                        String(localized: "audio_agent_learning_record_instruments"),
                        record.instrumentHints.joined(separator: " · ")
                    )
                }
            }
        }
    }

    private func parameterSection(_ record: AIEqualizerLearningRecord) -> some View {
        detailSection(String(localized: "audio_agent_learning_record_parameters")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "audio_agent_learning_record_eq_curve"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.54))

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 70), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(Array(record.graphicEQMode.frequencyLabels.enumerated()), id: \.offset) { index, label in
                        VStack(spacing: 3) {
                            Text(label)
                                .font(.system(.caption2, design: .monospaced, weight: .medium))
                                .foregroundStyle(.white.opacity(0.42))
                            Text(record.gainText(at: index))
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.vertical, 12)

            if record.feedback == .manualEqualizer {
                detailDivider
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "audio_agent_learning_record_manual_offsets"))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.54))

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 70), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(Array(record.graphicEQMode.frequencyLabels.enumerated()), id: \.offset) { index, label in
                            VStack(spacing: 3) {
                                Text(label)
                                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.42))
                                Text(record.learnedAdjustmentText(at: index))
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .foregroundStyle(accent.opacity(0.88))
                            }
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.vertical, 12)
            } else {
                detailDivider
                detailValueRow(String(localized: "audio_agent_learning_record_bass"), record.bassGain.decibelText)
                detailDivider
                detailValueRow(String(localized: "audio_agent_learning_record_treble"), record.trebleGain.decibelText)
                detailDivider
                detailValueRow(String(localized: "audio_agent_learning_record_surround"), record.surroundLevel.decimalText)
                detailDivider
                detailValueRow(String(localized: "audio_agent_learning_record_reverb"), record.reverbLevel.decimalText)
                detailDivider
                detailValueRow(String(localized: "audio_agent_learning_record_width"), record.stereoWidth.decimalText)
                detailDivider
                detailValueRow(
                    String(localized: "audio_agent_learning_record_processing"),
                    record.processingIntensity.decimalText
                )
            }
        }
    }

    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 0) { content() }
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }
                )
        }
    }

    private func detailValueRow(_ title: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(title)
                    .foregroundStyle(.white.opacity(0.54))
                Spacer(minLength: 12)
                Text(value)
                    .foregroundStyle(.white.opacity(0.84))
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .foregroundStyle(.white.opacity(0.54))
                Text(value)
                    .foregroundStyle(.white.opacity(0.84))
            }
        }
        .font(.system(.caption, design: .rounded, weight: .medium))
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
    }

    private var detailDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    private var detailBackdrop: some View {
        ZStack {
            Color(red: 0.035, green: 0.038, blue: 0.048)
            if let url = player.currentSong?.coverUrl?.sized(720) {
                CachedAsyncImage(url: url) { Color.clear }
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(1.16)
                    .blur(radius: 70)
                    .saturation(0.72)
                    .opacity(0.22)
                    .clipped()
            }
            Color.black.opacity(0.58)
        }
        .ignoresSafeArea()
    }
}

private enum LearningRecordFilter: String, CaseIterable, Identifiable {
    case all
    case positive
    case negative
    case manual
    case automatic

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all: return String(localized: "audio_agent_learning_filter_all")
        case .positive: return String(localized: "audio_agent_learning_filter_positive")
        case .negative: return String(localized: "audio_agent_learning_filter_negative")
        case .manual: return String(localized: "audio_agent_learning_filter_manual")
        case .automatic: return String(localized: "audio_agent_learning_filter_automatic")
        }
    }

    func includes(_ record: AIEqualizerLearningRecord) -> Bool {
        switch self {
        case .all: return true
        case .positive: return record.feedback == .positive
        case .negative: return record.feedback == .negative
        case .manual: return record.feedback == .manualEqualizer
        case .automatic: return record.feedback.isAutomatic
        }
    }
}

private extension AIEqualizerLearningStrength {
    var localizedTitle: String {
        switch self {
        case .cautious: return String(localized: "audio_agent_learning_strength_cautious")
        case .balanced: return String(localized: "audio_agent_learning_strength_balanced")
        case .responsive: return String(localized: "audio_agent_learning_strength_responsive")
        }
    }
}

private extension AIEqualizerLearningRetention {
    var localizedTitle: String {
        switch self {
        case .thirtyDays: return String(localized: "audio_agent_learning_retention_30")
        case .ninetyDays: return String(localized: "audio_agent_learning_retention_90")
        case .oneYear: return String(localized: "audio_agent_learning_retention_365")
        }
    }
}

private extension AIEqualizerLearningFeedback {
    var localizedTitle: String {
        switch self {
        case .positive: return String(localized: "audio_agent_learning_feedback_positive")
        case .negative: return String(localized: "audio_agent_learning_feedback_negative")
        case .retained: return String(localized: "audio_agent_learning_feedback_retained")
        case .reset: return String(localized: "audio_agent_learning_feedback_reset")
        case .regenerated: return String(localized: "audio_agent_learning_feedback_regenerated")
        case .manualEqualizer: return String(localized: "audio_agent_learning_feedback_manual_equalizer")
        }
    }

    var isAutomatic: Bool {
        self == .retained || self == .reset || self == .regenerated
    }

    var tint: Color {
        switch self {
        case .positive: return .green
        case .negative: return .orange
        case .retained: return .cyan
        case .reset: return .red
        case .regenerated: return .purple
        case .manualEqualizer: return .blue
        }
    }

    var icon: MonoIcon.IconType {
        switch self {
        case .positive: return .checkmark
        case .negative: return .heartSlash
        case .retained: return .playCircle
        case .reset: return .refresh
        case .regenerated: return .sparkle
        case .manualEqualizer: return .equalizer
        }
    }
}

private extension AIEqualizerLearningRecord {
    var displayTitle: String {
        guard let songTitle, !songTitle.isEmpty else {
            return String(localized: "audio_agent_learning_unknown_track")
        }
        return songTitle
    }

    var secondaryText: String {
        [artist, displayOutput]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var displayOutput: String {
        let baseIdentity = outputIdentity.split(separator: "|", maxSplits: 1).first.map(String.init)
            ?? outputIdentity
        let parts = baseIdentity.split(separator: ":", maxSplits: 1).map(String.init)
        return parts.count == 2 && !parts[1].isEmpty ? parts[1] : baseIdentity
    }

    func gainText(at index: Int) -> String {
        guard gains.indices.contains(index) else { return "—" }
        return gains[index].decibelText
    }

    func learnedAdjustmentText(at index: Int) -> String {
        guard learnedBandAdjustments.indices.contains(index) else { return "—" }
        return learnedBandAdjustments[index].decibelText
    }
}

private extension Float {
    var decibelText: String {
        String(format: "%+.1f dB", self)
    }

    var decimalText: String {
        String(format: "%.2f", self)
    }
}

private extension TimeInterval {
    var localizedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self >= 3_600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: max(0, self)) ?? "—"
    }
}
