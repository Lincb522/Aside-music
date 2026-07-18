import SwiftUI

@MainActor
struct DebugLogView: View {
    private enum Destination: Hashable {
        case detail(LogEntry)
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var model = DebugLogViewModel()
    @State private var showMoreMenu = false
    @State private var showShareSheet = false
    @State private var showClearAlert = false
    @State private var shareItems: [Any] = []
    @FocusState private var searchFocused: Bool

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedSettingsBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        SettingsScrollablePageHeader(
                            title: String(localized: "debug_title"),
                            eyebrow: "DIAGNOSTICS",
                            icon: .logDebug
                        )

                        LazyVStack(alignment: .leading, spacing: 18) {
                            consoleHeader
                            metricRail

                            if let token = apnsToken {
                                tokenRow(token)
                            }

                            searchField
                            levelFilters
                            logSection
                            FloatingBarBottomSpacer()
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .iPadContentWidth(760)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                .coordinateSpace(name: SettingsPageLayout.scrollCoordinateSpace)
                .themeRenderScrollLayer()
                .onChange(of: model.latestVisibleEntryID) { _, identifier in
                    guard model.followsLatest, let identifier else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        proxy.scrollTo(identifier, anchor: model.newestFirst ? .top : .bottom)
                    }
                }
            }
        }
        .asideSettingsDetailChrome(String(localized: "debug_title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    searchFocused = false
                    withAnimation(.easeOut(duration: 0.18)) {
                        showMoreMenu.toggle()
                    }
                } label: {
                    MonologueIcon(icon: .more, size: 16, color: .monologueTextSecondary)
                        .frame(width: 36, height: 36)
                        .monologueGlassCircle(interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "player_more_title"))
            }
        }
        .overlay {
            if showMoreMenu {
                MonologueMoreMenuOverlay(
                    isPresented: $showMoreMenu,
                    title: String(localized: "player_more_title"),
                    isDarkBackground: colorScheme == .dark
                ) {
                    moreMenuContent
                }
                .zIndex(20)
            }
        }
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case .detail(let log):
                DebugLogDetailView(log: log)
            }
        }
        .alert(String(localized: "debug_clear_confirm_title"), isPresented: $showClearAlert) {
            Button(String(localized: "alert_cancel"), role: .cancel) {}
            Button(String(localized: "debug_clear"), role: .destructive) {
                model.clear()
            }
        } message: {
            Text(String(localized: "debug_clear_confirm_message"))
        }
        .monologueSheet(isPresented: $showShareSheet, preset: .standard) {
            DebugLogShareSheet(items: shareItems)
        }
        .onAppear {
            model.refresh(force: true)
        }
    }

    private var consoleHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Text(String(format: String(localized: "debug_log_count"), model.totalCount))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)

                if model.droppedCount > 0 {
                    Circle()
                        .fill(Color.monologueTextSecondary.opacity(0.45))
                        .frame(width: 3, height: 3)

                    Text(String(format: String(localized: "debug_dropped_count"), model.droppedCount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.orange)
                }

                if let lastUpdatedAt = model.lastUpdatedAt {
                    Circle()
                        .fill(Color.monologueTextSecondary.opacity(0.45))
                        .frame(width: 3, height: 3)

                    Text(
                        String(
                            format: String(localized: "debug_updated_at"),
                            lastUpdatedAt.formatted(date: .omitted, time: .standard)
                        )
                    )
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.monologueTextSecondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 8)

            collectionButton
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .debugGlassSurface(cornerRadius: 14)
    }

    private var collectionButton: some View {
        Button {
            model.isCollecting.toggle()
            HapticManager.shared.light()
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(model.isCollecting ? Color.green : Color.monologueTextSecondary)
                    .frame(width: 7, height: 7)

                Text(
                    model.isCollecting
                        ? String(localized: "debug_collecting")
                        : String(localized: "debug_collection_paused")
                )
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .debugGlassCapsule(
                tint: model.isCollecting
                    ? Color.green.opacity(0.075)
                    : Color.monologueTextPrimary.opacity(0.025)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            model.isCollecting
                ? String(localized: "debug_collecting")
                : String(localized: "debug_collection_paused")
        )
    }

    private var metricRail: some View {
        HStack(spacing: 0) {
            DebugLogMetricButton(
                title: String(localized: "debug_stat_total"),
                value: model.totalCount,
                tint: .monologueAccent,
                isSelected: model.selectedLevel == nil
            ) {
                model.select(nil)
            }

            metricDivider

            DebugLogMetricButton(
                title: String(localized: "debug_stat_error"),
                value: model.count(for: .error),
                tint: .red,
                isSelected: model.selectedLevel == .error
            ) {
                model.select(.error)
            }

            metricDivider

            DebugLogMetricButton(
                title: String(localized: "debug_stat_warning"),
                value: model.count(for: .warning),
                tint: .orange,
                isSelected: model.selectedLevel == .warning
            ) {
                model.select(.warning)
            }

            metricDivider

            DebugLogMetricButton(
                title: String(localized: "debug_level_network"),
                value: model.count(for: .network),
                tint: .cyan,
                isSelected: model.selectedLevel == .network
            ) {
                model.select(.network)
            }
        }
        .debugGlassSurface(cornerRadius: 14)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.monologueSeparator)
            .frame(width: 0.5, height: 30)
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            MonologueIcon(icon: .magnifyingGlass, size: 15, color: .monologueTextSecondary)

            TextField(String(localized: "debug_search_placeholder"), text: $model.searchText)
                .focused($searchFocused)
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .monologueTextInputBehavior()

            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    MonologueIcon(icon: .xmarkCircle, size: 15, color: .monologueTextSecondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "common_clear"))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 7)
        .frame(height: 46)
        .debugGlassSurface(
            cornerRadius: 12,
            tint: Color.monologueTextPrimary.opacity(searchFocused ? 0.04 : 0.018)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    searchFocused ? Color.monologueAccent.opacity(0.55) : Color.clear,
                    lineWidth: 1
                )
        }
        .animation(.easeOut(duration: 0.16), value: searchFocused)
    }

    private var levelFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                DebugLogFilterChip(
                    title: String(localized: "filter_all"),
                    tint: .monologueAccent,
                    isSelected: model.selectedLevel == nil
                ) {
                    model.select(nil)
                }

                ForEach(LogEntry.LogLevel.allCases, id: \.self) { level in
                    DebugLogFilterChip(
                        title: level.localizedTitle,
                        tint: level.tint,
                        isSelected: model.selectedLevel == level
                    ) {
                        model.select(level)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "debug_records_section"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer(minLength: 8)

                Text("\(model.visibleEntries.count) / \(model.totalCount)")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.monologueTextSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 2)

            if model.visibleEntries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(model.visibleEntries) { log in
                        NavigationLink(value: Destination.detail(log)) {
                            DebugLogRow(log: log)
                        }
                        .buttonStyle(.plain)
                        .id(log.id)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = log.exportText
                                HapticManager.shared.success()
                            } label: {
                                Label(String(localized: "debug_copy_log"), systemImage: "doc.on.doc")
                            }
                        }

                        if log.id != model.visibleEntries.last?.id {
                            Rectangle()
                                .fill(Color.monologueSeparator)
                                .frame(height: 0.5)
                                .padding(.leading, 52)
                        }
                    }
                }
                .debugGlassSurface(cornerRadius: 14)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            MonologueIcon(icon: .logDebug, size: 27, color: .monologueTextSecondary.opacity(0.45))

            Text(
                model.isFiltering
                    ? String(localized: "debug_no_matches")
                    : String(localized: "debug_empty")
            )
            .font(.system(size: 13.5, weight: .medium, design: .rounded))
            .foregroundColor(.monologueTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .debugGlassSurface(cornerRadius: 14)
    }

    private func tokenRow(_ token: String) -> some View {
        HStack(spacing: 11) {
            MonologueIcon(icon: .bell, size: 14, color: .monologueTextSecondary)
                .frame(width: 30, height: 30)
                .debugGlassSurface(cornerRadius: 9)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "debug_apns_token"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)

                Text("\(token.prefix(16))…\(token.suffix(8))")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                UIPasteboard.general.string = token
                HapticManager.shared.success()
            } label: {
                MonologueIcon(icon: .layers, size: 14, color: .monologueAccent)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "debug_copy"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(minHeight: 50)
        .debugGlassSurface(cornerRadius: 12)
    }

    private var apnsToken: String? {
        guard let value = UserDefaults.standard.string(forKey: "apns_device_token"), !value.isEmpty else {
            return nil
        }
        return value
    }

    private var moreMenuContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            MonologueMoreMenuSection(title: String(localized: "more_menu_log_section")) {
                MonologueMoreMenuGroup {
                    MonologueMoreMenuRow(
                        icon: .share,
                        title: String(localized: "debug_export_filtered"),
                        trailingText: "\(model.visibleEntries.count)",
                        isEnabled: !model.visibleEntries.isEmpty
                    ) {
                        presentShare(model.textExport(filtered: true))
                    }

                    MonologueMoreMenuDivider()

                    MonologueMoreMenuRow(
                        icon: .save,
                        title: String(localized: "debug_export_all_json"),
                        trailingText: "\(model.totalCount)",
                        isEnabled: model.totalCount > 0
                    ) {
                        presentShare(model.jsonExport())
                    }

                    MonologueMoreMenuDivider()

                    MonologueMoreMenuRow(
                        icon: .trash,
                        title: String(localized: "debug_clear"),
                        isDestructive: true,
                        isEnabled: model.totalCount > 0
                    ) {
                        showMoreMenu = false
                        showClearAlert = true
                    }
                }
            }

            MonologueMoreMenuSection(title: String(localized: "more_menu_options_section")) {
                MonologueMoreMenuGroup {
                    MonologueMoreMenuToggleRow(
                        icon: .waveform,
                        title: String(localized: "debug_collection"),
                        isOn: $model.isCollecting
                    )

                    MonologueMoreMenuDivider()

                    MonologueMoreMenuToggleRow(
                        icon: .arrowDownToLine,
                        title: String(localized: "debug_newest_first"),
                        isOn: $model.newestFirst
                    )

                    MonologueMoreMenuDivider()

                    MonologueMoreMenuToggleRow(
                        icon: .history,
                        title: String(localized: "debug_follow_latest"),
                        isOn: $model.followsLatest
                    )
                }
            }
        }
    }

    private func presentShare(_ content: String) {
        guard !content.isEmpty else { return }
        showMoreMenu = false
        shareItems = [content]
        showShareSheet = true
    }
}

private struct DebugLogMetricButton: View {
    let title: String
    let value: Int
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? tint : .monologueTextPrimary)
                    .monospacedDigit()

                Text(title)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isSelected ? tint.opacity(0.075) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue("\(value)")
    }
}

private struct DebugLogFilterChip: View {
    let title: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? tint : .monologueTextSecondary)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .debugGlassCapsule(
                    tint: isSelected
                        ? tint.opacity(0.09)
                        : Color.monologueTextPrimary.opacity(0.015)
                )
                .overlay {
                    Capsule()
                        .stroke(isSelected ? tint.opacity(0.26) : Color.clear, lineWidth: 0.75)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct DebugLogRow: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MonologueIcon(icon: log.level.icon, size: 14, color: log.level.tint)
                .frame(width: 32, height: 32)
                .debugGlassSurface(cornerRadius: 9, tint: log.level.tint.opacity(0.08))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(log.level.localizedTitle)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(log.level.tint)

                    Text(log.formattedTime)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.monologueTextSecondary)
                        .monospacedDigit()

                    Spacer(minLength: 6)

                    Text(log.sourceDescription)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.monologueTextSecondary.opacity(0.75))
                        .lineLimit(1)
                }

                Text(log.message)
                    .font(.system(size: 12.25, weight: .regular, design: .monospaced))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
            }

            MonologueIcon(icon: .chevronRight, size: 9, color: .monologueTextSecondary.opacity(0.5))
                .frame(height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private extension LogEntry.LogLevel {
    var localizedTitle: String {
        switch self {
        case .info: return String(localized: "debug_level_info")
        case .debug: return String(localized: "debug_level_debug")
        case .warning: return String(localized: "debug_level_warning")
        case .error: return String(localized: "debug_level_error")
        case .network: return String(localized: "debug_level_network")
        case .success: return String(localized: "debug_level_success")
        }
    }

    var tint: Color {
        switch self {
        case .info: return .blue
        case .debug: return .purple
        case .warning: return .orange
        case .error: return .red
        case .network: return .cyan
        case .success: return .green
        }
    }

    var icon: MonologueIcon.IconType {
        switch self {
        case .info: return .logInfo
        case .debug: return .logDebug
        case .warning: return .warning
        case .error: return .logError
        case .network: return .logNetwork
        case .success: return .logSuccess
        }
    }
}

private struct DebugLogAnalysis {
    enum Kind {
        case javascript
        case json
        case network
        case structured
        case text

        var localizedTitle: String {
            switch self {
            case .javascript: return String(localized: "debug_analysis_javascript")
            case .json: return String(localized: "debug_analysis_json")
            case .network: return String(localized: "debug_analysis_network")
            case .structured: return String(localized: "debug_analysis_structured")
            case .text: return String(localized: "debug_analysis_text")
            }
        }
    }

    struct Field: Identifiable, Hashable {
        let key: String
        let value: String
        var id: String { "\(key)=\(value)" }
    }

    struct JavaScriptFrame: Identifiable, Hashable {
        let function: String?
        let file: String
        let line: Int
        let column: Int
        let raw: String

        var id: String { raw }

        var location: String {
            "\(file):\(line):\(column)"
        }
    }

    struct JavaScriptInfo {
        let level: String?
        let eventType: String?
        let errorName: String?
        let message: String?
        let sourceURL: String?
        let line: Int?
        let column: Int?
        let stack: String?
        let frames: [JavaScriptFrame]
    }

    let kind: Kind
    let lineCount: Int
    let characterCount: Int
    let fields: [Field]
    let links: [String]
    let prettyJSON: String?
    let requestMethod: String?
    let statusCode: String?
    let javaScript: JavaScriptInfo?

    init(log: LogEntry) {
        lineCount = max(1, log.message.split(separator: "\n", omittingEmptySubsequences: false).count)
        characterCount = log.message.count
        fields = Self.extractFields(from: log.message)
        links = Self.extractLinks(from: log.message)
        prettyJSON = Self.extractPrettyJSON(from: log.message)
        requestMethod = Self.firstMatch(
            pattern: #"\b(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\b"#,
            text: log.message,
            group: 1
        )
        statusCode = Self.firstMatch(
            pattern: #"\b(?:status|statusCode|code)\s*[:=]\s*(\d{3})\b"#,
            text: log.message,
            group: 1
        )
        javaScript = Self.extractJavaScriptInfo(from: log.message)

        if javaScript != nil {
            kind = .javascript
        } else if prettyJSON != nil {
            kind = .json
        } else if log.level == .network || !links.isEmpty || requestMethod != nil {
            kind = .network
        } else if !fields.isEmpty {
            kind = .structured
        } else {
            kind = .text
        }
    }

    private static func extractFields(from text: String) -> [Field] {
        let pattern = #"([A-Za-z_][A-Za-z0-9_.-]*)\s*[:=]\s*(\"[^\"]*\"|'[^']*'|[^\s,;]+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = expression.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var seen = Set<String>()
        var result: [Field] = []

        for match in matches.prefix(32) where match.numberOfRanges >= 3 {
            let key = nsText.substring(with: match.range(at: 1))
            var value = nsText.substring(with: match.range(at: 2))
            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\""))
                || (value.hasPrefix("'") && value.hasSuffix("'"))
            {
                value.removeFirst()
                value.removeLast()
            }
            let identity = "\(key)=\(value)"
            guard seen.insert(identity).inserted else { continue }
            result.append(Field(key: key, value: value))
        }
        return result
    }

    private static func extractLinks(from text: String) -> [String] {
        let pattern = #"https?://[^\s<>\"']+"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = expression.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var seen = Set<String>()

        return matches.compactMap { match in
            let raw = nsText.substring(with: match.range)
            let value = raw.trimmingCharacters(in: CharacterSet(charactersIn: "),.;]}"))
            return seen.insert(value).inserted ? value : nil
        }
    }

    private static func extractPrettyJSON(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates = [trimmed]

        if let first = trimmed.firstIndex(of: "{"), let last = trimmed.lastIndex(of: "}"), first < last {
            candidates.append(String(trimmed[first...last]))
        }
        if let first = trimmed.firstIndex(of: "["), let last = trimmed.lastIndex(of: "]"), first < last {
            candidates.append(String(trimmed[first...last]))
        }

        for candidate in candidates {
            guard let data = candidate.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  JSONSerialization.isValidJSONObject(object),
                  let output = try? JSONSerialization.data(
                    withJSONObject: object,
                    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                  ),
                  let result = String(data: output, encoding: .utf8)
            else { continue }
            return result
        }
        return nil
    }

    private static func extractJavaScriptInfo(from text: String) -> JavaScriptInfo? {
        let markerPresent = text.localizedCaseInsensitiveContains("[JavaScript]")
        let stackLooksLikeJavaScript = text.range(
            of: #"(?:https?|file|webpack|blob):\/\/[^\s]+\.js(?:\?[^\s:]*)?:\d+:\d+"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let containsJavaScriptError = text.range(
            of: #"\b(?:TypeError|ReferenceError|SyntaxError|RangeError|EvalError|URIError)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil

        guard markerPresent || stackLooksLikeJavaScript || containsJavaScriptError else {
            return nil
        }

        let stack = multilineValue(for: "stack", in: text)
        let frames = extractJavaScriptFrames(from: stack ?? text)
        let explicitSource = lineValue(for: "sourceURL", in: text)
            ?? lineValue(for: "filename", in: text)
        let normalizedSource = nonEmpty(explicitSource)
        let sourceURL: String?
        if let normalizedSource, normalizedSource.localizedCaseInsensitiveContains(".js") {
            sourceURL = normalizedSource
        } else {
            sourceURL = frames.first?.file ?? normalizedSource
        }
        let explicitLine = positiveInteger(lineValue(for: "lineNumber", in: text))
            ?? positiveInteger(lineValue(for: "line", in: text))
        let explicitColumn = positiveInteger(lineValue(for: "columnNumber", in: text))
            ?? positiveInteger(lineValue(for: "column", in: text))

        return JavaScriptInfo(
            level: nonEmpty(lineValue(for: "level", in: text)),
            eventType: nonEmpty(lineValue(for: "eventType", in: text)),
            errorName: nonEmpty(lineValue(for: "errorName", in: text))
                ?? firstMatch(
                    pattern: #"\b(TypeError|ReferenceError|SyntaxError|RangeError|EvalError|URIError|Error)\b"#,
                    text: text,
                    group: 1
                ),
            message: nonEmpty(lineValue(for: "message", in: text)),
            sourceURL: sourceURL,
            line: explicitLine ?? frames.first?.line,
            column: explicitColumn ?? frames.first?.column,
            stack: nonEmpty(stack),
            frames: frames
        )
    }

    private static func extractJavaScriptFrames(from stack: String) -> [JavaScriptFrame] {
        let pattern = #"((?:(?:https?|file|webpack|blob):\/\/)?[^\s()@]+?):(\d+):(\d+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        var seen = Set<String>()
        var frames: [JavaScriptFrame] = []
        for rawLine in stack.split(separator: "\n", omittingEmptySubsequences: true).prefix(48) {
            let raw = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            let nsLine = raw as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            guard let match = expression.firstMatch(in: raw, range: range), match.numberOfRanges >= 4 else {
                continue
            }

            let file = nsLine.substring(with: match.range(at: 1))
            guard let line = Int(nsLine.substring(with: match.range(at: 2))),
                  let column = Int(nsLine.substring(with: match.range(at: 3)))
            else { continue }

            var function = nsLine.substring(to: match.range.location)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            function = function.replacingOccurrences(of: #"^at\s+"#, with: "", options: .regularExpression)
            function = function.trimmingCharacters(in: CharacterSet(charactersIn: "(@ "))
            if function.hasSuffix("@") {
                function.removeLast()
            }
            let normalizedFunction = function.lowercased()
            if normalizedFunction.contains("console.<computed>")
                || normalizedFunction == "send"
                || normalizedFunction.contains("__monologue")
            {
                continue
            }

            let identity = "\(file):\(line):\(column) \(function)"
            guard seen.insert(identity).inserted else { continue }
            frames.append(
                JavaScriptFrame(
                    function: function.isEmpty ? nil : function,
                    file: file,
                    line: line,
                    column: column,
                    raw: raw
                )
            )
        }
        return frames
    }

    private static func lineValue(for key: String, in text: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "(?mi)^\\s*\(escapedKey)\\s*[:=]\\s*(.*?)\\s*$"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(location: 0, length: (text as NSString).length)
              ),
              match.numberOfRanges >= 2,
              match.range(at: 1).location != NSNotFound
        else { return nil }
        return (text as NSString).substring(with: match.range(at: 1))
    }

    private static func multilineValue(for key: String, in text: String) -> String? {
        let markers = ["\n\(key)=", "\n\(key):"]
        for marker in markers {
            guard let range = text.range(of: marker, options: [.caseInsensitive]) else { continue }
            let value = String(text[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func positiveInteger(_ value: String?) -> Int? {
        guard let value, let number = Int(value), number > 0 else { return nil }
        return number
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func firstMatch(pattern: String, text: String, group: Int) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = expression.firstMatch(in: text, range: range),
              match.numberOfRanges > group,
              match.range(at: group).location != NSNotFound
        else { return nil }
        return nsText.substring(with: match.range(at: group)).uppercased()
    }
}

@MainActor
private struct DebugLogDetailView: View {
    let log: LogEntry
    private let analysis: DebugLogAnalysis

    @ObservedObject private var settings = SettingsManager.shared
    @State private var copiedTarget: CopyTarget?

    private enum CopyTarget {
        case message
        case log
    }

    init(log: LogEntry) {
        self.log = log
        analysis = DebugLogAnalysis(log: log)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "debug_detail_title"),
                        eyebrow: "LOG DETAIL",
                        icon: .logDebug
                    )

                    VStack(alignment: .leading, spacing: 22) {
                        identityHeader
                        copyActions
                        metadataSection
                        messageSection
                        analysisSection
                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .iPadContentWidth(760)
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: SettingsPageLayout.scrollCoordinateSpace)
            .themeRenderScrollLayer()
        }
        .asideSettingsDetailChrome(String(localized: "debug_detail_title"))
    }

    private var identityHeader: some View {
        HStack(alignment: .top, spacing: 13) {
            MonologueIcon(icon: log.level.icon, size: 18, color: log.level.tint)
                .frame(width: 42, height: 42)
                .debugGlassSurface(cornerRadius: 12, tint: log.level.tint.opacity(0.09))

            VStack(alignment: .leading, spacing: 5) {
                Text(log.level.localizedTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(log.level.tint)

                Text(log.detailedTimestamp)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.monologueTextSecondary)
                    .monospacedDigit()

                if log.resolvedStep != "—" {
                    Text(log.resolvedStep)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(analysis.kind.localizedTitle)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .debugGlassCapsule(tint: Color.monologueTextPrimary.opacity(0.025))
        }
        .padding(14)
        .debugGlassSurface(cornerRadius: 14, tint: log.level.tint.opacity(0.025))
    }

    private var copyActions: some View {
        HStack(spacing: 9) {
            copyButton(
                title: copiedTarget == .message
                    ? String(localized: "debug_copied")
                    : String(localized: "debug_copy_message"),
                icon: copiedTarget == .message ? .checkmark : .layers,
                isPrimary: false
            ) {
                copy(log.message, target: .message)
            }

            copyButton(
                title: copiedTarget == .log
                    ? String(localized: "debug_copied")
                    : String(localized: "debug_copy_log"),
                icon: copiedTarget == .log ? .checkmark : .share,
                isPrimary: true
            ) {
                copy(log.exportText, target: .log)
            }
        }
    }

    private func copyButton(
        title: String,
        icon: MonologueIcon.IconType,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                MonologueIcon(
                    icon: icon,
                    size: 14,
                    color: isPrimary ? .monologueIconForeground : .monologueTextPrimary
                )

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isPrimary ? .monologueIconForeground : .monologueTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .debugGlassSurface(
                cornerRadius: 12,
                tint: isPrimary
                    ? Color.monologueIconBackground.opacity(0.78)
                    : Color.monologueTextPrimary.opacity(0.02)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(String(localized: "debug_context_section"))

            VStack(spacing: 0) {
                metadataRow(String(localized: "debug_step"), log.resolvedStep)
                detailDivider

                metadataRow(
                    String(localized: "debug_file"),
                    log.fileName.isEmpty ? "—" : log.fileName
                )
                detailDivider

                metadataRow(
                    String(localized: "debug_line"),
                    log.line > 0 ? "\(log.line)" : "—"
                )
                detailDivider

                metadataRow(
                    String(localized: "debug_function"),
                    log.function.isEmpty ? "—" : log.function
                )
                detailDivider

                metadataRow(
                    String(localized: "debug_thread"),
                    log.thread.isEmpty ? "—" : log.thread
                )
                detailDivider

                metadataRow(
                    String(localized: "debug_path"),
                    log.file.isEmpty ? "—" : log.file
                )
            }
            .debugGlassSurface(cornerRadius: 12)
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(String(localized: "debug_message_section"))

            Text(log.message)
                .font(.system(size: 12.25, weight: .regular, design: .monospaced))
                .foregroundColor(.monologueTextPrimary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .debugGlassSurface(cornerRadius: 12)
        }
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                sectionTitle(String(localized: "debug_analysis_section"))

                VStack(spacing: 0) {
                    metadataRow(String(localized: "debug_analysis_type"), analysis.kind.localizedTitle)
                    detailDivider
                    metadataRow(String(localized: "debug_analysis_lines"), "\(analysis.lineCount)")
                    detailDivider
                    metadataRow(String(localized: "debug_analysis_characters"), "\(analysis.characterCount)")

                    if let requestMethod = analysis.requestMethod {
                        detailDivider
                        metadataRow(String(localized: "debug_request_method"), requestMethod)
                    }

                    if let statusCode = analysis.statusCode {
                        detailDivider
                        metadataRow(String(localized: "debug_status_code"), statusCode)
                    }
                }
                .debugGlassSurface(cornerRadius: 12)
            }

            if let javaScript = analysis.javaScript {
                javaScriptSection(javaScript)
            } else if !analysis.fields.isEmpty {
                parsedFields
            }

            if !analysis.links.isEmpty {
                parsedLinks
            }

            if let prettyJSON = analysis.prettyJSON {
                parsedJSON(prettyJSON)
            }
        }
    }

    private func javaScriptSection(_ info: DebugLogAnalysis.JavaScriptInfo) -> some View {
        let metadata = javaScriptMetadata(info)

        return VStack(alignment: .leading, spacing: 18) {
            if !metadata.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    sectionTitle("JavaScript")

                    VStack(spacing: 0) {
                        ForEach(Array(metadata.enumerated()), id: \.offset) { index, field in
                            metadataRow(field.key, field.value)
                            if index < metadata.count - 1 {
                                detailDivider
                            }
                        }
                    }
                    .debugGlassSurface(cornerRadius: 12)
                }
            }

            if !info.frames.isEmpty {
                javaScriptFrames(info.frames)
            }

            if let stack = info.stack {
                VStack(alignment: .leading, spacing: 9) {
                    sectionTitle(String(localized: "debug_js_stack"))

                    Text(stack)
                        .font(.system(size: 11.25, weight: .regular, design: .monospaced))
                        .foregroundColor(.monologueTextPrimary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .debugGlassSurface(cornerRadius: 12)
                }
            }
        }
    }

    private func javaScriptMetadata(
        _ info: DebugLogAnalysis.JavaScriptInfo
    ) -> [DebugLogAnalysis.Field] {
        var fields: [DebugLogAnalysis.Field] = []
        if let level = info.level {
            fields.append(.init(key: String(localized: "debug_js_level"), value: level.uppercased()))
        }
        if let eventType = info.eventType {
            fields.append(.init(key: String(localized: "debug_js_event"), value: eventType))
        }
        if let errorName = info.errorName {
            fields.append(.init(key: String(localized: "debug_js_error"), value: errorName))
        }
        if let message = info.message {
            fields.append(.init(key: String(localized: "debug_js_message"), value: message))
        }
        if let sourceURL = info.sourceURL {
            fields.append(.init(key: String(localized: "debug_file"), value: sourceURL))
        }
        if let line = info.line {
            fields.append(.init(key: String(localized: "debug_line"), value: "\(line)"))
        }
        if let column = info.column {
            fields.append(.init(key: String(localized: "debug_column"), value: "\(column)"))
        }
        return fields
    }

    private func javaScriptFrames(_ frames: [DebugLogAnalysis.JavaScriptFrame]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(String(localized: "debug_js_frames"))

            VStack(spacing: 0) {
                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(frame.function ?? String(localized: "debug_js_anonymous"))
                            .font(.system(size: 12.25, weight: .semibold, design: .monospaced))
                            .foregroundColor(.monologueTextPrimary)
                            .textSelection(.enabled)

                        Text(frame.location)
                            .font(.system(size: 10.75, weight: .medium, design: .monospaced))
                            .foregroundColor(.monologueTextSecondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if index < frames.count - 1 {
                        detailDivider
                    }
                }
            }
            .debugGlassSurface(cornerRadius: 12)
        }
    }

    private var parsedFields: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(String(localized: "debug_fields_section"))

            VStack(spacing: 0) {
                ForEach(Array(analysis.fields.enumerated()), id: \.offset) { index, field in
                    metadataRow(field.key, field.value)
                    if index < analysis.fields.count - 1 {
                        detailDivider
                    }
                }
            }
            .debugGlassSurface(cornerRadius: 12)
        }
    }

    private var parsedLinks: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(String(localized: "debug_links_section"))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(analysis.links.enumerated()), id: \.offset) { index, value in
                    if let destination = URL(string: value) {
                        Link(destination: destination) {
                            HStack(spacing: 9) {
                                Text(value)
                                    .font(.system(size: 11.25, weight: .medium, design: .monospaced))
                                    .foregroundColor(.monologueAccent)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 8)

                                MonologueIcon(icon: .chevronRight, size: 9, color: .monologueTextSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(value)
                            .font(.system(size: 11.25, weight: .medium, design: .monospaced))
                            .foregroundColor(.monologueTextPrimary)
                            .textSelection(.enabled)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }

                    if index < analysis.links.count - 1 {
                        detailDivider
                    }
                }
            }
            .debugGlassSurface(cornerRadius: 12)
        }
    }

    private func parsedJSON(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("JSON")

            Text(value)
                .font(.system(size: 11.25, weight: .regular, design: .monospaced))
                .foregroundColor(.monologueTextPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .debugGlassSurface(cornerRadius: 12)
        }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 11.75, weight: .semibold, design: .monospaced))
                .foregroundColor(.monologueTextPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 43)
    }

    private var detailDivider: some View {
        Rectangle()
            .fill(Color.monologueSeparator)
            .frame(height: 0.5)
            .padding(.leading, 14)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.monologueTextSecondary)
            .padding(.horizontal, 2)
    }

    private func copy(_ value: String, target: CopyTarget) {
        UIPasteboard.general.string = value
        HapticManager.shared.success()
        withAnimation(.easeOut(duration: 0.16)) {
            copiedTarget = target
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard copiedTarget == target else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                copiedTarget = nil
            }
        }
    }
}

private extension View {
    func debugGlassSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint)
        )
        .monologueGlass(cornerRadius: cornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func debugGlassCapsule(tint: Color = .clear) -> some View {
        background(Capsule().fill(tint))
            .monologueGlassCapsule()
            .clipShape(Capsule())
    }
}

private struct DebugLogShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
