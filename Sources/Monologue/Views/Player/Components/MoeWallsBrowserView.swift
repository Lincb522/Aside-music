import SwiftUI

@MainActor
private final class MoeWallsQueryTranslator {
    static let shared = MoeWallsQueryTranslator()

    private struct Output: Decodable {
        let query: String
    }

    private let client = AIProviderClient()
    private let providerStore = AIProviderConfigurationStore.shared
    private var cache: [String: String] = [:]

    func englishQuery(for query: String) async -> String? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard containsChinese(normalized) else { return nil }

        let cacheKey = normalized.lowercased()
        if let cached = cache[cacheKey] { return cached }

        if let local = MoeWallsService.localEnglishTranslation(for: normalized),
           !containsChinese(local) {
            cache[cacheKey] = local
            return local
        }

        let configuration = providerStore.configuration
        let apiKey = providerStore.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !configuration.wireProtocol.requiresAPIKey || !apiKey.isEmpty else { return nil }

        do {
            let response = try await client.generate(
                systemPrompt: """
                You translate Chinese wallpaper search queries into concise English search keywords.
                Preserve character, game, anime, movie, place, and artist names using their official English names.
                Return JSON only: {"query":"english keywords"}. Do not explain.
                """,
                userPrompt: normalized,
                configuration: configuration,
                apiKey: apiKey
            )
            try Task.checkCancellation()
            guard let translated = decode(response), !containsChinese(translated) else { return nil }
            cache[cacheKey] = translated
            if cache.count > 128, let oldest = cache.keys.first { cache.removeValue(forKey: oldest) }
            return translated
        } catch is CancellationError {
            return nil
        } catch {
            AppLogger.warning("[MoeWalls] 中文搜索转译失败：\(error.localizedDescription)")
            return nil
        }
    }

    private func decode(_ rawValue: String) -> String? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = value.firstIndex(of: "{"),
           let end = value.lastIndex(of: "}"),
           start <= end,
           let data = String(value[start...end]).data(using: .utf8),
           let output = try? JSONDecoder().decode(Output.self, from: data) {
            value = output.query
        }

        value = value.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))
        )
        guard !value.isEmpty, value.count <= 100 else { return nil }
        return value
    }

    private func containsChinese(_ value: String) -> Bool {
        value.range(of: #"\p{Han}"#, options: .regularExpression) != nil
    }
}

@MainActor
final class MoeWallsBrowserViewModel: ObservableObject {
    enum ContentMode: Equatable {
        case daily
        case search(String)
    }

    @Published var query = ""
    @Published private(set) var mode: ContentMode = .daily
    @Published private(set) var wallpapers: [MoeWallsWallpaper] = []
    @Published private(set) var selectedWallpaper: MoeWallsWallpaper?
    @Published private(set) var detail: MoeWallsWallpaperDetail?
    @Published private(set) var isLoadingList = false
    @Published private(set) var isLoadingDetail = false
    @Published private(set) var downloadingWallpaperID: String?
    @Published private(set) var downloadProgress = 0.0
    @Published private(set) var errorMessage: String?
    @Published private(set) var downloadErrorMessage: String?
    @Published private(set) var detailErrorMessage: String?
    @Published private(set) var isEmptySearchResult = false

    private let service: MoeWallsService
    private let backgrounds: ImmersiveBackgroundManager
    private let queryTranslator = MoeWallsQueryTranslator.shared
    private var listTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var listRequestID: UUID?

    var isSearching: Bool {
        guard isLoadingList else { return false }
        if case .search = mode { return true }
        return false
    }

    init(
        service: MoeWallsService = .shared,
        backgrounds: ImmersiveBackgroundManager = .shared
    ) {
        self.service = service
        self.backgrounds = backgrounds
    }

    func loadIfNeeded() {
        guard wallpapers.isEmpty, !isLoadingList else { return }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            submitSearch()
            return
        }
        loadDaily()
    }

    func loadDaily(forceRefresh: Bool = false) {
        query = ""
        mode = .daily
        listTask?.cancel()
        let requestID = UUID()
        listRequestID = requestID
        listTask = Task { [weak self] in
            guard let self else { return }
            isLoadingList = true
            errorMessage = nil
            isEmptySearchResult = false
            defer {
                if listRequestID == requestID { isLoadingList = false }
            }
            do {
                let results = try await service.dailyRecommendations(forceRefresh: forceRefresh)
                try Task.checkCancellation()
                guard listRequestID == requestID else { return }
                applyList(results)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, listRequestID == requestID else { return }
                wallpapers = []
                selectedWallpaper = nil
                detail = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    func submitSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // 中文输入法结束组合文本前可能短暂提交空值；空搜索不应清除当前输入。
        guard !term.isEmpty else { return }

        mode = .search(term)
        listTask?.cancel()
        let requestID = UUID()
        listRequestID = requestID
        listTask = Task { [weak self] in
            guard let self else { return }
            isLoadingList = true
            errorMessage = nil
            isEmptySearchResult = false
            defer {
                if listRequestID == requestID { isLoadingList = false }
            }
            do {
                let translated = await queryTranslator.englishQuery(for: term)
                try Task.checkCancellation()
                let results = try await service.search(
                    query: term,
                    translatedQuery: translated
                )
                try Task.checkCancellation()
                guard listRequestID == requestID else { return }
                applyList(results)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, listRequestID == requestID else { return }
                wallpapers = []
                selectedWallpaper = nil
                detail = nil
                if let serviceError = error as? MoeWallsServiceError,
                   case .emptyResults = serviceError {
                    isEmptySearchResult = true
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    func retryCurrentList() {
        switch mode {
        case .daily:
            loadDaily(forceRefresh: true)
        case .search:
            submitSearch()
        }
    }

    func select(_ wallpaper: MoeWallsWallpaper) {
        selectedWallpaper = wallpaper
        detail = nil
        detailErrorMessage = nil
        isLoadingDetail = true
        detailTask?.cancel()
        detailTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await service.detail(for: wallpaper)
                try Task.checkCancellation()
                guard selectedWallpaper?.id == wallpaper.id else { return }
                detail = loaded
            } catch is CancellationError {
                return
            } catch {
                guard selectedWallpaper?.id == wallpaper.id else { return }
                detailErrorMessage = error.localizedDescription
            }
            if selectedWallpaper?.id == wallpaper.id {
                isLoadingDetail = false
            }
        }
    }

    func retryDetail() {
        guard let selectedWallpaper else { return }
        select(selectedWallpaper)
    }

    func existingVideo(for wallpaper: MoeWallsWallpaper) -> ImmersiveVideo? {
        backgrounds.video(sourceIdentifier: wallpaper.id, sourceName: "MoeWalls")
    }

    func downloadAndImport(
        _ wallpaper: MoeWallsWallpaper,
        quality: MoeWallsDownloadQuality
    ) async -> ImmersiveVideo? {
        if let existing = existingVideo(for: wallpaper) {
            return existing
        }

        guard downloadingWallpaperID == nil else { return nil }
        downloadingWallpaperID = wallpaper.id
        downloadProgress = 0
        downloadErrorMessage = nil
        defer {
            downloadingWallpaperID = nil
            downloadProgress = 0
        }

        do {
            let resolvedDetail: MoeWallsWallpaperDetail
            if let detail, detail.wallpaper.id == wallpaper.id {
                resolvedDetail = detail
            } else {
                resolvedDetail = try await service.detail(for: wallpaper)
            }

            let temporaryURL = try await service.download(
                detail: resolvedDetail,
                quality: quality,
                progress: { [weak self] value in
                    Task { @MainActor [weak self] in
                        guard let self,
                              self.downloadingWallpaperID == wallpaper.id else { return }
                        self.downloadProgress = min(max(value, self.downloadProgress), 1)
                    }
                }
            )
            defer { try? FileManager.default.removeItem(at: temporaryURL) }

            guard let video = backgrounds.importVideo(
                from: temporaryURL,
                displayName: wallpaper.title,
                sourceIdentifier: wallpaper.id,
                sourceName: "MoeWalls"
            ) else {
                throw MoeWallsServiceError.downloadUnavailable
            }
            return video
        } catch {
            downloadErrorMessage = error.localizedDescription
            return nil
        }
    }

    private func applyList(_ results: [MoeWallsWallpaper]) {
        isEmptySearchResult = results.isEmpty
        wallpapers = results
        guard let first = results.first else {
            selectedWallpaper = nil
            detail = nil
            return
        }
        select(first)
    }
}

@MainActor
struct MoeWallsBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var backgrounds = ImmersiveBackgroundManager.shared
    @StateObject private var model = MoeWallsBrowserViewModel()
    @FocusState private var searchFocused: Bool

    let palette: AriaPalette
    let isInUse: (ImmersiveVideo) -> Bool
    let onUse: (ImmersiveVideo) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 154, maximum: 260), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let selected = model.selectedWallpaper {
                        previewSection(selected)
                    }

                    if let downloadErrorMessage = model.downloadErrorMessage {
                        compactErrorState(downloadErrorMessage)
                    }

                    if model.isEmptySearchResult {
                        searchEmptyState
                    } else if let errorMessage = model.errorMessage {
                        errorState(errorMessage)
                    } else {
                        wallpaperSection
                    }
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .background(backdrop.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            model.loadIfNeeded()
        }
    }

    private var backdrop: some View {
        ZStack {
            Color(red: 0.055, green: 0.058, blue: 0.07)
            RadialGradient(
                colors: [palette.accent.opacity(0.14), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 460
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                MonologueIcon(icon: .back, size: 18, color: .white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "action_back"))

            Text("MoeWalls")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                searchFocused = false
                model.retryCurrentList()
            } label: {
                MonologueIcon(icon: .refresh, size: 17, color: .white.opacity(0.88))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingList)
            .accessibilityLabel(String(localized: "action_retry"))
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            MonologueIcon(icon: .search, size: 16, color: .white.opacity(0.48))

            TextField(String(localized: "moewalls_search_placeholder"), text: $model.query)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit { commitSearch() }

            Button {
                searchFocused = false
                model.loadDaily()
            } label: {
                MonologueIcon(icon: .close, size: 12, color: .white.opacity(0.72))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(model.query.isEmpty ? 0 : 1)
            .allowsHitTesting(!model.query.isEmpty)
            .accessibilityHidden(model.query.isEmpty)
            .accessibilityLabel(String(localized: "action_clear"))

            Button { commitSearch() } label: {
                Group {
                    if model.isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        MonologueIcon(icon: .search, size: 15, color: .white)
                    }
                }
                .frame(width: 36, height: 36)
                .background(Circle().fill(palette.accent.opacity(0.88)))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
            .accessibilityLabel(
                String(localized: model.isSearching ? "moewalls_searching" : "action_search")
            )
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(searchFocused ? palette.accent.opacity(0.68) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: searchFocused)
    }

    private func commitSearch() {
        searchFocused = false
        // 下一轮主线程事件再读取绑定值，让中文输入法先完成候选词提交。
        DispatchQueue.main.async {
            model.submitSearch()
        }
    }

    private func previewSection(_ wallpaper: MoeWallsWallpaper) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(
                    url: wallpaper.thumbnailURL,
                    width: 900,
                    height: 506
                ) {
                    Rectangle().fill(Color.white.opacity(0.06))
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

                if let detail = model.detail,
                   detail.wallpaper.id == wallpaper.id {
                    ImmersiveVideoBackground(url: detail.previewURL)
                        .transition(.opacity)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.76)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 10) {
                    Text(wallpaper.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(wallpaper.quality)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                }
                .padding(14)

                if model.isLoadingDetail {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.12))
                }

                if model.detailErrorMessage != nil {
                    Button { model.retryDetail() } label: {
                        MonologueIcon(icon: .refresh, size: 16, color: .white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.black.opacity(0.52)))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(String(localized: "action_retry"))
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)

            previewActions(wallpaper)
                .padding(10)
        }
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.detail?.wallpaper.id)
    }

    private func previewActions(_ wallpaper: MoeWallsWallpaper) -> some View {
        let existing = backgrounds.video(
            sourceIdentifier: wallpaper.id,
            sourceName: "MoeWalls"
        )
        let inUse = existing.map(isInUse) ?? false
        let downloading = model.downloadingWallpaperID == wallpaper.id
        let downloadProgress = min(max(model.downloadProgress, 0), 1)

        return HStack(spacing: 8) {
            Button {
                if let existing {
                    HapticManager.shared.light()
                    onUse(existing)
                } else {
                    downloadAndUse(wallpaper, quality: .hd)
                }
            } label: {
                HStack(spacing: 8) {
                    if downloading {
                        MonologueIcon(icon: .download, size: 14, color: .white)
                    } else {
                        MonologueIcon(
                            icon: inUse ? .checkmark : (existing == nil ? .download : .play),
                            size: 14,
                            color: .white
                        )
                    }
                    Text(
                        downloading
                            ? "\(Int((downloadProgress * 100).rounded()))%"
                            : primaryActionTitle(inUse: inUse, hasExistingVideo: existing != nil)
                    )
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                inUse
                                    ? Color.white.opacity(0.1)
                                    : palette.accent.opacity(downloading ? 0.2 : 0.88)
                            )

                        if downloading {
                            Rectangle()
                                .fill(palette.accent.opacity(0.92))
                                .scaleEffect(x: downloadProgress, y: 1, anchor: .leading)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.16),
                    value: downloadProgress
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
            .disabled(inUse || downloading || model.detail == nil)
            .accessibilityLabel(
                downloading
                    ? String(localized: "moewalls_download_use")
                    : primaryActionTitle(inUse: inUse, hasExistingVideo: existing != nil)
            )
            .accessibilityValue(downloading ? "\(Int((downloadProgress * 100).rounded()))%" : "")

            if existing == nil, model.detail?.fourKDownloadURL != nil {
                Menu {
                    Button(String(localized: "moewalls_download_hd")) {
                        downloadAndUse(wallpaper, quality: .hd)
                    }
                    Button(String(localized: "moewalls_download_4k")) {
                        downloadAndUse(wallpaper, quality: .fourK)
                    }
                } label: {
                    MonologueIcon(icon: .more, size: 17, color: .white.opacity(0.9))
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .disabled(downloading)
                .accessibilityLabel(String(localized: "moewalls_quality"))
            }
        }
    }

    @ViewBuilder
    private var wallpaperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sectionTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if !model.isLoadingList {
                    Text("\(model.wallpapers.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            if model.isLoadingList {
                loadingGrid
            } else if model.wallpapers.isEmpty {
                errorState(String(localized: "moewalls_empty"))
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.wallpapers) { wallpaper in
                        wallpaperCard(wallpaper)
                    }
                }
            }
        }
    }

    private var sectionTitle: String {
        if model.isSearching { return String(localized: "moewalls_searching") }
        switch model.mode {
        case .daily:
            return String(localized: "moewalls_daily")
        case .search:
            return String(localized: "moewalls_search_results")
        }
    }

    private func wallpaperCard(_ wallpaper: MoeWallsWallpaper) -> some View {
        let selected = model.selectedWallpaper?.id == wallpaper.id
        return Button {
            searchFocused = false
            HapticManager.shared.light()
            model.select(wallpaper)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(
                    url: wallpaper.thumbnailURL,
                    width: 520,
                    height: 293
                ) {
                    Rectangle().fill(Color.white.opacity(0.06))
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.74)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 6) {
                    Text(wallpaper.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Text(wallpaper.quality)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .padding(10)
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(selected ? palette.accent : Color.white.opacity(0.08), lineWidth: selected ? 1.7 : 1)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
        .accessibilityLabel(wallpaper.title)
    }

    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.065))
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        HStack(spacing: 10) {
            MonologueIcon(icon: .warning, size: 14, color: .white.opacity(0.62))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(String(localized: "action_retry")) {
                model.retryCurrentList()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.accent)
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            MonologueIcon(icon: .search, size: 22, color: .white.opacity(0.42))
            Text(String(localized: "moewalls_empty"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }

    private func compactErrorState(_ message: String) -> some View {
        HStack(spacing: 9) {
            MonologueIcon(icon: .warning, size: 13, color: .monologueAccentRed)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.monologueAccentRed.opacity(0.1))
        )
    }

    private func primaryActionTitle(inUse: Bool, hasExistingVideo: Bool) -> String {
        if inUse { return String(localized: "moewalls_in_use") }
        if hasExistingVideo { return String(localized: "moewalls_use") }
        return String(localized: "moewalls_download_use")
    }

    private func downloadAndUse(
        _ wallpaper: MoeWallsWallpaper,
        quality: MoeWallsDownloadQuality
    ) {
        Task {
            guard let video = await model.downloadAndImport(wallpaper, quality: quality) else {
                return
            }
            HapticManager.shared.success()
            onUse(video)
        }
    }
}
