import SwiftUI
import UIKit

@MainActor
struct CrashDiagnosticsView: View {
    @ObservedObject private var store = CrashDiagnosticsStore.shared
    @State private var showsClearConfirmation = false
    @State private var showsShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ZStack {
            DeveloperDiagnosticBackdrop()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    DeveloperDiagnosticStatus(status: L10n.format("crash_diagnostics_count", store.records.count))

                    if store.records.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.records) { record in
                            NavigationLink {
                                CrashDiagnosticDetailView(recordID: record.id)
                            } label: {
                                recordRow(record)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                .padding(.top, 8)
                .iPadContentWidth(SettingsPageLayout.contentWidth)
            }
            .scrollIndicators(.hidden)
        }
        .developerDiagnosticPageChrome(title: String(localized: "crash_diagnostics_title"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: shareAll) {
                    MonoIcon(
                        icon: .share,
                        size: 15,
                        color: store.records.isEmpty ? .white.opacity(0.25) : .cyan
                    )
                    .frame(width: 44, height: 44)
                }
                .disabled(store.records.isEmpty)
                .accessibilityLabel(String(localized: "crash_diagnostics_share_action"))

                Button {
                    showsClearConfirmation = true
                } label: {
                    MonoIcon(
                        icon: .trash,
                        size: 15,
                        color: store.records.isEmpty ? .white.opacity(0.25) : .red
                    )
                    .frame(width: 44, height: 44)
                }
                .disabled(store.records.isEmpty)
                .accessibilityLabel(String(localized: "crash_diagnostics_clear_action"))
            }
        }
        .alert(
            String(localized: "crash_diagnostics_clear_title"),
            isPresented: $showsClearConfirmation
        ) {
            Button(String(localized: "alert_cancel"), role: .cancel) {}
            Button(String(localized: "crash_diagnostics_clear_action"), role: .destructive) {
                store.clear()
            }
        } message: {
            Text(String(localized: "crash_diagnostics_clear_message"))
        }
        .sheet(isPresented: $showsShareSheet) {
            CrashDiagnosticShareSheet(items: shareItems)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            MonoIcon(icon: .warning, size: 28, color: .red.opacity(0.9))
            Text(String(localized: "crash_diagnostics_empty_title"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(String(localized: "crash_diagnostics_empty_message"))
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 54)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func recordRow(_ record: CrashDiagnosticRecord) -> some View {
        HStack(spacing: 13) {
            MonoIcon(icon: .warning, size: 16, color: .red)
                .frame(width: 44, height: 44)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(record.terminationReason ?? String(localized: "crash_diagnostics_unknown_reason"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(record.periodEnd.crashDiagnosticDateText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.52))

                Text(recordMetadata(record))
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.34))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            MonoIcon(icon: .chevronRight, size: 12, color: .white.opacity(0.28))
        }
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
        }
    }

    private func recordMetadata(_ record: CrashDiagnosticRecord) -> String {
        var values = [record.appVersion]
        if let signal = record.signal {
            values.append("SIG \(signal)")
        }
        if let exceptionType = record.exceptionType {
            values.append("EXC \(exceptionType)")
        }
        return values.joined(separator: " · ")
    }

    private func shareAll() {
        guard let url = store.exportAllURL() else { return }
        shareItems = [url]
        showsShareSheet = true
    }
}

@MainActor
private struct CrashDiagnosticDetailView: View {
    @ObservedObject private var store = CrashDiagnosticsStore.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsShareSheet = false
    @State private var shareItems: [Any] = []

    let recordID: String

    private var record: CrashDiagnosticRecord? {
        store.records.first { $0.id == recordID }
    }

    var body: some View {
        ZStack {
            DeveloperDiagnosticBackdrop()

            if let record {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        DeveloperDiagnosticStatus(status: record.periodEnd.crashDiagnosticDateText)

                        detailSection(String(localized: "crash_diagnostics_summary")) {
                            valueRow(String(localized: "crash_diagnostics_version"), record.appVersion)
                            valueRow(
                                String(localized: "crash_diagnostics_period"),
                                "\(record.periodStart.crashDiagnosticDateText) – \(record.periodEnd.crashDiagnosticDateText)"
                            )
                            valueRow(
                                String(localized: "crash_diagnostics_termination_reason"),
                                record.terminationReason ?? "—"
                            )
                            valueRow(String(localized: "crash_diagnostics_signal"), record.signal.map(String.init) ?? "—")
                            valueRow(String(localized: "crash_diagnostics_exception_type"), record.exceptionType ?? "—")
                            valueRow(String(localized: "crash_diagnostics_exception_code"), record.exceptionCode ?? "—")
                        }

                        detailSection(String(localized: "crash_diagnostics_raw")) {
                            Text(record.diagnosticJSON)
                                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .padding(.top, 8)
                    .iPadContentWidth(SettingsPageLayout.contentWidth)
                }
                .scrollIndicators(.hidden)
            } else {
                Text(String(localized: "crash_diagnostics_record_missing"))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .developerDiagnosticPageChrome(title: String(localized: "crash_diagnostics_detail_title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: shareRecord) {
                    MonoIcon(icon: .share, size: 15, color: record == nil ? .white.opacity(0.25) : .cyan)
                        .frame(width: 44, height: 44)
                }
                .disabled(record == nil)
                .accessibilityLabel(String(localized: "crash_diagnostics_share_action"))
            }
        }
        .sheet(isPresented: $showsShareSheet) {
            CrashDiagnosticShareSheet(items: shareItems)
        }
    }

    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
        }
    }

    @ViewBuilder
    private func valueRow(_ title: String, _ value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                valueTitle(title)
                valueText(value)
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                valueTitle(title)
                    .frame(width: 112, alignment: .leading)
                valueText(value)
            }
        }
    }

    private func valueTitle(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.4))
    }

    private func valueText(_ value: String) -> some View {
        Text(value)
            .font(.caption.monospaced())
            .foregroundStyle(.white.opacity(0.72))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func shareRecord() {
        guard let record, let url = store.exportURL(for: record) else { return }
        shareItems = [url]
        showsShareSheet = true
    }
}

private struct CrashDiagnosticShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension Date {
    var crashDiagnosticDateText: String {
        formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
        )
    }
}
