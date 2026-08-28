import SwiftUI
import FFmpegSwiftSDK

extension AIEqualizerLabView {

    var workspaceSwitcher: some View {
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

    var workspaceContent: AnyView {
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

    var tuningWorkspace: AnyView {
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

    var measurementWorkspace: AnyView {
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

    var resultWorkspace: AnyView {
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

    var historyWorkspace: AnyView {
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

    func workspaceHasContent(_ workspace: AIEqualizerWorkspace) -> Bool {
        switch workspace {
        case .tuning: return agent.phase.isWorking
        case .measurement: return agent.measuredFeatures != nil
        case .result: return agent.proposal != nil
        case .history: return !agent.savedProposals.isEmpty
        }
    }

}
