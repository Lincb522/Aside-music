import SwiftUI
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// 影院沉浸背景 — 从照片图库/文件导入视频，按「当前歌曲 / 当前歌单」绑定。
/// 深色影院风：暗底 + 主题色辉光，16:9 海报网格。
struct ImmersiveBackgroundSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var bgManager = ImmersiveBackgroundManager.shared
    @ObservedObject private var player = PlayerManager.shared

    enum BindTarget: Hashable { case song, context }

    @State private var target: BindTarget = .song
    @State private var showFileImporter = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importError: String?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)]

    private var songId: Int? { player.currentSong?.id }
    private var context: PlayerManager.PlayContext? {
        guard let ctx = player.playContext, ImmersiveBackgroundManager.contextBindingKey(ctx) != nil else { return nil }
        return ctx
    }

    private var currentBoundVideoId: String? {
        switch target {
        case .song:
            guard let songId else { return nil }
            return bgManager.boundVideoId(forSong: songId)
        case .context:
            guard let context else { return nil }
            return bgManager.boundVideoId(forContext: context)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    importCards
                    if let importError {
                        errorBanner(importError)
                    }
                    targetPicker
                    librarySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(sheetBackdrop.ignoresSafeArea())
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await importFromPhotos(item) }
        }
        .onAppear {
            if context == nil { target = .song }
        }
    }

    // MARK: - 背景

    private var sheetBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.09), Color(red: 0.10, green: 0.10, blue: 0.13)],
                startPoint: .top,
                endPoint: .bottom
            )
            // 顶部主题色辉光，呼应沉浸舞台
            RadialGradient(
                colors: [Color.monologueAccent.opacity(0.16), .clear],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 360
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            MonologueIcon(icon: .mv, size: 18, color: .monologueAccent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.monologueAccent.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "immersive_bg_title"))
                    .font(.rounded(size: 19, weight: .bold))
                    .foregroundColor(.white)
                Text(String(localized: "immersive_bg_subtitle"))
                    .font(.rounded(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Button(action: { dismiss() }) {
                MonologueIcon(icon: .close, size: 14, color: .white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - 导入入口

    private var importCards: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoPickerItem, matching: .videos, photoLibrary: .shared()) {
                ImportCardLabel(
                    icon: .album,
                    title: String(localized: "immersive_bg_from_photos"),
                    hint: String(localized: "immersive_bg_from_photos_hint")
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
            .disabled(isImporting)

            Button {
                showFileImporter = true
            } label: {
                ImportCardLabel(
                    icon: .arrowDownToLine,
                    title: String(localized: "immersive_bg_from_files"),
                    hint: String(localized: "immersive_bg_from_files_hint")
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
            .disabled(isImporting)
        }
        .overlay {
            if isImporting {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(String(localized: "immersive_bg_importing"))
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                )
            }
        }
    }

    /// 独立 View 结构体：PhotosPicker 的 label 闭包是 nonisolated 的，
    /// 不能直接调用主 actor 隔离的视图构建方法，构造结构体则没有隔离限制
    private struct ImportCardLabel: View {
        let icon: MonologueIcon.IconType
        let title: String
        let hint: String

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                MonologueIcon(icon: icon, size: 17, color: .monologueAccent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.monologueAccent.opacity(0.15)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.rounded(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(hint)
                        .font(.rounded(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            MonologueIcon(icon: .warning, size: 13, color: .monologueAccentRed)
            Text(message)
                .font(.rounded(size: 12, weight: .medium))
                .foregroundColor(.monologueAccentRed)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.monologueAccentRed.opacity(0.12))
        )
    }

    // MARK: - 绑定目标

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "immersive_bg_bind_target"))
                .font(.rounded(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .textCase(.uppercase)

            HStack(spacing: 10) {
                targetChip(.song, icon: .musicNote, title: String(localized: "immersive_bg_target_song"), subtitle: player.currentSong?.name)
                if context != nil {
                    targetChip(.context, icon: .musicNoteList, title: String(localized: "immersive_bg_target_playlist"), subtitle: context?.name)
                }
            }

            bindingSummary
        }
    }

    private func targetChip(_ value: BindTarget, icon: MonologueIcon.IconType, title: String, subtitle: String?) -> some View {
        let selected = target == value
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { target = value }
        } label: {
            HStack(spacing: 10) {
                MonologueIcon(icon: icon, size: 14, color: selected ? .monologueAccent : .white.opacity(0.6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.rounded(size: 13, weight: .bold))
                        .foregroundColor(selected ? .white : .white.opacity(0.65))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.rounded(size: 10, weight: .medium))
                            .foregroundColor(selected ? .white.opacity(0.6) : .white.opacity(0.35))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if selected {
                    Circle()
                        .fill(Color.monologueAccent)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.monologueAccent.opacity(0.16) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color.monologueAccent.opacity(0.5) : Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }

    @ViewBuilder
    private var bindingSummary: some View {
        if let vid = currentBoundVideoId, let v = bgManager.video(withId: vid) {
            HStack(spacing: 10) {
                VideoThumbnailView(url: bgManager.fileURL(for: v), id: v.id)
                    .frame(width: 52, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(v.displayName)
                        .font(.rounded(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                    Text(String(localized: "immersive_bg_in_use"))
                        .font(.rounded(size: 10, weight: .bold))
                        .foregroundColor(.monologueAccent)
                }

                Spacer()

                Button {
                    HapticManager.shared.light()
                    applyBinding(nil)
                } label: {
                    Text(String(localized: "immersive_bg_unbind"))
                        .font(.rounded(size: 12, weight: .semibold))
                        .foregroundColor(.monologueAccentRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.monologueAccentRed.opacity(0.12)))
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        } else {
            Text(String(localized: "immersive_bg_no_binding"))
                .font(.rounded(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .padding(.top, 2)
        }
    }

    // MARK: - 视频库

    @ViewBuilder
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !bgManager.library.isEmpty {
                HStack(spacing: 8) {
                    Text(String(localized: "immersive_bg_library_section"))
                        .font(.rounded(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .textCase(.uppercase)
                    Text("\(bgManager.library.count)")
                        .font(.rounded(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                }
            }

            if bgManager.library.isEmpty {
                emptyLibrary
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(bgManager.library) { video in
                        libraryCard(video)
                    }
                }
            }
        }
    }

    private var emptyLibrary: some View {
        VStack(spacing: 12) {
            MonologueIcon(icon: .mv, size: 30, color: .white.opacity(0.25))
            Text(String(localized: "immersive_bg_empty"))
                .font(.rounded(size: 13))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
                )
        )
    }

    private func libraryCard(_ video: ImmersiveVideo) -> some View {
        let isBound = currentBoundVideoId == video.id
        return Button {
            HapticManager.shared.light()
            applyBinding(isBound ? nil : video.id)
        } label: {
            ZStack(alignment: .bottomLeading) {
                VideoThumbnailView(url: bgManager.fileURL(for: video), id: video.id)
                    .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // 底部渐变压暗，托出片名
                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 6) {
                    Text(video.displayName)
                        .font(.rounded(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    VideoDurationBadge(url: bgManager.fileURL(for: video), id: video.id)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .overlay(alignment: .topLeading) {
                if isBound {
                    HStack(spacing: 4) {
                        MonologueIcon(icon: .checkmark, size: 9, color: .white)
                        Text(String(localized: "immersive_bg_in_use"))
                            .font(.rounded(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.monologueAccent))
                    .padding(7)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    HapticManager.shared.light()
                    bgManager.delete(video)
                } label: {
                    MonologueIcon(icon: .trash, size: 11, color: .white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isBound ? Color.monologueAccent : Color.white.opacity(0.08), lineWidth: isBound ? 1.6 : 1)
            )
            .shadow(color: isBound ? Color.monologueAccent.opacity(0.35) : .clear, radius: 12)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }

    // MARK: - Actions

    private func applyBinding(_ videoId: String?) {
        switch target {
        case .song:
            guard let songId else { return }
            bgManager.bindSong(songId, to: videoId)
        case .context:
            guard let context else { return }
            bgManager.bindContext(context, to: videoId)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        importError = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if let video = bgManager.importVideo(from: url) {
                applyBinding(video.id)
            } else {
                importError = String(localized: "immersive_bg_import_failed")
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    /// 照片图库导入：视频先落到临时目录，再入库并自动绑定当前目标
    private func importFromPhotos(_ item: PhotosPickerItem) async {
        importError = nil
        isImporting = true
        defer {
            isImporting = false
            photoPickerItem = nil
        }

        do {
            guard let picked = try await item.loadTransferable(type: PickedImmersiveVideo.self) else {
                importError = String(localized: "immersive_bg_import_failed")
                return
            }
            defer { try? FileManager.default.removeItem(at: picked.url) }

            let name = Date().formatted(.dateTime.month().day().hour().minute())
            if let video = bgManager.importVideo(
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

// MARK: - 照片图库视频落盘载体

private struct PickedImmersiveVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("immersive-import-\(UUID().uuidString)")
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

// MARK: - 时长角标

private struct VideoDurationBadge: View {
    let url: URL
    let id: String
    @State private var text: String?

    var body: some View {
        ZStack {
            if let text {
                Text(text)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
            }
        }
        .task(id: id) {
            text = await VideoDurationCache.shared.durationText(for: url, id: id)
        }
    }
}

@MainActor
private final class VideoDurationCache {
    static let shared = VideoDurationCache()
    private var cache: [String: String] = [:]

    func durationText(for url: URL, id: String) async -> String? {
        if let cached = cache[id] { return cached }
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let total = Int(duration.seconds.rounded())
        guard total > 0 else { return nil }
        let text: String
        if total >= 3600 {
            text = String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        } else {
            text = String(format: "%d:%02d", total / 60, total % 60)
        }
        cache[id] = text
        return text
    }
}

// MARK: - 视频缩略图

struct VideoThumbnailView: View {
    let url: URL
    let id: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .overlay(MonologueIcon(icon: .mv, size: 20, color: .white.opacity(0.3)))
            }
        }
        .task(id: id) {
            image = await VideoThumbnailCache.shared.thumbnail(for: url, id: id)
        }
    }
}

@MainActor
final class VideoThumbnailCache {
    static let shared = VideoThumbnailCache()
    private var cache: [String: UIImage] = [:]

    func thumbnail(for url: URL, id: String) async -> UIImage? {
        if let cached = cache[id] { return cached }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        do {
            let cgImage = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
            let image = UIImage(cgImage: cgImage)
            cache[id] = image
            return image
        } catch {
            return nil
        }
    }
}
