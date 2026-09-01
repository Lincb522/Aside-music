import SwiftUI

@MainActor
struct DebugLogView: View {
    @StateObject private var model = DebugLogViewModel()
    @State private var showMoreMenu = false
    @State private var showShareSheet = false
    @State private var showClearAlert = false
    @State private var shareItems: [Any] = []
    @FocusState private var searchFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                debugBackdrop

                ScrollViewReader { proxy in
                    Group {
                        if geometry.size.width >= 760 {
                            wideWorkspace(width: geometry.size.width, proxy: proxy)
                        } else {
                            compactWorkspace(width: geometry.size.width, proxy: proxy)
                        }
                    }
                }
            }
        }
        .developerDiagnosticPageChrome()
        .overlay {
            if showMoreMenu {
                MonoMoreMenuOverlay(
                    isPresented: $showMoreMenu,
                    title: String(localized: "player_more_title"),
                    isDarkBackground: true
                ) {
                    moreMenuContent
                }
                .zIndex(20)
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
        .monoSheet(isPresented: $showShareSheet, preset: .standard) {
            DebugLogShareSheet(items: shareItems)
        }
    }

    private var debugBackdrop: some View {
        DeveloperDiagnosticBackdrop()
    }

    private func compactWorkspace(width: CGFloat, proxy: ScrollViewProxy) -> some View {
        let inset: CGFloat = width < 370 ? 12 : 16

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                compactHeader
                compactStatusStrip
                severityRail
                categoryRail
                streamToolbar
                logTimeline
                FloatingBarBottomSpacer()
            }
            .padding(.horizontal, inset)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .transaction { $0.animation = nil }
        .onChange(of: model.latestVisibleEntryID) { _, identifier in
            scrollToLatest(identifier, proxy: proxy)
        }
    }

    private func wideWorkspace(width: CGFloat, proxy: ScrollViewProxy) -> some View {
        let workspaceWidth = min(width - 40, 1160)

        return HStack(spacing: 0) {
            Spacer(minLength: 20)

            HStack(spacing: 0) {
                diagnosticSidebar
                    .frame(width: 240)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 0.5)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        wideStreamHeader
                        streamToolbar
                        categoryRail
                        logTimeline
                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                .transaction { $0.animation = nil }
                .onChange(of: model.latestVisibleEntryID) { _, identifier in
                    scrollToLatest(identifier, proxy: proxy)
                }
            }
            .frame(width: workspaceWidth)
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 0.7)
            }
            .padding(.vertical, 12)
            .frame(maxHeight: .infinity)

            Spacer(minLength: 20)
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "debug_title"))
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(model.isCollecting
                     ? String(localized: "debug_collecting")
                     : String(localized: "debug_collection_paused"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(model.isCollecting ? Color.green : Color.white.opacity(0.48))
            }

            Spacer(minLength: 0)
            headerActions
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                model.isCollecting.toggle()
                HapticManager.shared.light()
            } label: {
                MonoIcon(
                    icon: model.isCollecting ? .pause : .play,
                    size: 14,
                    color: model.isCollecting ? .black : .white
                )
                .frame(width: 40, height: 40)
                .background(model.isCollecting ? Color.green : Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                searchFocused = false
                showMoreMenu = true
            } label: {
                MonoIcon(icon: .more, size: 15, color: .white.opacity(0.82))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var compactStatusStrip: some View {
        HStack(spacing: 0) {
            consoleMetric(value: "\(model.totalCount)", title: String(localized: "debug_stat_total"))
            consoleMetricDivider
            consoleMetric(value: "\(model.visibleEntries.count)", title: String(localized: "debug_visible_count"))
            consoleMetricDivider
            consoleMetric(
                value: "\(model.coalescedCount)",
                title: String(localized: "debug_coalesced_count_short"),
                tint: model.coalescedCount > 0 ? .cyan : .white
            )
            consoleMetricDivider
            consoleMetric(
                value: "\(model.droppedCount)",
                title: String(localized: "debug_dropped_count_short"),
                tint: model.droppedCount > 0 ? .orange : .white
            )
        }
        .padding(.vertical, 13)
        .debugConsoleSurface(cornerRadius: 16)
    }

    private func consoleMetric(value: String, title: String, tint: Color = .white) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var consoleMetricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(width: 0.5, height: 30)
    }

    private var diagnosticSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                MonoIcon(icon: .logDebug, size: 24, color: .cyan)
                    .frame(width: 48, height: 48)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                Text(String(localized: "debug_title"))
                    .font(.system(size: 23, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 7) {
                    Circle()
                        .fill(model.isCollecting ? Color.green : Color.white.opacity(0.3))
                        .frame(width: 7, height: 7)
                    Text(model.isCollecting
                         ? String(localized: "debug_collecting")
                         : String(localized: "debug_collection_paused"))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 4) {
                    sidebarFilter(level: nil)
                    ForEach(LogEntry.LogLevel.allCases, id: \.self) { level in
                        sidebarFilter(level: level)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)

            VStack(spacing: 8) {
                sidebarControl(
                    title: String(localized: "debug_collection"),
                    icon: model.isCollecting ? .pause : .play,
                    isActive: model.isCollecting
                ) {
                    model.isCollecting.toggle()
                }
                sidebarControl(
                    title: String(localized: "debug_follow_latest"),
                    icon: .history,
                    isActive: model.followsLatest
                ) {
                    model.followsLatest.toggle()
                }
                sidebarControl(
                    title: String(localized: "debug_newest_first"),
                    icon: .arrowDownToLine,
                    isActive: model.newestFirst
                ) {
                    model.newestFirst.toggle()
                }
            }
            .padding(12)

            Button {
                showMoreMenu = true
            } label: {
                HStack(spacing: 9) {
                    MonoIcon(icon: .more, size: 13, color: .white.opacity(0.65))
                    Text(String(localized: "player_more_title"))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color.white.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    private func sidebarFilter(level: LogEntry.LogLevel?) -> some View {
        let isSelected = model.selectedLevel == level
        let tint = level?.tint ?? Color.cyan

        return Button {
            model.select(level)
        } label: {
            HStack(spacing: 10) {
                if let level {
                    MonoIcon(icon: level.icon, size: 13, color: isSelected ? tint : .white.opacity(0.5))
                } else {
                    Circle()
                        .fill(isSelected ? tint : Color.white.opacity(0.38))
                        .frame(width: 8, height: 8)
                        .frame(width: 13)
                }

                Text(level?.localizedTitle ?? String(localized: "filter_all"))
                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.56))

                Spacer()

                Text("\(model.count(for: level))")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? tint : Color.white.opacity(0.35))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(isSelected ? tint.opacity(0.11) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sidebarControl(
        title: String,
        icon: MonoIcon.IconType,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                MonoIcon(icon: icon, size: 12, color: isActive ? .cyan : .white.opacity(0.42))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(isActive ? 0.82 : 0.45))
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(isActive ? Color.green : Color.white.opacity(0.18))
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var wideStreamHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    model.selectedCategory?.localizedTitle
                        ?? model.selectedLevel?.localizedTitle
                        ?? String(localized: "debug_records_section")
                )
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(model.visibleEntries.count) / \(model.totalCount)")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                    .monospacedDigit()
            }

            Spacer()
            headerActions
        }
    }

    private var streamToolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                MonoIcon(icon: .magnifyingGlass, size: 14, color: .white.opacity(0.42))

                TextField(String(localized: "debug_search_placeholder"), text: $model.searchText)
                    .focused($searchFocused)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .monoTextInputBehavior()
                    .monoOnSubmit(text: $model.searchText) { _ in
                        searchFocused = false
                    }

                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        MonoIcon(icon: .xmarkCircle, size: 14, color: .white.opacity(0.45))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "common_clear"))
                }
            }
            .padding(.leading, 13)
            .padding(.trailing, 7)
            .frame(height: 43)
            .background(Color.white.opacity(searchFocused ? 0.09 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(searchFocused ? Color.cyan.opacity(0.48) : Color.white.opacity(0.05), lineWidth: 0.7)
            }

            Text("\(model.visibleEntries.count)")
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
                .frame(minWidth: 34, minHeight: 34)
                .padding(.horizontal, 4)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .monospacedDigit()
        }
        .animation(.easeOut(duration: 0.16), value: searchFocused)
    }

    private var severityRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                severityButton(level: nil)

                ForEach(LogEntry.LogLevel.allCases, id: \.self) { level in
                    severityButton(level: level)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func severityButton(level: LogEntry.LogLevel?) -> some View {
        let selected = model.selectedLevel == level
        let tint = level?.tint ?? Color.cyan

        return Button {
            model.select(level)
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(selected ? tint : Color.white.opacity(0.28))
                    .frame(width: 6, height: 6)
                Text(level?.localizedTitle ?? String(localized: "filter_all"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                Text("\(model.count(for: level))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .opacity(0.55)
                    .monospacedDigit()
            }
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.48))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(selected ? tint.opacity(0.13) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(selected ? tint.opacity(0.28) : Color.white.opacity(0.045), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                categoryButton(category: nil)

                ForEach(LogEntry.Category.allCases, id: \.self) { category in
                    categoryButton(category: category)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func categoryButton(category: LogEntry.Category?) -> some View {
        let selected = model.selectedCategory == category
        let tint = category?.tint ?? Color.cyan

        return Button {
            model.select(category: category)
        } label: {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(selected ? tint : Color.white.opacity(0.25))
                    .frame(width: 7, height: 7)

                Text(category?.localizedTitle ?? String(localized: "debug_category_all"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))

                Text("\(model.count(for: category))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .opacity(0.55)
                    .monospacedDigit()
            }
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.48))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(selected ? tint.opacity(0.13) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(selected ? tint.opacity(0.28) : Color.white.opacity(0.045), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
    }

    private var logTimeline: some View {
        Group {
            if model.visibleEntries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.visibleEntries.enumerated()), id: \.element.id) { index, log in
                        NavigationLink {
                            DebugLogDetailView(log: log)
                        } label: {
                            DebugLogTimelineRow(
                                log: log,
                                isLast: index == model.visibleEntries.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                        .id(log.id)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = log.exportText
                                HapticManager.shared.success()
                            } label: {
                                Label {
                                    Text(String(localized: "debug_copy_log"))
                                } icon: {
                                    MonoSemanticIcon(semantic: .copy, fallback: .save)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.horizontal, 12)
                .debugConsoleSurface(cornerRadius: 16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            MonoIcon(icon: .logDebug, size: 27, color: .monoTextSecondary.opacity(0.45))

            Text(
                model.isFiltering
                    ? String(localized: "debug_no_matches")
                    : String(localized: "debug_empty")
            )
            .font(.system(size: 13.5, weight: .medium, design: .rounded))
            .foregroundColor(.monoTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .debugConsoleSurface(cornerRadius: 16)
    }

    private func scrollToLatest(_ identifier: UUID?, proxy: ScrollViewProxy) {
        guard model.followsLatest, let identifier else { return }
        proxy.scrollTo(identifier, anchor: model.newestFirst ? .top : .bottom)
    }

    private var moreMenuContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            MonoMoreMenuSection(title: String(localized: "more_menu_log_section")) {
                MonoMoreMenuGroup {
                    MonoMoreMenuRow(
                        icon: .share,
                        title: String(localized: "debug_export_filtered"),
                        trailingText: "\(model.visibleEntries.count)",
                        isEnabled: !model.visibleEntries.isEmpty
                    ) {
                        presentShare(model.textExport(filtered: true))
                    }

                    MonoMoreMenuDivider()

                    MonoMoreMenuRow(
                        icon: .save,
                        title: String(localized: "debug_export_all_json"),
                        trailingText: "\(model.totalCount)",
                        isEnabled: model.totalCount > 0
                    ) {
                        presentShare(model.jsonExport())
                    }

                    MonoMoreMenuDivider()

                    MonoMoreMenuRow(
                        icon: .waveform,
                        title: String(localized: "debug_export_silence_diagnostics"),
                        isEnabled: model.hasSilenceDiagnostics
                    ) {
                        presentShare(model.silenceDiagnosticsExport())
                    }

                    MonoMoreMenuDivider()

                    MonoMoreMenuRow(
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

            MonoMoreMenuSection(title: String(localized: "more_menu_options_section")) {
                MonoMoreMenuGroup {
                    MonoMoreMenuToggleRow(
                        icon: .waveform,
                        title: String(localized: "debug_collection"),
                        isOn: $model.isCollecting
                    )

                    MonoMoreMenuDivider()

                    MonoMoreMenuToggleRow(
                        icon: .arrowDownToLine,
                        title: String(localized: "debug_newest_first"),
                        isOn: $model.newestFirst
                    )

                    MonoMoreMenuDivider()

                    MonoMoreMenuToggleRow(
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

private struct DebugLogTimelineRow: View {
    let log: LogEntry
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(log.formattedTime)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
                .monospacedDigit()
                .frame(width: 54, alignment: .leading)
                .padding(.top, 3)

            VStack(spacing: 0) {
                Circle()
                    .fill(log.level.tint)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(log.level.tint.opacity(0.25), lineWidth: 5))
                    .padding(.top, 5)

                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 5)
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(log.level.localizedTitle)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(log.level.tint)

                    Text(log.category.localizedTitle)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(log.category.tint)
                        .lineLimit(1)

                    Text(log.sourceDescription)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if log.repeatCount > 1 {
                        Text("×\(log.repeatCount)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan.opacity(0.72))
                            .monospacedDigit()
                    }

                    MonoIcon(icon: .chevronRight, size: 8, color: .white.opacity(0.22))
                }

                Text(log.message)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.86))
                    .lineLimit(3)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)

                if log.resolvedStep != "—" {
                    Text(log.resolvedStep)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.36))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
            .padding(.leading, 5)
            .padding(.bottom, isLast ? 16 : 20)
        }
        .padding(.top, 15)
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
    
    var icon: MonoIcon.IconType {
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

private extension LogEntry.Category {
    var localizedTitle: String {
        switch self {
        case .app: return String(localized: "debug_category_app")
        case .playback: return String(localized: "debug_category_playback")
        case .audio: return String(localized: "debug_category_audio")
        case .network: return String(localized: "debug_category_network")
        case .appleMusic: return String(localized: "debug_category_appleMusic")
        case .lyrics: return String(localized: "debug_category_lyrics")
        case .ai: return String(localized: "debug_category_ai")
        case .cloud: return String(localized: "debug_category_cloud")
        case .database: return String(localized: "debug_category_database")
        case .download: return String(localized: "debug_category_download")
        case .session: return String(localized: "debug_category_session")
        case .interface: return String(localized: "debug_category_interface")
        case .other: return String(localized: "debug_category_other")
        }
    }

    var tint: Color {
        switch self {
        case .app: return .indigo
        case .playback: return .green
        case .audio: return .mint
        case .network: return .cyan
        case .appleMusic: return .pink
        case .lyrics: return .purple
        case .ai: return .blue
        case .cloud: return .teal
        case .database: return .brown
        case .download: return .orange
        case .session: return .yellow
        case .interface: return .gray
        case .other: return .white.opacity(0.65)
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
                || normalizedFunction.contains("__mono")
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

    @State private var copiedTarget: CopyTarget?
    @State private var selectedPanel: DetailPanel = .message

    private enum CopyTarget {
        case message
        case log
    }

    private enum DetailPanel: CaseIterable, Hashable {
        case message
        case context
        case analysis

        var title: String {
            switch self {
            case .message: return String(localized: "debug_message_section")
            case .context: return String(localized: "debug_context_section")
            case .analysis: return String(localized: "debug_analysis_section")
            }
        }

        var icon: MonoIcon.IconType {
            switch self {
            case .message: return .layers
            case .context: return .infoCircle
            case .analysis: return .logDebug
            }
        }
    }

    init(log: LogEntry) {
        self.log = log
        analysis = DebugLogAnalysis(log: log)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                debugDetailBackdrop

                if geometry.size.width >= 760 {
                    wideDetailWorkspace(width: geometry.size.width)
                } else {
                    compactDetailWorkspace(width: geometry.size.width)
                }
            }
        }
        .developerDiagnosticPageChrome()
    }

    private var debugDetailBackdrop: some View {
        ZStack {
            Color(red: 0.022, green: 0.025, blue: 0.032)
            RadialGradient(
                colors: [log.level.tint.opacity(0.1), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }

    private func compactDetailWorkspace(width: CGFloat) -> some View {
        let inset: CGFloat = width < 370 ? 12 : 16

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                compactDetailHeader
                detailSegment
                detailPanelContent
                FloatingBarBottomSpacer()
            }
            .padding(.horizontal, inset)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func wideDetailWorkspace(width: CGFloat) -> some View {
        let workspaceWidth = min(width - 40, 1120)

        return HStack(spacing: 0) {
            Spacer(minLength: 20)

            HStack(spacing: 0) {
                detailSidebar
                    .frame(width: 250)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 0.5)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(selectedPanel.title)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(analysis.kind.localizedTitle)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(log.level.tint)
                        }

                        detailPanelContent
                        FloatingBarBottomSpacer()
                    }
                    .padding(22)
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: workspaceWidth)
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 0.7)
            }
            .padding(.vertical, 12)
            .frame(maxHeight: .infinity)

            Spacer(minLength: 20)
        }
    }

    private var compactDetailHeader: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "debug_detail_title"))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text(log.detailedTimestamp)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                MonoIcon(icon: log.level.icon, size: 18, color: log.level.tint)
                    .frame(width: 44, height: 44)
                    .background(log.level.tint.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.level.localizedTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(log.level.tint)

                    Text(log.sourceDescription)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)

                    if log.resolvedStep != "—" {
                        Text(log.resolvedStep)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.36))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)
                compactCopyActions
            }
            .padding(14)
            .debugConsoleSurface(cornerRadius: 16, tint: log.level.tint.opacity(0.025))
        }
    }

    private var compactCopyActions: some View {
        HStack(spacing: 7) {
            iconCopyButton(icon: .layers, target: .message, value: log.message)
            iconCopyButton(icon: .share, target: .log, value: log.exportText)
        }
    }

    private func iconCopyButton(
        icon: MonoIcon.IconType,
        target: CopyTarget,
        value: String
    ) -> some View {
        Button {
            copy(value, target: target)
        } label: {
            MonoIcon(
                icon: copiedTarget == target ? .checkmark : icon,
                size: 13,
                color: copiedTarget == target ? .green : .white.opacity(0.72)
            )
            .monoIconArtwork(copiedTarget == target ? nil : MonoGlyphSemantic.copy.rawValue)
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var detailSegment: some View {
        HStack(spacing: 4) {
            ForEach(DetailPanel.allCases, id: \.self) { panel in
                detailPanelButton(panel, compact: true)
            }
        }
        .padding(4)
        .debugConsoleSurface(cornerRadius: 14)
    }

    private var detailSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                MonoIcon(icon: log.level.icon, size: 21, color: log.level.tint)
                    .frame(width: 46, height: 46)
                    .background(log.level.tint.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(String(localized: "debug_detail_title"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(log.level.localizedTitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(log.level.tint)

                Text(log.detailedTimestamp)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
            }
            .padding(20)

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)

            VStack(spacing: 5) {
                ForEach(DetailPanel.allCases, id: \.self) { panel in
                    detailPanelButton(panel, compact: false)
                }
            }
            .padding(12)

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)

            VStack(alignment: .leading, spacing: 6) {
                Text(log.sourceDescription)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(3)

                if log.resolvedStep != "—" {
                    Text(log.resolvedStep)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.34))
                        .lineLimit(4)
                }
            }
            .padding(16)

            Spacer(minLength: 12)

            VStack(spacing: 8) {
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
            .padding(14)
        }
    }

    private func detailPanelButton(_ panel: DetailPanel, compact: Bool) -> some View {
        let selected = selectedPanel == panel

        return Button {
            selectedPanel = panel
            HapticManager.shared.selection()
        } label: {
            HStack(spacing: 8) {
                MonoIcon(
                    icon: panel.icon,
                    size: 12,
                    color: selected ? .black : .white.opacity(0.45)
                )
                Text(panel.title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Color.black : Color.white.opacity(0.5))
                if !compact { Spacer() }
            }
            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            .padding(.horizontal, compact ? 8 : 12)
            .frame(height: compact ? 39 : 42)
            .background(selected ? Color.white.opacity(0.9) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailPanelContent: some View {
        switch selectedPanel {
        case .message:
            messageSection
        case .context:
            metadataSection
        case .analysis:
            analysisSection
        }
    }

    private func copyButton(
        title: String,
        icon: MonoIcon.IconType,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                MonoIcon(
                    icon: icon,
                    size: 14,
                    color: isPrimary ? .black : .white.opacity(0.78)
                )
                .monoIconArtwork(MonoGlyphSemantic.copy.rawValue)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isPrimary ? .black : .white.opacity(0.78))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .debugConsoleSurface(
                cornerRadius: 12,
                tint: isPrimary
                    ? Color.white.opacity(0.88)
                    : Color.white.opacity(0.02)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var metadataSection: some View {
        VStack(spacing: 0) {
            metadataRow(String(localized: "debug_category"), log.category.localizedTitle)
            detailDivider

            metadataRow(String(localized: "debug_event"), log.resolvedEvent)
            detailDivider

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
                String(localized: "debug_session"),
                log.sessionID.isEmpty ? "—" : log.sessionID
            )
            detailDivider

            metadataRow(
                String(localized: "debug_repeat_count"),
                "\(log.repeatCount)"
            )

            ForEach(log.context.keys.sorted(), id: \.self) { key in
                detailDivider
                metadataRow(key, log.context[key] ?? "—")
            }

            detailDivider
            metadataRow(
                String(localized: "debug_path"),
                log.file.isEmpty ? "—" : log.file
            )
        }
        .debugConsoleSurface(cornerRadius: 14)
    }

    private var messageSection: some View {
        Text(log.message)
            .font(.system(size: 12.25, weight: .regular, design: .monospaced))
            .foregroundColor(.white.opacity(0.88))
            .lineSpacing(5)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .debugConsoleSurface(cornerRadius: 14, tint: log.level.tint.opacity(0.018))
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
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
                .debugConsoleSurface(cornerRadius: 14)
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
                    .debugConsoleSurface(cornerRadius: 12)
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
                        .foregroundColor(.monoTextPrimary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .debugConsoleSurface(cornerRadius: 12)
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
                            .foregroundColor(.monoTextPrimary)
                            .textSelection(.enabled)

                        Text(frame.location)
                            .font(.system(size: 10.75, weight: .medium, design: .monospaced))
                            .foregroundColor(.monoTextSecondary)
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
            .debugConsoleSurface(cornerRadius: 12)
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
            .debugConsoleSurface(cornerRadius: 12)
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
                                    .foregroundColor(.monoAccent)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 8)

                                MonoIcon(icon: .chevronRight, size: 9, color: .monoTextSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(value)
                            .font(.system(size: 11.25, weight: .medium, design: .monospaced))
                            .foregroundColor(.monoTextPrimary)
                            .textSelection(.enabled)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }

                    if index < analysis.links.count - 1 {
                        detailDivider
                    }
                }
            }
            .debugConsoleSurface(cornerRadius: 12)
        }
    }

    private func parsedJSON(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("JSON")

            Text(value)
                .font(.system(size: 11.25, weight: .regular, design: .monospaced))
                .foregroundColor(.monoTextPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .debugConsoleSurface(cornerRadius: 12)
        }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.monoTextSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 11.75, weight: .semibold, design: .monospaced))
                .foregroundColor(.monoTextPrimary)
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
            .fill(Color.monoSeparator)
            .frame(height: 0.5)
            .padding(.leading, 14)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.monoTextSecondary)
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
    func debugConsoleSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.045, green: 0.05, blue: 0.061))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.65)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

}

private struct DebugLogShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
