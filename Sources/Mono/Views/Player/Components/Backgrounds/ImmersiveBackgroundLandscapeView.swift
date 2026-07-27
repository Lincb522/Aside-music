import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ImmersiveBackgroundLandscapeView: View {
    private enum BindTarget: Hashable {
        case song
        case global
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var backgrounds = ImmersiveBackgroundManager.shared
    @ObservedObject private var player = PlayerManager.shared

    @State private var target: BindTarget = .song
    @State private var showFileImporter = false
    @State private var showMoeWalls = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importError: String?

    let palette: AriaPalette

    init(palette: AriaPalette = .fallback) {
        self.palette = palette
    }

    private var songID: Int? { player.currentSong?.id }

    private var currentBoundVideoID: String? {
        switch target {
        case .song:
            guard let songID else { return nil }
            return backgrounds.boundVideoId(forSong: songID)
        case .global:
            return backgrounds.boundGlobalVideoId()
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let compactHeight = proxy.size.height < 500
            let sideWidth = min(max(proxy.size.width * 0.27, 224), 306)
            let horizontalInset = max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing) + 14

            ZStack {
                backdrop

                VStack(spacing: compactHeight ? 8 : 12) {
                    header

                    HStack(alignment: .top, spacing: 12) {
                        controlPanel(compactHeight: compactHeight)
                            .frame(width: sideWidth)

                        libraryPanel(compactHeight: compactHeight)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
                }
            }
        }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await importFromPhotos(item) }
        }
        .fullScreenCover(isPresented: $showMoeWalls) {
            MoeWallsLandscapeBrowserView(
                palette: palette,
                isInUse: { video in currentBoundVideoID == video.id },
                onUse: { video in applyBinding(video.id) }
            )
        }
        .onAppear {
            OrientationManager.shared.enterLandscape()
            if songID == nil { target = .global }
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.86)
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.17),
                    Color.black.opacity(0.14),
                    palette.primary.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.28)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                MonoIcon(icon: .back, size: 17, color: .white.opacity(0.92))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(String(localized: "action_back"))

            Text(String(localized: "immersive_bg_title"))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Text(player.currentSong?.name ?? String(localized: "not_playing"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
                .frame(maxWidth: 280, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func controlPanel(compactHeight: Bool) -> some View {
        landscapePanel {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: compactHeight ? 10 : 14) {
                    panelTitle(String(localized: "immersive_bg_bind_target"))

                    VStack(spacing: 7) {
                        targetButton(
                            .song,
                            icon: .musicNote,
                            title: String(localized: "immersive_bg_target_song"),
                            subtitle: player.currentSong?.name
                        )
                        .disabled(songID == nil)
                        .opacity(songID == nil ? 0.42 : 1)

                        targetButton(
                            .global,
                            icon: .immersive,
                            title: String(localized: "全局沉浸模式"),
                            subtitle: String(localized: "所有未单独绑定的歌曲")
                        )
                    }

                    currentBinding

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    panelTitle(String(localized: "immersive_bg_sources"))

                    VStack(spacing: 7) {
                        HStack(spacing: 7) {
                            PhotosPicker(
                                selection: $photoPickerItem,
                                matching: .videos,
                                photoLibrary: .shared()
                            ) {
                                LandscapeSourceButtonLabel(
                                    icon: .album,
                                    title: String(localized: "immersive_bg_from_photos"),
                                    accent: palette.accent
                                )
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                            .disabled(isImporting)

                            Button { showFileImporter = true } label: {
                                LandscapeSourceButtonLabel(
                                    icon: .arrowDownToLine,
                                    title: String(localized: "immersive_bg_from_files"),
                                    accent: palette.accent
                                )
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                            .disabled(isImporting)
                        }

                        Button { showMoeWalls = true } label: {
                            HStack(spacing: 9) {
                                MonoIcon(icon: .search, size: 14, color: palette.accent)
                                Text(String(localized: "immersive_bg_moewalls"))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.9))
                                Spacer(minLength: 0)
                                MonoIcon(icon: .chevronRight, size: 10, color: .white.opacity(0.34))
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.055))
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                        .disabled(isImporting)
                    }

                    if let importError {
                        HStack(spacing: 7) {
                            MonoIcon(icon: .warning, size: 12, color: .monoAccentRed)
                            Text(importError)
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.monoAccentRed)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .overlay {
                if isImporting {
                    HStack(spacing: 9) {
                        ProgressView().tint(.white).controlSize(.small)
                        Text(String(localized: "immersive_bg_importing"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.58))
                }
            }
        }
    }

    private func targetButton(
        _ value: BindTarget,
        icon: MonoIcon.IconType,
        title: String,
        subtitle: String?
    ) -> some View {
        let selected = target == value

        return Button {
            if reduceMotion {
                target = value
            } else {
                withAnimation(.easeOut(duration: 0.2)) { target = value }
            }
        } label: {
            HStack(spacing: 9) {
                MonoIcon(
                    icon: icon,
                    size: 14,
                    color: selected ? palette.accent : .white.opacity(0.56)
                )
                .frame(width: 27, height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? palette.accent.opacity(0.13) : Color.white.opacity(0.045))
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(selected ? 0.96 : 0.66))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(selected ? 0.5 : 0.3))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(selected ? palette.accent : Color.white.opacity(0.12))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? palette.accent.opacity(0.1) : Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(selected ? palette.accent.opacity(0.38) : Color.white.opacity(0.055), lineWidth: 1)
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
    }

    @ViewBuilder
    private var currentBinding: some View {
        if let id = currentBoundVideoID, let video = backgrounds.video(withId: id) {
            HStack(spacing: 9) {
                VideoThumbnailView(url: backgrounds.fileURL(for: video), id: video.id)
                    .frame(width: 62, height: 35)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(video.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                    Text(String(localized: "immersive_bg_in_use"))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }

                Spacer(minLength: 0)

                Button {
                    HapticManager.shared.light()
                    applyBinding(nil)
                } label: {
                    MonoIcon(icon: .close, size: 10, color: .monoAccentRed)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.monoAccentRed.opacity(0.12)))
                }
                .buttonStyle(MonoBouncingButtonStyle())
                .accessibilityLabel(String(localized: "immersive_bg_unbind"))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
        } else {
            Text(String(localized: "immersive_bg_no_binding"))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.34))
        }
    }

    private func libraryPanel(compactHeight: Bool) -> some View {
        landscapePanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(String(localized: "immersive_bg_library_section"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                    Text("\(backgrounds.library.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.34))
                    Spacer()
                }

                if backgrounds.library.isEmpty {
                    VStack(spacing: 10) {
                        MonoIcon(icon: .mv, size: 27, color: .white.opacity(0.24))
                        Text(String(localized: "immersive_bg_empty"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(
                                        minimum: compactHeight ? 142 : 168,
                                        maximum: compactHeight ? 218 : 260
                                    ),
                                    spacing: 10
                                )
                            ],
                            spacing: 10
                        ) {
                            ForEach(backgrounds.library) { video in
                                landscapeLibraryCard(video)
                            }
                        }
                    }
                }
            }
        }
    }

    private func landscapeLibraryCard(_ video: ImmersiveVideo) -> some View {
        let selected = currentBoundVideoID == video.id

        return Button {
            HapticManager.shared.light()
            applyBinding(selected ? nil : video.id)
        } label: {
            ZStack(alignment: .bottomLeading) {
                VideoThumbnailView(url: backgrounds.fileURL(for: video), id: video.id)
                    .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.76)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                Text(video.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.bottom, 7)
            }
            .overlay(alignment: .topLeading) {
                if selected {
                    MonoIcon(icon: .checkmark, size: 10, color: .white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(palette.accent))
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    HapticManager.shared.light()
                    backgrounds.delete(video)
                } label: {
                    MonoIcon(icon: .trash, size: 10, color: .white.opacity(0.9))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .padding(5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? palette.accent : Color.white.opacity(0.075), lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
    }

    private func landscapePanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }

    private func panelTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.44))
            .textCase(.uppercase)
    }

    private func applyBinding(_ videoID: String?) {
        switch target {
        case .song:
            guard let songID else { return }
            backgrounds.bindSong(songID, to: videoID)
        case .global:
            backgrounds.bindGlobal(to: videoID)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        importError = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            Task {
                defer { isImporting = false }
                guard await LandscapeVideoImportSupport.videoWithin4K(url) else {
                    importError = String(localized: "视频分辨率超过 4K，无法导入")
                    return
                }
                if let video = backgrounds.importVideo(from: url) {
                    applyBinding(video.id)
                } else {
                    importError = String(localized: "immersive_bg_import_failed")
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func importFromPhotos(_ item: PhotosPickerItem) async {
        importError = nil
        isImporting = true
        defer {
            isImporting = false
            photoPickerItem = nil
        }

        do {
            guard let picked = try await item.loadTransferable(type: LandscapePickedImmersiveVideo.self) else {
                importError = String(localized: "immersive_bg_import_failed")
                return
            }
            defer { try? FileManager.default.removeItem(at: picked.url) }

            guard await LandscapeVideoImportSupport.videoWithin4K(picked.url) else {
                importError = String(localized: "视频分辨率超过 4K，无法导入")
                return
            }

            let name = Date().formatted(.dateTime.month().day().hour().minute())
            if let video = backgrounds.importVideo(
                from: picked.url,
                displayName: String(localized: "immersive_bg_photos_name_prefix") + " " + name
            ) {
                applyBinding(video.id)
            } else {
                importError = String(localized: "immersive_bg_import_failed")
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct LandscapeSourceButtonLabel: View {
    let icon: MonoIcon.IconType
    let title: String
    let accent: Color

    var body: some View {
        VStack(spacing: 5) {
            MonoIcon(icon: icon, size: 14, color: accent)
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

private struct LandscapePickedImmersiveVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("immersive-landscape-import-\(UUID().uuidString)")
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}

private enum LandscapeVideoImportSupport {
    static func videoWithin4K(_ url: URL) async -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else {
            return true
        }
        let rect = CGRect(origin: .zero, size: size).applying(transform)
        return max(abs(rect.width), abs(rect.height)) <= 4200
            && min(abs(rect.width), abs(rect.height)) <= 2400
    }
}

@MainActor
struct MoeWallsLandscapeBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var backgrounds = ImmersiveBackgroundManager.shared
    @StateObject private var model = MoeWallsBrowserViewModel()
    @FocusState private var searchFocused: Bool

    let palette: AriaPalette
    let isInUse: (ImmersiveVideo) -> Bool
    let onUse: (ImmersiveVideo) -> Void

    var body: some View {
        GeometryReader { proxy in
            let compactHeight = proxy.size.height < 500
            let resultsWidth = min(max(proxy.size.width * 0.34, 252), 390)
            let inset = max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing) + 12

            ZStack {
                landscapeBackdrop

                VStack(spacing: compactHeight ? 8 : 12) {
                    browserHeader

                    HStack(alignment: .top, spacing: 12) {
                        previewPanel(compactHeight: compactHeight)
                            .frame(maxWidth: .infinity)

                        resultsPanel(compactHeight: compactHeight)
                            .frame(width: resultsWidth)
                    }
                    .padding(.horizontal, inset)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
                }
            }
        }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task { model.loadIfNeeded() }
        .onAppear { OrientationManager.shared.enterLandscape() }
    }

    private var landscapeBackdrop: some View {
        ZStack {
            Color(red: 0.045, green: 0.047, blue: 0.058)
            LinearGradient(
                colors: [palette.accent.opacity(0.17), .clear, palette.primary.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var browserHeader: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                MonoIcon(icon: .back, size: 17, color: .white.opacity(0.92))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(String(localized: "action_back"))

            Text("MoeWalls")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                MonoIcon(icon: .search, size: 14, color: .white.opacity(0.44))

                TextField(String(localized: "moewalls_search_placeholder"), text: $model.query)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { submitSearch() }

                Button {
                    searchFocused = false
                    model.loadDaily()
                } label: {
                    MonoIcon(icon: .close, size: 10, color: .white.opacity(0.65))
                        .frame(width: 27, height: 27)
                }
                .buttonStyle(.plain)
                .opacity(model.query.isEmpty ? 0 : 1)
                .allowsHitTesting(!model.query.isEmpty)
                .accessibilityHidden(model.query.isEmpty)
                .accessibilityLabel(String(localized: "action_clear"))

                Button { submitSearch() } label: {
                    Group {
                        if model.isSearching {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            MonoIcon(icon: .search, size: 13, color: .white)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(palette.accent.opacity(0.9)))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                .accessibilityLabel(
                    String(localized: model.isSearching ? "moewalls_searching" : "action_search")
                )
            }
            .padding(.leading, 12)
            .padding(.trailing, 5)
            .frame(maxWidth: 460)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.065))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(searchFocused ? palette.accent.opacity(0.58) : Color.white.opacity(0.07), lineWidth: 1)
            )

            Button { model.retryCurrentList() } label: {
                MonoIcon(icon: .refresh, size: 15, color: .white.opacity(0.82))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .disabled(model.isLoadingList)
            .accessibilityLabel(String(localized: "action_retry"))
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func previewPanel(compactHeight: Bool) -> some View {
        if let wallpaper = model.selectedWallpaper {
            landscapePanel {
                VStack(spacing: 8) {
                    ZStack(alignment: .bottomLeading) {
                        MoeWallsLandscapePoster(url: wallpaper.thumbnailURL)

                        if let detail = model.detail,
                           detail.wallpaper.id == wallpaper.id {
                            ImmersiveVideoBackground(url: detail.hdDownloadURL)
                                .transition(.opacity)
                        }

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.76)],
                            startPoint: .center,
                            endPoint: .bottom
                        )

                        HStack(alignment: .bottom, spacing: 10) {
                            Text(wallpaper.title)
                                .font(.system(size: compactHeight ? 13 : 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Text(wallpaper.quality)
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.48)))
                        }
                        .padding(compactHeight ? 10 : 13)

                        if model.isLoadingDetail {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.14))
                        }

                        if model.detailErrorMessage != nil {
                            Button { model.retryDetail() } label: {
                                MonoIcon(icon: .refresh, size: 15, color: .white)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .buttonStyle(MonoBouncingButtonStyle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    landscapePreviewActions(wallpaper)
                }
            }
        } else {
            landscapePanel {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func landscapePreviewActions(_ wallpaper: MoeWallsWallpaper) -> some View {
        let existing = backgrounds.video(sourceIdentifier: wallpaper.id, sourceName: "MoeWalls")
        let inUse = existing.map(isInUse) ?? false
        let downloading = model.downloadingWallpaperID == wallpaper.id
        let progress = min(max(model.downloadProgress, 0), 1)

        return HStack(spacing: 8) {
            Button {
                if let existing {
                    HapticManager.shared.light()
                    onUse(existing)
                } else {
                    downloadAndUse(wallpaper, quality: .hd)
                }
            } label: {
                HStack(spacing: 7) {
                    MonoIcon(
                        icon: downloading ? .download : (inUse ? .checkmark : (existing == nil ? .download : .play)),
                        size: 13,
                        color: .white
                    )
                    Text(
                        downloading
                            ? "\(Int((progress * 100).rounded()))%"
                            : primaryActionTitle(inUse: inUse, hasExistingVideo: existing != nil)
                    )
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(inUse ? Color.white.opacity(0.09) : palette.accent.opacity(downloading ? 0.18 : 0.88))
                        if downloading {
                            Rectangle()
                                .fill(palette.accent.opacity(0.92))
                                .scaleEffect(x: progress, y: 1, anchor: .leading)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: progress)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
            .disabled(inUse || downloading || model.detail == nil)
            .accessibilityValue(downloading ? "\(Int((progress * 100).rounded()))%" : "")

            if existing == nil, model.detail?.fourKDownloadURL != nil {
                Menu {
                    Button(String(localized: "moewalls_download_hd")) {
                        downloadAndUse(wallpaper, quality: .hd)
                    }
                    Button(String(localized: "moewalls_download_4k")) {
                        downloadAndUse(wallpaper, quality: .fourK)
                    }
                } label: {
                    MonoIcon(icon: .more, size: 16, color: .white.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
                }
                .disabled(downloading)
                .accessibilityLabel(String(localized: "moewalls_quality"))
            }
        }
    }

    private func resultsPanel(compactHeight: Bool) -> some View {
        landscapePanel {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(sectionTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer()
                    if !model.isLoadingList {
                        Text("\(model.wallpapers.count)")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.34))
                    }
                }

                if model.isEmptySearchResult {
                    landscapeEmptyState
                } else if let errorMessage = model.errorMessage {
                    landscapeError(errorMessage)
                } else if model.isLoadingList {
                    landscapeLoadingGrid(compactHeight: compactHeight)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(
                                        minimum: compactHeight ? 104 : 130,
                                        maximum: compactHeight ? 170 : 220
                                    ),
                                    spacing: 8
                                )
                            ],
                            spacing: 8
                        ) {
                            ForEach(model.wallpapers) { wallpaper in
                                landscapeWallpaperCard(wallpaper)
                            }
                        }
                    }
                }

                if let error = model.downloadErrorMessage {
                    landscapeError(error)
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

    private func landscapeWallpaperCard(_ wallpaper: MoeWallsWallpaper) -> some View {
        let selected = model.selectedWallpaper?.id == wallpaper.id

        return Button { model.select(wallpaper) } label: {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: wallpaper.thumbnailURL, width: 320, height: 180) {
                    Rectangle().fill(Color.white.opacity(0.055))
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.76)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                Text(wallpaper.title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.bottom, 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(selected ? palette.accent : Color.white.opacity(0.065), lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
    }

    private func landscapeLoadingGrid(compactHeight: Bool) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: compactHeight ? 104 : 130, maximum: 220), spacing: 8)],
            spacing: 8
        ) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            }
        }
    }

    private func landscapeError(_ message: String) -> some View {
        HStack(spacing: 7) {
            MonoIcon(icon: .warning, size: 11, color: .monoAccentRed)
            Text(message)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.monoAccentRed.opacity(0.1))
        )
    }

    private var landscapeEmptyState: some View {
        VStack(spacing: 7) {
            MonoIcon(icon: .search, size: 18, color: .white.opacity(0.36))
            Text(String(localized: "moewalls_empty"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func landscapePanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.2))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }

    private func submitSearch() {
        searchFocused = false
        // 等待中文输入法提交组合文本，避免读到空值后误清空搜索框。
        DispatchQueue.main.async {
            model.submitSearch()
        }
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
            guard let video = await model.downloadAndImport(wallpaper, quality: quality) else { return }
            HapticManager.shared.success()
            onUse(video)
        }
    }
}

private struct MoeWallsLandscapePoster: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            case .empty:
                Rectangle().fill(Color.white.opacity(0.055))
            case .failure:
                Rectangle()
                    .fill(Color.white.opacity(0.055))
                    .overlay(MonoIcon(icon: .mv, size: 24, color: .white.opacity(0.28)))
            @unknown default:
                Rectangle().fill(Color.white.opacity(0.055))
            }
        }
        .clipped()
    }
}
