import SwiftUI

@MainActor
struct AIProviderDeveloperSettingsView: View {
    private enum TestState: Equatable {
        case idle
        case testing
        case passed
        case failed(String)
    }

    @ObservedObject private var store = AIProviderConfigurationStore.shared
    @ObservedObject private var usageLimiter = AIUsageLimiter.shared
    @State private var testState: TestState = .idle
    @State private var discoveredModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelDiscoveryError: String?
    @State private var modelDiscoveryRequestID = UUID()

    private let client = AIProviderClient()

    var body: some View {
        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                VStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "ai_provider_settings_title"),
                        eyebrow: "AI PROVIDER",
                        icon: .sparkle
                    )

                    VStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                        SettingsSection(title: String(localized: "ai_provider_protocol_section")) {
                            providerRow

                            if store.wireProtocol.supportsCustomEndpoint {
                                developerDivider
                                inputRow(
                                    title: String(localized: "ai_provider_endpoint"),
                                    text: $store.baseURL,
                                    secure: false,
                                    prompt: store.wireProtocol.defaultBaseURL
                                )
                            }

                            developerDivider
                            modelRow

                            if store.wireProtocol != .appleIntelligence {
                                developerDivider
                                inputRow(
                                    title: "API Key",
                                    text: $store.apiKey,
                                    secure: true,
                                    prompt: "sk-…"
                                )
                            }
                        }

                        if store.wireProtocol.supportsCustomEndpoint {
                            SettingsSection(title: String(localized: "ai_provider_request_section")) {
                                timeoutRow
                                developerDivider
                                inputRow(
                                    title: String(localized: "ai_provider_headers"),
                                    text: $store.customHeadersJSON,
                                    secure: false,
                                    prompt: "{\"Header\":\"Value\"}"
                                )

                                developerDivider
                                inputRow(
                                    title: String(localized: "ai_provider_model_list_endpoint"),
                                    text: $store.modelDiscoveryURL,
                                    secure: false,
                                    prompt: String(localized: "ai_provider_automatic")
                                )
                            }
                        }

                        SettingsSection(title: String(localized: "ai_usage_limits_section")) {
                            integerLimitRow(
                                title: String(localized: "ai_usage_daily_limit"),
                                value: $store.dailyRequestLimit,
                                range: 0...10_000
                            )

                            developerDivider

                            integerLimitRow(
                                title: String(localized: "ai_usage_hourly_limit"),
                                value: $store.hourlyRequestLimit,
                                range: 0...1_000
                            )

                            developerDivider

                            intervalLimitRow

                            developerDivider

                            usageStatusRow

                            developerDivider

                            SettingsButtonRow(
                                icon: .trash,
                                title: String(localized: "ai_usage_reset"),
                                action: usageLimiter.reset
                            )
                        }

                        SettingsSection(title: String(localized: "ai_provider_connection_section")) {
                            SettingsInfoRow(
                                icon: testStateIcon,
                                title: String(localized: "ai_provider_connection_status"),
                                value: testStateText
                            )

                            developerDivider

                            SettingsButtonRow(
                                icon: .refresh,
                                title: String(localized: "ai_provider_test"),
                                action: testConnection
                            )
                            .disabled(testState == .testing)

                            developerDivider

                            SettingsButtonRow(
                                icon: .refresh,
                                title: String(localized: "ai_provider_reset"),
                                action: resetConfiguration
                            )
                        }

                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .iPadContentWidth(SettingsPageLayout.contentWidth)
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: SettingsPageLayout.scrollCoordinateSpace)
            .themeRenderScrollLayer()
        }
        .asideSettingsDetailChrome(String(localized: "ai_provider_settings_title"))
        .onAppear {
            usageLimiter.refresh()
        }
        .task(id: modelDiscoveryFingerprint) {
            await fetchModels(automatic: true)
        }
    }

    private var providerRow: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: .sparkle)
            Text(String(localized: "ai_provider_protocol"))
                .font(.rounded(size: 15, weight: .medium))
                .foregroundColor(.monologueTextPrimary)
            Spacer()
            Menu {
                Picker("", selection: providerSelection) {
                    ForEach(AIWireProtocol.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(store.wireProtocol.title)
                        .lineLimit(1)
                    MonologueIcon(icon: .chevronDown, size: 10, color: .monologueTextSecondary)
                }
                .font(.rounded(size: 13, weight: .medium))
                .foregroundColor(.monologueTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var providerSelection: Binding<AIWireProtocol> {
        Binding(
            get: { store.wireProtocol },
            set: { value in
                store.wireProtocol = value
                store.useProtocolDefaults()
                discoveredModels = []
                modelDiscoveryError = nil
                testState = .idle
            }
        )
    }

    private var modelRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(String(localized: "ai_provider_model"))
                    .font(.rounded(size: 13, weight: .semibold))
                    .foregroundColor(.monologueTextSecondary)
                Spacer()
                if isLoadingModels {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await fetchModels() }
                    } label: {
                        MonologueIcon(icon: .refresh, size: 13, color: .monologueTextSecondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                TextField(store.wireProtocol.defaultModel, text: $store.model)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.monologueTextPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !discoveredModels.isEmpty {
                    Menu {
                        ForEach(discoveredModels, id: \.self) { model in
                            Button(model) { store.model = model }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text("\(discoveredModels.count)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            MonologueIcon(icon: .chevronDown, size: 10, color: .monologueTextSecondary)
                        }
                        .foregroundColor(.monologueTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.monologueSeparator.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            if let modelDiscoveryError {
                Text(modelDiscoveryError)
                    .font(.rounded(size: 11, weight: .medium))
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else if !discoveredModels.isEmpty {
                Text(String(format: String(localized: "ai_provider_models_loaded"), discoveredModels.count))
                    .font(.rounded(size: 11, weight: .medium))
                    .foregroundColor(.monologueTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private func inputRow(
        title: String,
        text: Binding<String>,
        secure: Bool,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.rounded(size: 13, weight: .semibold))
                .foregroundColor(.monologueTextSecondary)

            Group {
                if secure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                }
            }
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .foregroundColor(.monologueTextPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.monologueSeparator.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var timeoutRow: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: .clock)
            Text(String(localized: "ai_provider_timeout"))
                .font(.rounded(size: 15, weight: .medium))
                .foregroundColor(.monologueTextPrimary)
            Spacer()
            Stepper(value: $store.timeout, in: 10...120, step: 5) {
                Text("\(Int(store.timeout))s")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.monologueTextSecondary)
                    .frame(minWidth: 42, alignment: .trailing)
            }
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func integerLimitRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.rounded(size: 15, weight: .medium))
                .foregroundColor(.monologueTextPrimary)
            Spacer()
            Stepper(value: value, in: range) {
                Text(value.wrappedValue == 0
                     ? String(localized: "ai_usage_unlimited")
                     : "\(value.wrappedValue)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.monologueTextSecondary)
                    .frame(minWidth: 48, alignment: .trailing)
            }
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var intervalLimitRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "ai_usage_minimum_interval"))
                .font(.rounded(size: 15, weight: .medium))
                .foregroundColor(.monologueTextPrimary)
            Spacer()
            Stepper(value: $store.minimumRequestInterval, in: 0...3_600, step: 5) {
                Text(store.minimumRequestInterval == 0
                     ? String(localized: "ai_usage_unlimited")
                     : "\(Int(store.minimumRequestInterval))s")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.monologueTextSecondary)
                    .frame(minWidth: 54, alignment: .trailing)
            }
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var usageStatusRow: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: .chart)
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "ai_usage_current"))
                    .font(.rounded(size: 15, weight: .medium))
                    .foregroundColor(.monologueTextPrimary)
                Text(String(
                    format: String(localized: "ai_usage_current_format"),
                    usageLimiter.snapshot.usedToday,
                    usageLimiter.snapshot.usedThisHour
                ))
                .font(.rounded(size: 11, weight: .medium))
                .foregroundColor(.monologueTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var modelDiscoveryFingerprint: String {
        [
            store.wireProtocol.rawValue,
            store.baseURL,
            store.modelDiscoveryURL,
            String(store.apiKey.hashValue)
        ].joined(separator: "|")
    }

    private func fetchModels(automatic: Bool = false) async {
        if automatic {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
        }

        let normalizedKey = store.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if automatic, store.wireProtocol.requiresAPIKey, normalizedKey.isEmpty {
            discoveredModels = []
            modelDiscoveryError = nil
            return
        }

        let requestID = UUID()
        modelDiscoveryRequestID = requestID
        isLoadingModels = true
        modelDiscoveryError = nil
        defer {
            if modelDiscoveryRequestID == requestID {
                isLoadingModels = false
            }
        }

        do {
            let values = try await client.fetchModels(
                configuration: store.configuration,
                apiKey: store.apiKey
            )
            guard !Task.isCancelled, modelDiscoveryRequestID == requestID else { return }
            discoveredModels = values
            let current = store.model.trimmingCharacters(in: .whitespacesAndNewlines)
            if current.isEmpty || (!values.isEmpty && !values.contains(current)) {
                let preferred = store.wireProtocol.defaultModel
                store.model = values.contains(preferred) ? preferred : (values.first ?? preferred)
            }
        } catch {
            guard !Task.isCancelled, modelDiscoveryRequestID == requestID else { return }
            discoveredModels = []
            modelDiscoveryError = error.localizedDescription
        }
    }

    private var developerDivider: some View {
        Divider().padding(.leading, 58)
    }

    private var testStateIcon: MonologueIcon.IconType {
        switch testState {
        case .passed: return .checkmark
        case .failed: return .warning
        default: return .logNetwork
        }
    }

    private var testStateText: String {
        switch testState {
        case .idle: return String(localized: "ai_provider_not_tested")
        case .testing: return String(localized: "ai_provider_testing")
        case .passed: return String(localized: "ai_provider_connected")
        case let .failed(message): return message
        }
    }

    private func testConnection() {
        testState = .testing
        Task {
            do {
                try await AIEqualizerAgent.shared.testProviderConnection()
                testState = .passed
                HapticManager.shared.success()
            } catch {
                testState = .failed(error.localizedDescription)
                HapticManager.shared.error()
            }
        }
    }

    private func resetConfiguration() {
        store.resetDeveloperOverride()
        testState = .idle
    }
}
