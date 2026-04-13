import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UniformTypeIdentifiers

@MainActor
final class LocalMusicLibraryManager: ObservableObject {
    static let shared = LocalMusicLibraryManager()

    struct ImportResult {
        var importedCount = 0
        var skippedCount = 0
        var failedItems: [String] = []
        var notices: [String] = []

        var summaryText: String {
            var parts = [
                String(
                    format: NSLocalizedString("local_import_result_imported", comment: ""),
                    locale: Locale.current,
                    importedCount
                )
            ]
            if skippedCount > 0 {
                parts.append(
                    String(
                        format: NSLocalizedString("local_import_result_skipped", comment: ""),
                        locale: Locale.current,
                        skippedCount
                    )
                )
            }
            if !failedItems.isEmpty {
                parts.append(
                    String(
                        format: NSLocalizedString("local_import_result_failed", comment: ""),
                        locale: Locale.current,
                        failedItems.count
                    )
                )
            }
            let summary = parts.joined(separator: "，")
            guard !notices.isEmpty else { return summary }
            if summary.isEmpty {
                return notices.joined(separator: "\n")
            }
            return ([summary] + notices).joined(separator: "\n")
        }
    }

    @Published private(set) var songs: [Song] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var lastImportResult: ImportResult?

    nonisolated static var rootDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent("LocalMusic", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    nonisolated static var musicDirectory: URL {
        let dir = rootDirectory.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    nonisolated private static var manifestURL: URL {
        rootDirectory.appendingPathComponent("library.json")
    }

    nonisolated static let importableContentTypes: [UTType] = [.audio, .folder]

    private static let supportedExtensions: Set<String> = [
        "aac", "aif", "aiff", "alac", "flac", "m4a", "m4b", "mp3", "ogg", "opus", "wav"
    ]

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        loadManifest()
    }

    var songCount: Int {
        songs.count
    }

    func importItems(from urls: [URL]) async -> ImportResult {
        isProcessing = true
        defer { isProcessing = false }

        var result = ImportResult()
        var nextSongs = songs
        let existingPaths = Set(nextSongs.compactMap(\.localRelativePath))

        for rootURL in urls {
            let accessGranted = rootURL.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    rootURL.stopAccessingSecurityScopedResource()
                }
            }

            let candidates = Self.collectImportableFiles(from: rootURL)
            if candidates.isEmpty {
                result.skippedCount += 1
                continue
            }

            for candidate in candidates {
                do {
                    let destinationURL = try Self.copyToLibrary(candidate)
                    let relativePath = destinationURL.lastPathComponent

                    if existingPaths.contains(relativePath) || nextSongs.contains(where: { $0.localRelativePath == relativePath }) {
                        result.skippedCount += 1
                        continue
                    }

                    let song = try await Self.makeLocalSong(from: destinationURL, relativePath: relativePath)
                    nextSongs.append(song)
                    result.importedCount += 1
                } catch {
                    result.failedItems.append(candidate.lastPathComponent)
                    AppLogger.error("本地音乐导入失败: \(candidate.lastPathComponent), error=\(error.localizedDescription)")
                }
            }
        }

        applyLibrarySongs(nextSongs)
        lastImportResult = result
        return result
    }

    func scanLibrary() async -> ImportResult {
        isProcessing = true
        defer { isProcessing = false }

        var result = ImportResult()
        let sharedImportResult = await importSharedDocumentAudio()
        result.skippedCount += sharedImportResult.skippedCount
        result.failedItems.append(contentsOf: sharedImportResult.failedItems)
        result.notices.append(contentsOf: sharedImportResult.notices)

        let mediaImportResult = await importSystemMediaLibraryAudio()
        result.skippedCount += mediaImportResult.skippedCount
        result.failedItems.append(contentsOf: mediaImportResult.failedItems)
        result.notices.append(contentsOf: mediaImportResult.notices)

        let files = Self.collectImportableFiles(from: Self.musicDirectory)
        var rebuilt: [Song] = []

        for file in files {
            do {
                let song = try await Self.makeLocalSong(from: file, relativePath: file.lastPathComponent)
                rebuilt.append(song)
            } catch {
                result.failedItems.append(file.lastPathComponent)
                AppLogger.error("扫描本地曲库失败: \(file.lastPathComponent), error=\(error.localizedDescription)")
            }
        }

        applyLibrarySongs(rebuilt)
        result.importedCount = rebuilt.count
        lastImportResult = result
        return result
    }

    func deleteSong(_ song: Song) {
        guard song.musicSource == .local,
              let relativePath = song.localRelativePath else { return }

        let fileURL = Self.musicDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        applyLibrarySongs(songs.filter { $0.id != song.id })
    }

    func reload() {
        loadManifest()
    }

    private func applyLibrarySongs(_ inputSongs: [Song]) {
        let deduplicated = Dictionary(grouping: inputSongs, by: \.id)
            .compactMap { $0.value.first }
            .sorted { lhs, rhs in
                let lhsDate = lhs.localImportedAt ?? .distantPast
                let rhsDate = rhs.localImportedAt ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        songs = deduplicated
        persist()
        pruneMissingLocalSongsFromPlaylists(validSongIDs: Set(deduplicated.map(\.id)))
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: Self.manifestURL),
              let storedSongs = try? decoder.decode([Song].self, from: data) else {
            songs = []
            return
        }

        songs = storedSongs.sorted { lhs, rhs in
            let lhsDate = lhs.localImportedAt ?? .distantPast
            let rhsDate = rhs.localImportedAt ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(songs)
            try data.write(to: Self.manifestURL, options: [.atomic])
        } catch {
            AppLogger.error("保存本地曲库失败: \(error.localizedDescription)")
        }
    }

    private func pruneMissingLocalSongsFromPlaylists(validSongIDs: Set<Int>) {
        let manager = LocalPlaylistManager.shared

        for playlist in manager.playlists {
            let missingLocalSongs = playlist.songs.filter {
                $0.musicSource == .local && !validSongIDs.contains($0.id)
            }

            for song in missingLocalSongs {
                manager.removeSong(id: song.id, from: playlist)
            }
        }
    }

    private static func collectImportableFiles(from rootURL: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            return []
        }

        if !isDirectory.boolValue {
            return isSupportedAudioFile(rootURL) ? [rootURL] : []
        }

        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var urls: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            if isSupportedAudioFile(item) {
                urls.append(item)
            }
        }

        return urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func collectSharedDocumentFiles() -> [URL] {
        let excludedDirectories = [rootDirectory, DownloadedSong.downloadsDirectory]

        return collectImportableFiles(from: documentsDirectory).filter { url in
            !excludedDirectories.contains { excluded in
                isDescendant(url, of: excluded)
            }
        }
    }

    private static func isDescendant(_ url: URL, of directory: URL) -> Bool {
        let normalizedDirectory = directory.standardizedFileURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedURL = url.standardizedFileURL.path
        return normalizedURL == directory.standardizedFileURL.path
            || normalizedURL.hasPrefix("/\(normalizedDirectory)/")
            || normalizedURL.hasPrefix(directory.standardizedFileURL.path + "/")
    }

    private static func isSupportedAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return !ext.isEmpty && supportedExtensions.contains(ext)
    }

    private static func copyToLibrary(_ sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let ext = sourceURL.pathExtension
        let baseName = sanitizedFileNameComponent(sourceURL.deletingPathExtension().lastPathComponent)

        var destination = musicDirectory.appendingPathComponent(baseName).appendingPathExtension(ext)
        var index = 2

        while fileManager.fileExists(atPath: destination.path) {
            destination = musicDirectory
                .appendingPathComponent("\(baseName) (\(index))")
                .appendingPathExtension(ext)
            index += 1
        }

        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    private func importSharedDocumentAudio() async -> ImportResult {
        var result = ImportResult()
        let files = Self.collectSharedDocumentFiles()

        for file in files {
            do {
                let (_, isNewFile) = try Self.ensureScannedFileInLibrary(
                    from: file,
                    stableKey: "docs:\(file.standardizedFileURL.path)"
                )
                if !isNewFile {
                    result.skippedCount += 1
                }
            } catch {
                result.failedItems.append(file.lastPathComponent)
                AppLogger.error("扫描 App 文稿音频失败: \(file.lastPathComponent), error=\(error.localizedDescription)")
            }
        }

        return result
    }

    private func importSystemMediaLibraryAudio() async -> ImportResult {
        var result = ImportResult()

        let status = await requestMediaLibraryAuthorizationIfNeeded()
        guard status == .authorized else {
            result.notices.append(NSLocalizedString("local_scan_notice_media_denied", comment: ""))
            return result
        }

        let items = MPMediaQuery.songs().items ?? []
        for item in items {
            let isCloudItem = (item.value(forProperty: MPMediaItemPropertyIsCloudItem) as? Bool) ?? false
            guard !isCloudItem, let assetURL = item.assetURL else {
                result.skippedCount += 1
                continue
            }

            do {
                let (_, isNewFile) = try await Self.ensureMediaItemInLibrary(item, assetURL: assetURL)
                if !isNewFile {
                    result.skippedCount += 1
                }
            } catch {
                result.failedItems.append(item.title ?? assetURL.lastPathComponent)
                AppLogger.error("导入系统媒体库失败: \(item.title ?? assetURL.lastPathComponent), error=\(error.localizedDescription)")
            }
        }

        return result
    }

    private func requestMediaLibraryAuthorizationIfNeeded() async -> MPMediaLibraryAuthorizationStatus {
        let current = MPMediaLibrary.authorizationStatus()
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func ensureScannedFileInLibrary(from sourceURL: URL, stableKey: String) throws -> (url: URL, isNewFile: Bool) {
        let baseName = sanitizedFileNameComponent(sourceURL.deletingPathExtension().lastPathComponent)
        let ext = normalizedAudioExtension(sourceURL.pathExtension)
        let destination = managedLibraryDestinationURL(baseName: baseName, stableKey: stableKey, fileExtension: ext)

        guard !FileManager.default.fileExists(atPath: destination.path) else {
            return (destination, false)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return (destination, true)
    }

    private static func ensureMediaItemInLibrary(_ item: MPMediaItem, assetURL: URL) async throws -> (url: URL, isNewFile: Bool) {
        let title = sanitizedFileNameComponent(item.title ?? assetURL.deletingPathExtension().lastPathComponent)
        let ext = normalizedAudioExtension(assetURL.pathExtension.isEmpty ? "m4a" : assetURL.pathExtension)
        let stableKey = "media:\(item.persistentID)"
        let destination = managedLibraryDestinationURL(baseName: title, stableKey: stableKey, fileExtension: ext)

        guard !FileManager.default.fileExists(atPath: destination.path) else {
            return (destination, false)
        }

        if assetURL.isFileURL {
            try FileManager.default.copyItem(at: assetURL, to: destination)
            return (destination, true)
        }

        let asset = AVURLAsset(url: assetURL)
        let exportedURL = try await exportMediaAsset(asset, fallbackURL: destination)
        return (exportedURL, true)
    }

    private static func managedLibraryDestinationURL(baseName: String, stableKey: String, fileExtension: String) -> URL {
        let token = stableToken(for: stableKey)
        let safeBaseName = sanitizedFileNameComponent(baseName)
        let decoratedBase = "\(safeBaseName)-\(token.prefix(8))"
        return musicDirectory
            .appendingPathComponent(decoratedBase)
            .appendingPathExtension(fileExtension)
    }

    private static func normalizedAudioExtension(_ fileExtension: String) -> String {
        let lowercased = fileExtension.lowercased()
        return supportedExtensions.contains(lowercased) ? lowercased : "m4a"
    }

    private static func stableToken(for key: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16, uppercase: false)
    }

    private static func exportMediaAsset(_ asset: AVAsset, fallbackURL: URL) async throws -> URL {
        let passthroughExporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)

        let exporter: AVAssetExportSession
        let outputType: AVFileType

        if let passthroughExporter,
           let passthroughType = preferredPassthroughFileType(from: passthroughExporter.supportedFileTypes) {
            exporter = passthroughExporter
            outputType = passthroughType
        } else {
            guard let fallbackExporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw NSError(domain: "LocalMusicLibrary", code: -10, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "无法导出系统媒体库音频")
                ])
            }
            exporter = fallbackExporter
            outputType = fallbackExporter.supportedFileTypes.contains(.m4a)
                ? .m4a
                : (fallbackExporter.supportedFileTypes.first ?? .m4a)
        }

        let finalURL = fallbackURL
            .deletingPathExtension()
            .appendingPathExtension(fileExtension(for: outputType))

        if FileManager.default.fileExists(atPath: finalURL.path) {
            try? FileManager.default.removeItem(at: finalURL)
        }

        exporter.outputURL = finalURL
        exporter.outputFileType = outputType
        exporter.shouldOptimizeForNetworkUse = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    continuation.resume(throwing: exporter.error ?? NSError(domain: "LocalMusicLibrary", code: -11))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "LocalMusicLibrary", code: -12, userInfo: [
                        NSLocalizedDescriptionKey: String(localized: "系统媒体库导出已取消")
                    ]))
                default:
                    continuation.resume(throwing: NSError(domain: "LocalMusicLibrary", code: -13, userInfo: [
                        NSLocalizedDescriptionKey: String(localized: "系统媒体库导出失败")
                    ]))
                }
            }
        }

        return finalURL
    }

    private static func preferredPassthroughFileType(from fileTypes: [AVFileType]) -> AVFileType? {
        let preferredTypes: [AVFileType] = [.m4a, .mp3, .wav, .aiff, .caf]
        for type in preferredTypes where fileTypes.contains(type) {
            return type
        }
        return nil
    }

    private static func fileExtension(for fileType: AVFileType) -> String {
        switch fileType {
        case .m4a: return "m4a"
        case .mp3: return "mp3"
        case .wav: return "wav"
        case .aiff: return "aiff"
        case .caf: return "caf"
        case .mov: return "mov"
        case .mp4: return "mp4"
        default: return "m4a"
        }
    }

    private static func sanitizedFileNameComponent(_ text: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
            .union(.illegalCharacters)

        let cleaned = text
            .components(separatedBy: invalidCharacters)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ."))

        return cleaned.isEmpty ? "Local Track" : cleaned
    }

    private static func makeLocalSong(from fileURL: URL, relativePath: String) async throws -> Song {
        let asset = AVURLAsset(url: fileURL)
        let duration = try? await asset.load(.duration)
        let metadata = try? await asset.load(.commonMetadata)

        let title = await metadataValue(for: metadata, identifier: .commonIdentifierTitle)
            ?? fileURL.deletingPathExtension().lastPathComponent
        let artistName = await metadataValue(for: metadata, identifier: .commonIdentifierArtist) ?? "Unknown Artist"
        let albumName = await metadataValue(for: metadata, identifier: .commonIdentifierAlbumName) ?? "Local Library"

        let durationMs: Int?
        if let duration {
            let seconds = CMTimeGetSeconds(duration)
            durationMs = seconds.isFinite ? Int(seconds * 1000) : nil
        } else {
            durationMs = nil
        }

        let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let importedAt = resourceValues?.creationDate ?? resourceValues?.contentModificationDate ?? Date()
        let songID = stableSongID(for: relativePath)
        let artistID = stableSongID(for: "artist:\(artistName)")
        let albumID = stableSongID(for: "album:\(albumName)")

        return Song(
            id: songID,
            name: title,
            ar: [Artist(id: artistID, name: artistName)],
            al: Album(id: albumID, name: albumName, picUrl: nil),
            dt: durationMs,
            fee: nil,
            mv: nil,
            h: nil,
            m: nil,
            l: nil,
            sq: nil,
            hr: nil,
            alia: nil,
            privilege: nil,
            source: .local,
            qqMid: nil,
            qqAlbumMid: nil,
            qqArtistMid: nil,
            qqMaxQuality: nil,
            localRelativePath: relativePath,
            localImportedAt: importedAt
        )
    }

    private static func metadataValue(for metadata: [AVMetadataItem]?, identifier: AVMetadataIdentifier) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: metadata ?? [], filteredByIdentifier: identifier).first else {
            return nil
        }

        let value = try? await item.load(.stringValue)
        return value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stableSongID(for key: String) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }

        let positive = Int64(bitPattern: hash & 0x7FFF_FFFF_FFFF_FFFF)
        let negative = positive == 0 ? Int64(-1) : -positive
        return Int(truncatingIfNeeded: negative)
    }
}
