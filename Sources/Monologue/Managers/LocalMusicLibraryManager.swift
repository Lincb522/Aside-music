import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UniformTypeIdentifiers

private struct SendableAVAssetExportSession: @unchecked Sendable {
    let session: AVAssetExportSession
}

@MainActor
final class LocalMusicLibraryManager: ObservableObject {
    static let shared = LocalMusicLibraryManager()

    struct ImportResult {
        var importedCount = 0
        var skippedCount = 0
        var failedItems: [String] = []
        var notices: [String] = []
        var importedSongs: [Song] = []
        var matchedMetadataCount = 0
        var prefetchedLyricsCount = 0

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
            if matchedMetadataCount > 0 {
                parts.append(
                    String(
                        format: NSLocalizedString("local_import_result_metadata_matched", comment: ""),
                        locale: Locale.current,
                        matchedMetadataCount
                    )
                )
            }
            if prefetchedLyricsCount > 0 {
                parts.append(
                    String(
                        format: NSLocalizedString("local_import_result_lyrics_prefetched", comment: ""),
                        locale: Locale.current,
                        prefetchedLyricsCount
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

    private struct LocalSongImportPayload {
        let song: Song
        let matchedMetadata: Bool
        let prefetchedLyrics: Bool
    }

    private struct OnlineMetadataMatch {
        let song: Song
        let score: Double
    }

    private struct OnlineMetadataSelection {
        let match: OnlineMetadataMatch
        let source: MusicSource
    }

    private struct MetadataSearchCandidate: Hashable {
        let title: String
        let artist: String

        var query: String {
            [effectiveArtistName(artist), title]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }

    private typealias OnlineMetadataMatches = (netease: OnlineMetadataMatch?, qq: OnlineMetadataMatch?, qishui: OnlineMetadataMatch?)

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

    nonisolated static var artworkDirectory: URL {
        let dir = rootDirectory.appendingPathComponent("Artwork", isDirectory: true)
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

    private static let onlineMetadataMatchThreshold = 0.78
    private static let unknownArtistMetadataMatchThreshold = 0.88
    private static let minimumTitleMatchScore = 0.72
    private static let minimumKnownArtistMatchScore = 0.42

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

                    let payload = try await Self.makeLocalSongImportPayload(from: destinationURL, relativePath: relativePath)
                    let song = payload.song
                    nextSongs.append(song)
                    result.importedSongs.append(song)
                    result.importedCount += 1
                    if payload.matchedMetadata {
                        result.matchedMetadataCount += 1
                    }
                    if payload.prefetchedLyrics {
                        result.prefetchedLyricsCount += 1
                    }
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
                let payload = try await Self.makeLocalSongImportPayload(from: file, relativePath: file.lastPathComponent)
                rebuilt.append(payload.song)
                if payload.matchedMetadata {
                    result.matchedMetadataCount += 1
                }
                if payload.prefetchedLyrics {
                    result.prefetchedLyricsCount += 1
                }
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
        deleteSongs([song])
    }

    func deleteSongs(_ songsToDelete: [Song]) {
        let localSongs = songsToDelete.filter { $0.musicSource == .local }
        guard !localSongs.isEmpty else { return }

        var removedIds = Set<Int>()

        for song in localSongs {
            guard let relativePath = song.localRelativePath else { continue }

            let fileURL = Self.musicDirectory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }

            let artworkURL = Self.artworkDirectory.appendingPathComponent("\(song.id).artwork")
            if FileManager.default.fileExists(atPath: artworkURL.path) {
                try? FileManager.default.removeItem(at: artworkURL)
            }

            OptimizedCacheManager.shared.removeLyrics(songId: song.id)
            removedIds.insert(song.id)
        }

        guard !removedIds.isEmpty else { return }
        applyLibrarySongs(songs.filter { !removedIds.contains($0.id) })
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
        LocalPlaylistManager.shared.syncLocalMusicPlaylist(with: deduplicated)
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
            let missingLocalSongIds = Set(manager.songs(for: playlist).filter {
                $0.musicSource == .local && !validSongIDs.contains($0.id)
            }.map(\.id))

            manager.removeSongs(ids: missingLocalSongIds, from: playlist)
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

        let sendableExporter = SendableAVAssetExportSession(session: exporter)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sendableExporter.session.exportAsynchronously {
                let exporter = sendableExporter.session
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

    private static func makeLocalSongImportPayload(from fileURL: URL, relativePath: String) async throws -> LocalSongImportPayload {
        let asset = AVURLAsset(url: fileURL)
        let duration = try? await asset.load(.duration)
        let commonMetadata = try? await asset.load(.commonMetadata)
        let metadata = (commonMetadata ?? []) + ((try? await asset.load(.metadata)) ?? [])

        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let inferred = inferredMetadata(from: fileName)
        let metadataTitle = await metadataValue(for: metadata, identifier: .commonIdentifierTitle)
        let metadataArtist = await metadataValue(for: metadata, identifier: .commonIdentifierArtist)
        let title = metadataTitle ?? inferred.title
        let artistName = metadataArtist
            ?? inferred.artist
            ?? "Unknown Artist"
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
        let embeddedArtworkURL = await embeddedArtworkURL(from: metadata, songID: songID)
        let embeddedLyrics = await embeddedLyrics(from: metadata)

        let localSong = Song(
            id: songID,
            name: title,
            ar: [Artist(id: artistID, name: artistName)],
            al: Album(id: albumID, name: albumName, picUrl: embeddedArtworkURL?.absoluteString),
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

        let searchCandidates = metadataSearchCandidates(
            fileName: fileName,
            metadataTitle: metadataTitle,
            metadataArtist: metadataArtist,
            fallbackTitle: title,
            fallbackArtist: artistName
        )

        return await enrichLocalSong(
            localSong,
            embeddedArtworkURL: embeddedArtworkURL,
            embeddedLyrics: embeddedLyrics,
            searchCandidates: searchCandidates
        )
    }

    private static func inferredMetadata(from fileName: String) -> (title: String, artist: String?) {
        let cleaned = fileName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"^\d+\s*[-.、_]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for separator in [" - ", " – ", " — "] {
            let parts = cleaned.components(separatedBy: separator)
            if parts.count >= 2 {
                let artist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let title = parts.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                if !artist.isEmpty, !title.isEmpty {
                    return (title, artist)
                }
            }
        }

        return (cleaned.isEmpty ? "Local Track" : cleaned, nil)
    }

    private static func embeddedArtworkURL(from metadata: [AVMetadataItem]?, songID: Int) async -> URL? {
        guard let item = AVMetadataItem.metadataItems(from: metadata ?? [], filteredByIdentifier: .commonIdentifierArtwork).first,
              let data = try? await item.load(.dataValue),
              !data.isEmpty else {
            return nil
        }

        let destination = artworkDirectory.appendingPathComponent("\(songID).artwork")
        do {
            try data.write(to: destination, options: [.atomic])
            return destination
        } catch {
            AppLogger.warning("本地音乐封面写入失败: \(error.localizedDescription)")
            return nil
        }
    }

    private static func embeddedLyrics(from metadata: [AVMetadataItem]?) async -> String? {
        for item in metadata ?? [] where isLyricsMetadataItem(item) {
            guard let value = try? await item.load(.stringValue) else { continue }
            let normalized = normalizedEmbeddedLyrics(value)
            if !normalized.isEmpty {
                return normalized
            }
        }
        return nil
    }

    private static func isLyricsMetadataItem(_ item: AVMetadataItem) -> Bool {
        let identifier = item.identifier?.rawValue.lowercased() ?? ""
        let commonKey = item.commonKey?.rawValue.lowercased() ?? ""
        let key = item.key.map { "\($0)".lowercased() } ?? ""
        return identifier.contains("lyric")
            || commonKey.contains("lyric")
            || key.contains("lyric")
            || key == "uslt"
            || key == "sylt"
    }

    private static func normalizedEmbeddedLyrics(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.range(of: #"\[\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
            return trimmed
        }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return trimmed }
        return lines.enumerated().map { index, line in
            let seconds = Double(index) * 5.0
            let minutes = Int(seconds) / 60
            let remainingSeconds = seconds - Double(minutes * 60)
            return String(format: "[%02d:%05.2f]%@", locale: Locale(identifier: "en_US_POSIX"), minutes, remainingSeconds, line)
        }.joined(separator: "\n")
    }

    private static func enrichLocalSong(
        _ song: Song,
        embeddedArtworkURL: URL?,
        embeddedLyrics: String?,
        searchCandidates: [MetadataSearchCandidate]
    ) async -> LocalSongImportPayload {
        let candidates = searchCandidates.isEmpty
            ? [MetadataSearchCandidate(title: song.name, artist: song.artistName)]
            : searchCandidates

        guard candidates.contains(where: { !$0.query.isEmpty }) else {
            return LocalSongImportPayload(song: song, matchedMetadata: false, prefetchedLyrics: cacheEmbeddedLyrics(embeddedLyrics, localSongId: song.id))
        }

        let matches = await bestOnlineMatches(for: candidates, durationMs: song.dt)
        let primarySelection = bestSelection(from: matches)
        let enrichedSong = applyOnlineMetadata(
            to: song,
            primarySelection: primarySelection,
            neteaseSong: matches.netease?.song,
            qqSong: matches.qq?.song,
            qishuiSong: matches.qishui?.song,
            embeddedArtworkURL: embeddedArtworkURL
        )

        var prefetchedLyrics = cacheEmbeddedLyrics(embeddedLyrics, localSongId: enrichedSong.id, overwrite: true)
        if !prefetchedLyrics {
            prefetchedLyrics = await prefetchLyrics(
                for: enrichedSong,
                primarySelection: primarySelection,
                neteaseSong: matches.netease?.song,
                qqSong: matches.qq?.song,
                qishuiSong: matches.qishui?.song
            )
        }
        if !prefetchedLyrics, primarySelection == nil, embeddedLyrics == nil {
            OptimizedCacheManager.shared.removeLyrics(songId: enrichedSong.id)
        }

        return LocalSongImportPayload(
            song: enrichedSong,
            matchedMetadata: primarySelection != nil,
            prefetchedLyrics: prefetchedLyrics
        )
    }

    private static func bestOnlineMatches(
        for candidates: [MetadataSearchCandidate],
        durationMs: Int?
    ) async -> OnlineMetadataMatches {
        var best: OnlineMetadataMatches = (nil, nil, nil)

        for candidate in candidates.prefix(4) where !candidate.query.isEmpty {
            async let neteaseMatch = fetchNeteaseMetadataMatch(
                query: candidate.query,
                title: candidate.title,
                artist: candidate.artist,
                durationMs: durationMs
            )
            async let qqMatch = fetchQQMetadataMatch(
                query: candidate.query,
                title: candidate.title,
                artist: candidate.artist,
                durationMs: durationMs
            )
            async let qishuiMatch = fetchQishuiMetadataMatch(
                query: candidate.query,
                title: candidate.title,
                artist: candidate.artist,
                durationMs: durationMs
            )
            let result = await (netease: neteaseMatch, qq: qqMatch, qishui: qishuiMatch)

            best.netease = strongerMatch(best.netease, result.netease)
            best.qq = strongerMatch(best.qq, result.qq)
            best.qishui = strongerMatch(best.qishui, result.qishui)

            if let selection = bestSelection(from: best), selection.match.score >= 0.96 {
                break
            }
        }

        return best
    }

    private static func bestSelection(from matches: OnlineMetadataMatches) -> OnlineMetadataSelection? {
        [
            matches.netease.map { OnlineMetadataSelection(match: $0, source: .netease) },
            matches.qq.map { OnlineMetadataSelection(match: $0, source: .qqmusic) },
            matches.qishui.map { OnlineMetadataSelection(match: $0, source: .qishui) }
        ]
        .compactMap { $0 }
        .max { $0.match.score < $1.match.score }
    }

    private static func strongerMatch(_ lhs: OnlineMetadataMatch?, _ rhs: OnlineMetadataMatch?) -> OnlineMetadataMatch? {
        guard let lhs else { return rhs }
        guard let rhs else { return lhs }
        return lhs.score >= rhs.score ? lhs : rhs
    }

    private static func fetchNeteaseMetadataMatch(query: String, title: String, artist: String, durationMs: Int?) async -> OnlineMetadataMatch? {
        do {
            let candidates = try await APIService.shared.searchSongs(keyword: query, offset: 0).async()
            return bestMetadataMatch(from: candidates, title: title, artist: artist, durationMs: durationMs)
        } catch {
            AppLogger.warning("本地音乐 NCM 元数据匹配失败: \(query), error=\(error.localizedDescription)")
            return nil
        }
    }

    private static func fetchQQMetadataMatch(query: String, title: String, artist: String, durationMs: Int?) async -> OnlineMetadataMatch? {
        do {
            let candidates = try await APIService.shared.searchQQSongs(keyword: query, page: 1, num: 10).async()
            return bestMetadataMatch(from: candidates, title: title, artist: artist, durationMs: durationMs)
        } catch {
            AppLogger.warning("本地音乐 QCM 元数据匹配失败: \(query), error=\(error.localizedDescription)")
            return nil
        }
    }

    private static func fetchQishuiMetadataMatch(query: String, title: String, artist: String, durationMs: Int?) async -> OnlineMetadataMatch? {
        do {
            let candidates = try await APIService.shared.searchQishuiSongs(keyword: query, page: 0).async()
            return bestMetadataMatch(from: Array(candidates.prefix(10)), title: title, artist: artist, durationMs: durationMs)
        } catch {
            AppLogger.warning("本地音乐 Qishui 元数据匹配失败: \(query), error=\(error.localizedDescription)")
            return nil
        }
    }

    private static func bestMetadataMatch(from songs: [Song], title: String, artist: String, durationMs: Int?) -> OnlineMetadataMatch? {
        let normalizedTitle = normalizeMatchText(title)
        let normalizedArtist = normalizeMatchText(effectiveArtistName(artist))
        let hasKnownArtist = !normalizedArtist.isEmpty

        var bestMatch: Song?
        var bestScore = 0.0

        for song in songs {
            let titleScore = similarityScore(normalizedTitle, normalizeMatchText(song.name))
            guard titleScore >= minimumTitleMatchScore else { continue }

            let artistScore = hasKnownArtist
                ? similarityScore(normalizedArtist, normalizeMatchText(song.artistName))
                : 1.0
            if hasKnownArtist, artistScore < minimumKnownArtistMatchScore {
                continue
            }

            let exactDurationScore = durationMatchScore(localDurationMs: durationMs, remoteDurationMs: song.dt)
            if let exactDurationScore, exactDurationScore < 0.35 {
                continue
            }
            if !hasKnownArtist, exactDurationScore == nil, titleScore < 0.96 {
                continue
            }

            let durationScore = exactDurationScore ?? (hasKnownArtist ? 0.72 : 0.0)
            let totalScore = hasKnownArtist
                ? titleScore * 0.58 + artistScore * 0.27 + durationScore * 0.15
                : titleScore * 0.70 + durationScore * 0.30

            if totalScore > bestScore {
                bestScore = totalScore
                bestMatch = song
            }
        }

        let threshold = hasKnownArtist ? onlineMetadataMatchThreshold : unknownArtistMetadataMatchThreshold
        guard let bestMatch, bestScore >= threshold else { return nil }
        return OnlineMetadataMatch(song: bestMatch, score: bestScore)
    }

    private static func applyOnlineMetadata(
        to baseSong: Song,
        primarySelection: OnlineMetadataSelection?,
        neteaseSong: Song?,
        qqSong: Song?,
        qishuiSong: Song?,
        embeddedArtworkURL: URL?
    ) -> Song {
        guard primarySelection != nil || embeddedArtworkURL != nil else { return baseSong }

        let primarySong = primarySelection?.match.song
        let isHighConfidence = (primarySelection?.match.score ?? 0) >= 0.90
        let coverURL = firstNonEmpty(
            isHighConfidence ? primarySong?.coverUrl?.absoluteString : embeddedArtworkURL?.absoluteString,
            isHighConfidence ? neteaseSong?.coverUrl?.absoluteString : nil,
            isHighConfidence ? qqSong?.coverUrl?.absoluteString : nil,
            isHighConfidence ? qishuiSong?.coverUrl?.absoluteString : nil,
            isHighConfidence ? embeddedArtworkURL?.absoluteString : primarySong?.coverUrl?.absoluteString,
            isHighConfidence ? nil : neteaseSong?.coverUrl?.absoluteString,
            isHighConfidence ? nil : qqSong?.coverUrl?.absoluteString,
            isHighConfidence ? nil : qishuiSong?.coverUrl?.absoluteString,
            baseSong.coverUrl?.absoluteString
        )
        let albumName = firstNonEmpty(primarySong?.album?.name, baseSong.album?.name) ?? "Local Library"
        let albumID = primarySong?.album?.id ?? baseSong.album?.id ?? stableSongID(for: "album:\(albumName)")
        let artists = nonEmptyArtists(primarySong?.ar) ?? nonEmptyArtists(baseSong.ar) ?? [Artist(id: stableSongID(for: "artist:\(baseSong.artistName)"), name: baseSong.artistName)]

        var mergedSong = Song(
            id: baseSong.id,
            name: firstNonEmpty(primarySong?.name, baseSong.name) ?? baseSong.name,
            ar: artists,
            al: Album(id: albumID, name: albumName, picUrl: coverURL),
            dt: baseSong.dt ?? primarySong?.dt,
            fee: nil,
            mv: nil,
            h: nil,
            m: nil,
            l: nil,
            sq: nil,
            hr: nil,
            alia: baseSong.alia
        )

        mergedSong.source = .local
        mergedSong.qqMid = qqSong?.qqMid ?? baseSong.qqMid
        mergedSong.qqAlbumMid = qqSong?.qqAlbumMid ?? baseSong.qqAlbumMid
        mergedSong.qqArtistMid = qqSong?.qqArtistMid ?? baseSong.qqArtistMid
        mergedSong.qqMaxQuality = qqSong?.qqMaxQuality ?? baseSong.qqMaxQuality
        mergedSong.qishuiTrackId = qishuiSong?.qishuiTrackId ?? baseSong.qishuiTrackId
        mergedSong.localRelativePath = baseSong.localRelativePath
        mergedSong.localImportedAt = baseSong.localImportedAt
        return mergedSong
    }

    private static func prefetchLyrics(
        for song: Song,
        primarySelection: OnlineMetadataSelection?,
        neteaseSong: Song?,
        qqSong: Song?,
        qishuiSong: Song?
    ) async -> Bool {
        guard let primarySelection else { return false }

        switch primarySelection.source {
        case .qishui:
            guard let qishuiTrackId = qishuiSong?.qishuiTrackId ?? primarySelection.match.song.qishuiTrackId else {
                return false
            }
            do {
                let content = try await APIService.shared.fetchQishuiLyric(trackId: qishuiTrackId).async()
                if cacheQishuiLyrics(content, localSongId: song.id) {
                    return true
                }
            } catch {
                AppLogger.warning("本地音乐 Qishui 歌词预取失败: \(song.name), error=\(error.localizedDescription)")
            }
            return false

        case .netease:
            let matchedSong = neteaseSong ?? primarySelection.match.song
            do {
                let response = try await APIService.shared.fetchLyric(id: matchedSong.id).async()
                if cacheNeteaseLyrics(response, localSongId: song.id) {
                    return true
                }
            } catch {
                AppLogger.warning("本地音乐 NCM 歌词预取失败: \(song.name), error=\(error.localizedDescription)")
            }
            return false

        case .qqmusic:
            guard let qqMid = firstNonEmpty(qqSong?.qqMid, primarySelection.match.song.qqMid) else {
                return false
            }
            do {
                let response = try await APIService.shared.fetchQQLyric(mid: qqMid).async()
                if cacheQQLyrics(response, localSongId: song.id) {
                    return true
                }
            } catch {
                AppLogger.warning("本地音乐 QCM 歌词预取失败: \(song.name), error=\(error.localizedDescription)")
            }
            return false

        case .local:
            return false
        }
    }

    private static func cacheNeteaseLyrics(_ response: LyricResponse, localSongId: Int) -> Bool {
        guard let lyric = firstNonEmpty(response.yrc?.lyric, response.lrc?.lyric) else { return false }
        OptimizedCacheManager.shared.cacheLyrics(
            songId: localSongId,
            lyrics: lyric,
            translated: firstNonEmpty(response.tlyric?.lyric)
        )
        return true
    }

    private static func cacheQQLyrics(_ response: QQLyricResponse, localSongId: Int) -> Bool {
        guard let lyric = firstNonEmpty(response.qrc, response.lyric) else { return false }
        OptimizedCacheManager.shared.cacheLyrics(
            songId: localSongId,
            lyrics: lyric,
            translated: firstNonEmpty(response.trans, response.roma)
        )
        return true
    }

    private static func cacheQishuiLyrics(_ content: String, localSongId: Int) -> Bool {
        let lyric = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lyric.isEmpty else { return false }
        OptimizedCacheManager.shared.cacheLyrics(songId: localSongId, lyrics: lyric)
        return true
    }

    private static func cacheEmbeddedLyrics(_ lyrics: String?, localSongId: Int, overwrite: Bool = false) -> Bool {
        guard (overwrite || OptimizedCacheManager.shared.getLyrics(songId: localSongId) == nil),
              let lyrics,
              !lyrics.isEmpty else {
            return false
        }
        OptimizedCacheManager.shared.cacheLyrics(songId: localSongId, lyrics: lyrics)
        return true
    }

    private static func metadataSearchCandidates(
        fileName: String,
        metadataTitle: String?,
        metadataArtist: String?,
        fallbackTitle: String,
        fallbackArtist: String
    ) -> [MetadataSearchCandidate] {
        var candidates: [MetadataSearchCandidate] = []
        var seen = Set<String>()

        func append(title: String?, artist: String?) {
            let cleanedTitle = cleanedSearchTitle(title ?? "")
            let cleanedArtist = cleanedSearchArtist(artist ?? "")
            guard !cleanedTitle.isEmpty else { return }

            let key = "\(normalizeMatchText(cleanedTitle))|\(normalizeMatchText(cleanedArtist))"
            guard seen.insert(key).inserted else { return }
            candidates.append(MetadataSearchCandidate(title: cleanedTitle, artist: cleanedArtist))
        }

        append(title: metadataTitle, artist: metadataArtist)

        let inferred = inferredMetadata(from: fileName)
        append(title: inferred.title, artist: inferred.artist)

        append(title: fallbackTitle, artist: fallbackArtist)

        if let metadataTitle, metadataArtist == nil || metadataArtist?.isEmpty == true {
            append(title: metadataTitle, artist: nil)
        }

        return candidates
    }

    private static func cleanedSearchTitle(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"(?i)\.(mp3|m4a|flac|wav|aac|aiff|ogg|opus)$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\d+\s*[-.、_]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"【[^】]*】"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\((?:cover|伴奏|instrumental|karaoke|320k|flac|mp3|hq|sq|hi-?res)[^)]*\)"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"（(?:cover|伴奏|instrumental|karaoke|320k|flac|mp3|hq|sq|hi-?res)[^）]*）"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanedSearchArtist(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return effectiveArtistName(cleaned)
    }

    private static func durationMatchScore(localDurationMs: Int?, remoteDurationMs: Int?) -> Double? {
        guard let localDurationMs,
              let remoteDurationMs,
              localDurationMs > 0,
              remoteDurationMs > 0 else {
            return nil
        }

        let diff = abs(Double(localDurationMs - remoteDurationMs)) / 1000.0
        switch diff {
        case 0...3:
            return 1.0
        case 3...8:
            return 0.88
        case 8...15:
            return 0.68
        case 15...30:
            return 0.42
        default:
            return 0.0
        }
    }

    nonisolated private static func effectiveArtistName(_ artist: String) -> String {
        let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.localizedCaseInsensitiveCompare("Unknown Artist") == .orderedSame {
            return ""
        }
        return trimmed
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private static func nonEmptyArtists(_ artists: [Artist]?) -> [Artist]? {
        guard let artists, !artists.isEmpty else { return nil }
        let cleaned = artists.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func normalizeMatchText(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "\u{4E00}"..."\u{9FFF}")).inverted)
            .joined()
    }

    private static func similarityScore(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty && !rhs.isEmpty else { return lhs == rhs ? 1.0 : 0.0 }
        if lhs.contains(rhs) || rhs.contains(lhs) {
            return max(Double(min(lhs.count, rhs.count)) / Double(max(lhs.count, rhs.count)), 0.8)
        }

        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let m = lhsChars.count
        let n = rhsChars.count

        if Double(min(m, n)) / Double(max(m, n)) < 0.3 {
            return 0.2
        }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = lhsChars[i - 1] == rhsChars[j - 1]
                    ? dp[i - 1][j - 1] + 1
                    : max(dp[i - 1][j], dp[i][j - 1])
            }
        }

        return Double(dp[m][n] * 2) / Double(m + n)
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
