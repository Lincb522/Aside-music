import Foundation
import AVFoundation
import FFmpegSwiftSDK
@preconcurrency import Combine
@preconcurrency import Speech

enum AILyricAlignmentPhase: Equatable {
    case idle
    case existingTiming
    case preparing
    case recognizing(progress: Double)
    case aligning
    case completed(confidence: Double)
    case failed(message: String)

    var isWorking: Bool {
        switch self {
        case .preparing, .recognizing, .aligning:
            return true
        case .idle, .existingTiming, .completed, .failed:
            return false
        }
    }
}

private struct AILyricAlignmentCachePayload: Codable {
    static let currentVersion = 1

    let version: Int
    let songKey: String
    let lyricSource: String
    let lyricFingerprint: String
    let confidence: Double
    let createdAt: Date
    let lines: [Line]

    struct Line: Codable {
        let text: String
        let originalTime: TimeInterval
        let alignedTime: TimeInterval
        let duration: TimeInterval
        let words: [Word]
    }

    struct Word: Codable {
        let text: String
        let startTime: TimeInterval
        let duration: TimeInterval
    }
}

private struct AILyricRecognizedUnit: Sendable {
    let key: String
    let startTime: TimeInterval
    let duration: TimeInterval
    let confidence: Double
}

private struct AILyricOfficialUnit {
    let originalIndex: Int
    let key: String
}

private struct AILyricLineAlignment {
    let line: LyricLine
    let coverage: Double
    let recognitionConfidence: Double
    let matchedCharacterCount: Int
}

private enum AILyricAlignmentError: LocalizedError, Equatable, Sendable {
    case noSong
    case noLyrics
    case existingTiming
    case audioUnavailable
    case unsupportedAudio
    case speechPermission
    case recognizerUnavailable
    case noRecognizedVocal
    case insufficientMatch
    case downloadFailed
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .noSong:
            return String(localized: "ai_lyric_align_error_no_song")
        case .noLyrics:
            return String(localized: "ai_lyric_align_error_no_lyrics")
        case .existingTiming:
            return String(localized: "ai_lyric_align_error_existing")
        case .audioUnavailable:
            return String(localized: "ai_lyric_align_error_audio")
        case .unsupportedAudio:
            return String(localized: "ai_lyric_align_error_format")
        case .speechPermission:
            return String(localized: "ai_lyric_align_error_permission")
        case .recognizerUnavailable:
            return String(localized: "ai_lyric_align_error_unavailable")
        case .noRecognizedVocal:
            return String(localized: "ai_lyric_align_error_no_vocal")
        case .insufficientMatch:
            return String(localized: "ai_lyric_align_error_match")
        case .downloadFailed:
            return String(localized: "ai_lyric_align_error_download")
        case .recognitionFailed:
            return String(localized: "ai_lyric_align_error_recognition")
        }
    }
}

/// 使用原始播放输入识别人声时间，再把时间锚点强制对齐到现有逐行歌词。
/// 识别过程不会改写歌词文本，也不会覆盖平台已经提供的可靠 YRC/QRC。
@MainActor
final class AILyricAlignmentAgent: ObservableObject {
    static let shared = AILyricAlignmentAgent()

    @Published private(set) var phase: AILyricAlignmentPhase = .idle

    private let player = PlayerManager.shared
    private let lyricViewModel = LyricViewModel.shared
    private var cancellables = Set<AnyCancellable>()
    private var alignmentTask: Task<Void, Never>?
    private var speechTask: SFSpeechRecognitionTask?
    private var speechContinuation: CheckedContinuation<[AILyricRecognizedUnit], Error>?
    private var latestRecognizedUnits: [AILyricRecognizedUnit] = []
    private var activeCacheKey: String?
    private var isApplyingAlignment = false
    private var temporaryAudioURLs: Set<URL> = []

    private init() {
        player.$currentSong
            .map { song in
                song.map(Self.songKey(for:))
            }
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.cancel(resetPhase: true)
                self.activeCacheKey = nil
                self.refreshCurrentLyricsState()
            }
            .store(in: &cancellables)

        lyricViewModel.$lyrics
            .dropFirst()
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.isApplyingAlignment else { return }
                self.refreshCurrentLyricsState()
            }
            .store(in: &cancellables)
    }

    var statusText: String? {
        switch phase {
        case .idle:
            return nil
        case .existingTiming:
            return String(localized: "ai_lyric_align_existing_short")
        case .preparing:
            return String(localized: "ai_lyric_align_preparing")
        case .recognizing(let progress):
            return "\(Int((progress * 100).rounded()))%"
        case .aligning:
            return String(localized: "ai_lyric_aligning")
        case .completed:
            return String(localized: "ai_lyric_aligned")
        case .failed:
            return String(localized: "action_retry")
        }
    }

    var canStartAlignment: Bool {
        guard player.currentSong != nil,
              !lyricViewModel.lyrics.isEmpty else {
            return false
        }
        switch phase {
        case .idle, .failed:
            return true
        case .existingTiming, .preparing, .recognizing, .aligning, .completed:
            return false
        }
    }

    func alignCurrentSong() {
        guard !phase.isWorking else { return }

        alignmentTask?.cancel()
        alignmentTask = Task { [weak self] in
            await self?.runAlignment()
        }
    }

    func cancel() {
        cancel(resetPhase: true)
    }

    private func cancel(resetPhase: Bool) {
        alignmentTask?.cancel()
        alignmentTask = nil
        finishSpeechRecognition(with: .failure(CancellationError()))
        cleanupTemporaryAudio()
        if resetPhase, phase.isWorking {
            phase = .idle
        }
    }

    private func runAlignment() async {
        guard let song = player.currentSong else {
            presentFailure(.noSong)
            return
        }

        let songKey = Self.songKey(for: song)
        let sourceLines = lyricViewModel.lyrics
        guard lyricViewModel.currentSongId == song.id, !sourceLines.isEmpty else {
            presentFailure(.noLyrics)
            return
        }

        let lyricSource = lyricViewModel.activeSource?.rawValue ?? "unknown"
        let fingerprint = Self.lyricFingerprint(for: sourceLines)
        let cacheKey = Self.cacheKey(
            songKey: songKey,
            lyricSource: lyricSource,
            fingerprint: fingerprint
        )

        if activeCacheKey != cacheKey, Self.hasReliableWordTiming(in: sourceLines) {
            presentFailure(.existingTiming)
            return
        }

        let baselineLines = sourceLines.map { line -> LyricLine in
            guard activeCacheKey == cacheKey else { return line }
            return LyricLine(
                time: line.time,
                text: line.text,
                translation: line.translation,
                duration: line.duration,
                words: []
            )
        }

        phase = .preparing
        AppLogger.info(
            "[AILyricAlignment] Preparing source=\(song.musicSource.rawValue) id=\(song.id) lines=\(baselineLines.count)",
            step: "ai-lyrics.prepare"
        )

        do {
            let authorization = await speechAuthorizationStatus()
            try Task.checkCancellation()
            guard authorization == .authorized else {
                throw AILyricAlignmentError.speechPermission
            }

            let audioURL = try await prepareAudioURL()
            try Task.checkCancellation()

            let duration = max(
                Double(song.dt ?? 0) / 1000,
                player.duration,
                1
            )
            let localeIdentifier = Self.preferredLocaleIdentifier(for: baselineLines)
            let recognizedUnits = try await recognize(
                audioURL: audioURL,
                localeIdentifier: localeIdentifier,
                expectedDuration: duration,
                contextualLines: baselineLines
            )
            try Task.checkCancellation()

            phase = .aligning
            AppLogger.info(
                "[AILyricAlignment] Aligning recognizedUnits=\(recognizedUnits.count) locale=\(localeIdentifier)",
                step: "ai-lyrics.align"
            )

            let result = try Self.align(lines: baselineLines, to: recognizedUnits)
            try Task.checkCancellation()

            guard let currentSong = player.currentSong,
                  Self.songKey(for: currentSong) == songKey,
                  lyricViewModel.currentSongId == song.id,
                  Self.lyricFingerprint(for: lyricViewModel.lyrics) == fingerprint else {
                throw CancellationError()
            }

            let payload = Self.makeCachePayload(
                songKey: songKey,
                lyricSource: lyricSource,
                lyricFingerprint: fingerprint,
                confidence: result.confidence,
                originalLines: baselineLines,
                alignedLines: result.lines
            )
            OptimizedCacheManager.shared.setObject(
                payload,
                forKey: cacheKey,
                ttl: 180 * 24 * 60 * 60
            )

            apply(result.lines, cacheKey: cacheKey)
            phase = .completed(confidence: result.confidence)
            HapticManager.shared.success()
            AppLogger.info(
                "[AILyricAlignment] Completed confidence=\(String(format: "%.3f", result.confidence)) cache=\(cacheKey)",
                step: "ai-lyrics.complete"
            )
        } catch is CancellationError {
            if phase.isWorking { phase = .idle }
            AppLogger.info("[AILyricAlignment] Cancelled", step: "ai-lyrics.cancel")
        } catch let error as AILyricAlignmentError {
            presentFailure(error)
        } catch {
            AppLogger.error(
                "[AILyricAlignment] Unexpected failure: \(error.localizedDescription)",
                step: "ai-lyrics.error"
            )
            presentFailure(.recognitionFailed)
        }

        cleanupTemporaryAudio()
        alignmentTask = nil
    }

    private func refreshCurrentLyricsState() {
        guard !phase.isWorking,
              let song = player.currentSong,
              lyricViewModel.currentSongId == song.id,
              !lyricViewModel.lyrics.isEmpty else {
            if !phase.isWorking { phase = .idle }
            return
        }

        let lines = lyricViewModel.lyrics
        let lyricSource = lyricViewModel.activeSource?.rawValue ?? "unknown"
        let fingerprint = Self.lyricFingerprint(for: lines)
        let cacheKey = Self.cacheKey(
            songKey: Self.songKey(for: song),
            lyricSource: lyricSource,
            fingerprint: fingerprint
        )

        if activeCacheKey == cacheKey, Self.hasReliableWordTiming(in: lines) {
            phase = .completed(confidence: Self.averageWordConfidenceFallback)
            return
        }
        if activeCacheKey == cacheKey {
            activeCacheKey = nil
        }

        if let payload = OptimizedCacheManager.shared.getObject(
            forKey: cacheKey,
            type: AILyricAlignmentCachePayload.self
        ), let restored = Self.restore(payload: payload, onto: lines) {
            activeCacheKey = cacheKey
            apply(restored, cacheKey: cacheKey)
            phase = .completed(confidence: payload.confidence)
            return
        }

        phase = Self.hasReliableWordTiming(in: lines) ? .existingTiming : .idle
    }

    private func apply(_ lines: [LyricLine], cacheKey: String) {
        isApplyingAlignment = true
        activeCacheKey = cacheKey
        lyricViewModel.lyrics = lines
        lyricViewModel.hasLyrics = !lines.isEmpty
        isApplyingAlignment = false
    }

    private func presentFailure(_ error: AILyricAlignmentError) {
        let message = error.localizedDescription
        phase = error == .existingTiming ? .existingTiming : .failed(message: message)
        AppLogger.warning(
            "[AILyricAlignment] Failed: \(message)",
            step: "ai-lyrics.failure"
        )

        if error != .existingTiming {
            AlertManager.shared.show(
                title: String(localized: "ai_lyric_align"),
                message: message,
                primaryButtonTitle: String(localized: "common_ok"),
                primaryAction: {}
            )
        }
    }

    private func speechAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func prepareAudioURL() async throws -> URL {
        if let localURL = player.currentSong?.localFileURL {
            return localURL
        }

        guard let rawInput = player.currentPlayingURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawInput.isEmpty else {
            throw AILyricAlignmentError.audioUnavailable
        }

        if rawInput.hasPrefix("file://"), let url = URL(string: rawInput) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AILyricAlignmentError.audioUnavailable
            }
            return try await prepareSpeechReadableAudioIfNeeded(url)
        }

        if rawInput.hasPrefix("/") {
            guard FileManager.default.fileExists(atPath: rawInput) else {
                throw AILyricAlignmentError.audioUnavailable
            }
            return try await prepareSpeechReadableAudioIfNeeded(URL(fileURLWithPath: rawInput))
        }

        guard let remoteURL = URL(string: rawInput),
              let scheme = remoteURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw AILyricAlignmentError.unsupportedAudio
        }
        guard remoteURL.pathExtension.lowercased() != "m3u8" else {
            throw AILyricAlignmentError.unsupportedAudio
        }

        AppLogger.info("[AILyricAlignment] Downloading analysis input", step: "ai-lyrics.download")
        let downloadedURL: URL
        let response: URLResponse
        do {
            (downloadedURL, response) = try await URLSession.shared.download(from: remoteURL)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            AppLogger.warning(
                "[AILyricAlignment] Audio download failed: \(error.localizedDescription)",
                step: "ai-lyrics.download"
            )
            throw AILyricAlignmentError.downloadFailed
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AILyricAlignmentError.downloadFailed
        }

        let fileExtension = remoteURL.pathExtension.isEmpty ? "m4a" : remoteURL.pathExtension
        let targetURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mono-ai-lyrics-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        do {
            try FileManager.default.moveItem(at: downloadedURL, to: targetURL)
        } catch {
            throw AILyricAlignmentError.downloadFailed
        }
        temporaryAudioURLs.insert(targetURL)
        return try await prepareSpeechReadableAudioIfNeeded(targetURL)
    }

    private func prepareSpeechReadableAudioIfNeeded(_ inputURL: URL) async throws -> URL {
        guard let decryptionKey = player.currentPlayingDecryptionKey,
              !decryptionKey.isEmpty else {
            return inputURL
        }

        let targetURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mono-ai-lyrics-decoded-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        let metadataDuration = Double(player.currentSong?.dt ?? 0) / 1000
        let maximumDuration = min(max(player.duration, metadataDuration, 60) + 1, 900)

        AppLogger.info(
            "[AILyricAlignment] Decoding encrypted analysis input",
            step: "ai-lyrics.decode"
        )

        do {
            let outputURL = try await Task.detached(priority: .userInitiated) {
                var (samples, sampleRate, channelCount) = try AudioAnalyzer.decodeAudioFile(
                    url: inputURL.path,
                    maxDuration: maximumDuration,
                    decryptionKey: decryptionKey,
                    outputChannelCount: 1
                )
                guard channelCount == 1,
                      sampleRate > 0,
                      !samples.isEmpty,
                      let format = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32,
                        sampleRate: Double(sampleRate),
                        channels: 1,
                        interleaved: false
                      ),
                      let buffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: 32_768
                      ),
                      let channelData = buffer.floatChannelData?[0] else {
                    throw AILyricAlignmentError.unsupportedAudio
                }

                let outputFile = try AVAudioFile(
                    forWriting: targetURL,
                    settings: format.settings,
                    commonFormat: .pcmFormatFloat32,
                    interleaved: false
                )
                var offset = 0
                while offset < samples.count {
                    try Task.checkCancellation()
                    let count = min(Int(buffer.frameCapacity), samples.count - offset)
                    samples.withUnsafeBufferPointer { pointer in
                        if let baseAddress = pointer.baseAddress {
                            channelData.update(from: baseAddress.advanced(by: offset), count: count)
                        }
                    }
                    buffer.frameLength = AVAudioFrameCount(count)
                    try outputFile.write(from: buffer)
                    offset += count
                }
                samples.removeAll(keepingCapacity: false)
                return targetURL
            }.value
            temporaryAudioURLs.insert(outputURL)
            return outputURL
        } catch is CancellationError {
            try? FileManager.default.removeItem(at: targetURL)
            throw CancellationError()
        } catch {
            try? FileManager.default.removeItem(at: targetURL)
            AppLogger.warning(
                "[AILyricAlignment] Encrypted input decode failed: \(error.localizedDescription)",
                step: "ai-lyrics.decode"
            )
            throw AILyricAlignmentError.unsupportedAudio
        }
    }

    private func recognize(
        audioURL: URL,
        localeIdentifier: String,
        expectedDuration: TimeInterval,
        contextualLines: [LyricLine]
    ) async throws -> [AILyricRecognizedUnit] {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            throw AILyricAlignmentError.recognizerUnavailable
        }

        if recognizer.supportsOnDeviceRecognition {
            do {
                return try await recognizeOnce(
                    audioURL: audioURL,
                    recognizer: recognizer,
                    expectedDuration: expectedDuration,
                    contextualLines: contextualLines,
                    requiresOnDeviceRecognition: true
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                AppLogger.warning(
                    "[AILyricAlignment] On-device recognition unavailable, retrying service path",
                    step: "ai-lyrics.recognize.fallback"
                )
            }
        }

        return try await recognizeOnce(
            audioURL: audioURL,
            recognizer: recognizer,
            expectedDuration: expectedDuration,
            contextualLines: contextualLines,
            requiresOnDeviceRecognition: false
        )
    }

    private func recognizeOnce(
        audioURL: URL,
        recognizer: SFSpeechRecognizer,
        expectedDuration: TimeInterval,
        contextualLines: [LyricLine],
        requiresOnDeviceRecognition: Bool
    ) async throws -> [AILyricRecognizedUnit] {
        phase = .recognizing(progress: 0.02)
        latestRecognizedUnits = []

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        request.contextualStrings = contextualLines
            .map(\.text)
            .filter { !$0.isEmpty }
            .prefix(100)
            .map { $0 }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                speechContinuation = continuation
                speechTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    let units = result.map(Self.recognizedUnits(from:)) ?? []
                    let isFinal = result?.isFinal ?? false
                    let failureDescription = error?.localizedDescription

                    Task { @MainActor [weak self] in
                        self?.handleSpeechResult(
                            units: units,
                            isFinal: isFinal,
                            failureDescription: failureDescription,
                            expectedDuration: expectedDuration
                        )
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finishSpeechRecognition(with: .failure(CancellationError()))
            }
        }
    }

    private func handleSpeechResult(
        units: [AILyricRecognizedUnit],
        isFinal: Bool,
        failureDescription: String?,
        expectedDuration: TimeInterval
    ) {
        guard speechContinuation != nil else { return }

        if !units.isEmpty {
            latestRecognizedUnits = units
            let lastEnd = units.last.map { $0.startTime + $0.duration } ?? 0
            phase = .recognizing(progress: min(max(lastEnd / expectedDuration, 0.03), 0.98))
        }

        if isFinal {
            let finalUnits = units.isEmpty ? latestRecognizedUnits : units
            guard !finalUnits.isEmpty else {
                finishSpeechRecognition(with: .failure(AILyricAlignmentError.noRecognizedVocal))
                return
            }
            finishSpeechRecognition(with: .success(finalUnits))
            return
        }

        if let failureDescription {
            AppLogger.warning(
                "[AILyricAlignment] Speech recognizer: \(failureDescription)",
                step: "ai-lyrics.recognize"
            )
            if latestRecognizedUnits.isEmpty {
                finishSpeechRecognition(with: .failure(AILyricAlignmentError.recognitionFailed))
            } else {
                finishSpeechRecognition(with: .success(latestRecognizedUnits))
            }
        }
    }

    private func finishSpeechRecognition(with result: Result<[AILyricRecognizedUnit], Error>) {
        speechTask?.cancel()
        speechTask = nil
        guard let continuation = speechContinuation else { return }
        speechContinuation = nil
        latestRecognizedUnits = []

        switch result {
        case .success(let units):
            continuation.resume(returning: units)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func cleanupTemporaryAudio() {
        for url in temporaryAudioURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryAudioURLs.removeAll()
    }
}

private extension AILyricAlignmentAgent {
    static let averageWordConfidenceFallback = 0.75

    nonisolated static func recognizedUnits(from result: SFSpeechRecognitionResult) -> [AILyricRecognizedUnit] {
        result.bestTranscription.segments.flatMap { segment -> [AILyricRecognizedUnit] in
            let keys = semanticKeys(in: segment.substring)
            guard !keys.isEmpty else { return [] }

            let duration = max(segment.duration, Double(keys.count) * 0.045)
            let unitDuration = duration / Double(keys.count)
            return keys.enumerated().map { index, key in
                AILyricRecognizedUnit(
                    key: key,
                    startTime: segment.timestamp + Double(index) * unitDuration,
                    duration: unitDuration,
                    confidence: Double(segment.confidence)
                )
            }
        }
    }

    nonisolated static func align(
        lines: [LyricLine],
        to recognizedUnits: [AILyricRecognizedUnit]
    ) throws -> (lines: [LyricLine], confidence: Double) {
        let meaningfulLineIndices = lines.indices.filter {
            semanticKeys(in: lines[$0].text).count >= 2
        }
        guard !meaningfulLineIndices.isEmpty, !recognizedUnits.isEmpty else {
            throw AILyricAlignmentError.noLyrics
        }

        var alignedLines = lines
        var alignedLineCount = 0
        var matchedCharacters = 0
        var meaningfulCharacters = 0
        var weightedConfidence = 0.0

        for index in meaningfulLineIndices {
            let line = lines[index]
            let officialUnits = officialUnits(in: line.text)
            meaningfulCharacters += officialUnits.count

            let searchStart = max(0, line.time - 3.0)
            let searchEnd = line.time + max(line.duration, 1.0) + 3.0
            let candidates = recognizedUnits.filter {
                $0.startTime + $0.duration >= searchStart && $0.startTime <= searchEnd
            }

            guard let alignment = alignLine(
                line,
                officialUnits: officialUnits,
                candidates: candidates
            ) else { continue }

            alignedLines[index] = alignment.line
            alignedLineCount += 1
            matchedCharacters += alignment.matchedCharacterCount
            weightedConfidence += (
                alignment.coverage * 0.72 + alignment.recognitionConfidence * 0.28
            ) * Double(alignment.matchedCharacterCount)
        }

        let requiredLines = max(2, Int(ceil(Double(meaningfulLineIndices.count) * 0.18)))
        let characterCoverage = meaningfulCharacters > 0
            ? Double(matchedCharacters) / Double(meaningfulCharacters)
            : 0
        guard alignedLineCount >= min(requiredLines, meaningfulLineIndices.count),
              characterCoverage >= 0.28 else {
            throw AILyricAlignmentError.insufficientMatch
        }

        alignedLines = normalizedLineOrder(alignedLines)
        let confidence = min(
            max(weightedConfidence / Double(max(matchedCharacters, 1)), 0),
            1
        )
        return (alignedLines, confidence)
    }

    nonisolated static func alignLine(
        _ line: LyricLine,
        officialUnits: [AILyricOfficialUnit],
        candidates: [AILyricRecognizedUnit]
    ) -> AILyricLineAlignment? {
        guard officialUnits.count >= 2, candidates.count >= 2 else { return nil }

        let matches = longestCommonSubsequenceMatches(
            official: officialUnits.map(\.key),
            recognized: candidates.map(\.key)
        )
        let coverage = Double(matches.count) / Double(officialUnits.count)
        guard matches.count >= 2, coverage >= 0.36 else { return nil }

        var anchors: [Int: (start: TimeInterval, duration: TimeInterval)] = [:]
        var confidenceTotal = 0.0
        for match in matches {
            let official = officialUnits[match.official]
            let recognized = candidates[match.recognized]
            anchors[official.originalIndex] = (recognized.startTime, recognized.duration)
            confidenceTotal += recognized.confidence
        }

        guard let words = interpolatedWords(
            text: line.text,
            anchors: anchors,
            fallbackStart: line.time,
            fallbackDuration: line.duration
        ), let firstWord = words.first else {
            return nil
        }

        let alignedStart = min(max(firstWord.startTime, line.time - 3), line.time + 3)
        let wordShift = alignedStart - firstWord.startTime
        let shiftedWords = words.map { word in
            LyricWord(
                text: word.text,
                startTime: word.startTime + wordShift,
                duration: word.duration
            )
        }
        let shiftedLastEnd = (shiftedWords.last?.startTime ?? alignedStart)
            + (shiftedWords.last?.duration ?? 0.2)
        let alignedEnd = max(shiftedLastEnd, alignedStart + 0.2)
        let alignedLine = LyricLine(
            time: alignedStart,
            text: line.text,
            translation: line.translation,
            duration: alignedEnd - alignedStart,
            words: shiftedWords
        )

        return AILyricLineAlignment(
            line: alignedLine,
            coverage: coverage,
            recognitionConfidence: confidenceTotal / Double(matches.count),
            matchedCharacterCount: matches.count
        )
    }

    nonisolated static func interpolatedWords(
        text: String,
        anchors: [Int: (start: TimeInterval, duration: TimeInterval)],
        fallbackStart: TimeInterval,
        fallbackDuration: TimeInterval
    ) -> [LyricWord]? {
        let characters = Array(text)
        guard !characters.isEmpty, !anchors.isEmpty else { return nil }

        let sortedAnchors = anchors.keys.sorted()
        guard let firstAnchorIndex = sortedAnchors.first,
              let lastAnchorIndex = sortedAnchors.last,
              let firstAnchor = anchors[firstAnchorIndex],
              let lastAnchor = anchors[lastAnchorIndex] else {
            return nil
        }

        let nominalDuration = min(
            max((fallbackDuration > 0 ? fallbackDuration : 3) / Double(characters.count), 0.055),
            0.32
        )
        var starts = Array<TimeInterval?>(repeating: nil, count: characters.count)
        for (index, anchor) in anchors where starts.indices.contains(index) {
            starts[index] = anchor.start
        }

        if firstAnchorIndex > 0 {
            for index in 0..<firstAnchorIndex {
                let distance = Double(firstAnchorIndex - index)
                starts[index] = max(0, firstAnchor.start - nominalDuration * distance)
            }
        }

        if sortedAnchors.count > 1 {
            for pairIndex in 0..<(sortedAnchors.count - 1) {
                let lowerIndex = sortedAnchors[pairIndex]
                let upperIndex = sortedAnchors[pairIndex + 1]
                guard upperIndex > lowerIndex,
                      let lowerStart = starts[lowerIndex],
                      let upperStart = starts[upperIndex] else { continue }

                for index in lowerIndex...upperIndex {
                    let progress = Double(index - lowerIndex) / Double(upperIndex - lowerIndex)
                    starts[index] = lowerStart + (upperStart - lowerStart) * progress
                }
            }
        }

        if lastAnchorIndex < characters.count - 1 {
            for index in (lastAnchorIndex + 1)..<characters.count {
                starts[index] = lastAnchor.start + nominalDuration * Double(index - lastAnchorIndex)
            }
        }

        var resolvedStarts = starts.enumerated().map { index, value in
            value ?? (fallbackStart + Double(index) * nominalDuration)
        }
        for index in 1..<resolvedStarts.count {
            resolvedStarts[index] = max(resolvedStarts[index], resolvedStarts[index - 1] + 0.012)
        }

        let fallbackEnd = fallbackStart + max(fallbackDuration, nominalDuration * Double(characters.count))
        let finalEnd = max(lastAnchor.start + lastAnchor.duration, fallbackEnd, resolvedStarts.last! + 0.06)

        return characters.indices.map { index in
            let start = resolvedStarts[index]
            let nextStart = index < resolvedStarts.count - 1 ? resolvedStarts[index + 1] : finalEnd
            return LyricWord(
                text: String(characters[index]),
                startTime: start,
                duration: max(nextStart - start, 0.04)
            )
        }
    }

    nonisolated static func normalizedLineOrder(_ lines: [LyricLine]) -> [LyricLine] {
        var output: [LyricLine] = []
        output.reserveCapacity(lines.count)
        var minimumStart: TimeInterval = 0

        for (index, line) in lines.enumerated() {
            let nextOriginalStart = index < lines.count - 1 ? lines[index + 1].time : nil
            let desiredStart = max(line.time, minimumStart)
            let resolvedStart: TimeInterval
            if let nextOriginalStart, nextOriginalStart > minimumStart + 0.02 {
                resolvedStart = min(desiredStart, nextOriginalStart - 0.01)
            } else {
                resolvedStart = desiredStart
            }
            let resolvedEnd = nextOriginalStart.map { max($0, resolvedStart + 0.2) }
                ?? (resolvedStart + max(line.duration, 0.5))
            let duration = max(resolvedEnd - resolvedStart, 0.2)
            let wordShift = resolvedStart - line.time
            let shiftedStarts = line.words.map { word in
                min(max(word.startTime + wordShift, resolvedStart), resolvedEnd - 0.04)
            }
            let shiftedWords = line.words.indices.map { wordIndex in
                let word = line.words[wordIndex]
                let start = shiftedStarts[wordIndex]
                let nextStart = wordIndex < shiftedStarts.count - 1
                    ? shiftedStarts[wordIndex + 1]
                    : resolvedEnd
                return LyricWord(
                    text: word.text,
                    startTime: start,
                    duration: max(min(nextStart, resolvedEnd) - start, 0.04)
                )
            }
            output.append(LyricLine(
                time: resolvedStart,
                text: line.text,
                translation: line.translation,
                duration: duration,
                words: shiftedWords
            ))
            minimumStart = resolvedStart + 0.01
        }

        return output
    }

    nonisolated static func longestCommonSubsequenceMatches(
        official: [String],
        recognized: [String]
    ) -> [(official: Int, recognized: Int)] {
        guard !official.isEmpty, !recognized.isEmpty else { return [] }
        let columns = recognized.count + 1
        var table = Array(repeating: 0, count: (official.count + 1) * columns)

        for i in 1...official.count {
            for j in 1...recognized.count {
                let position = i * columns + j
                if official[i - 1] == recognized[j - 1] {
                    table[position] = table[(i - 1) * columns + (j - 1)] + 1
                } else {
                    table[position] = max(
                        table[(i - 1) * columns + j],
                        table[i * columns + (j - 1)]
                    )
                }
            }
        }

        var matches: [(official: Int, recognized: Int)] = []
        var i = official.count
        var j = recognized.count
        while i > 0, j > 0 {
            if official[i - 1] == recognized[j - 1] {
                matches.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if table[(i - 1) * columns + j] >= table[i * columns + (j - 1)] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return matches.reversed()
    }

    nonisolated static func officialUnits(in text: String) -> [AILyricOfficialUnit] {
        Array(text).enumerated().compactMap { index, character in
            guard let key = semanticKey(for: character) else { return nil }
            return AILyricOfficialUnit(originalIndex: index, key: key)
        }
    }

    nonisolated static func semanticKeys(in text: String) -> [String] {
        Array(text).compactMap(semanticKey(for:))
    }

    nonisolated static func semanticKey(for character: Character) -> String? {
        let folded = String(character)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
        let semantic = folded.filter { $0.isLetter || $0.isNumber }
        return semantic.isEmpty ? nil : semantic
    }

    nonisolated static func hasReliableWordTiming(in lines: [LyricLine]) -> Bool {
        let meaningful = lines.filter { semanticKeys(in: $0.text).count >= 2 }
        guard !meaningful.isEmpty else { return false }

        let timedCount = meaningful.filter { line in
            let words = line.words.filter {
                !$0.text.isEmpty
                    && $0.startTime.isFinite
                    && $0.duration.isFinite
                    && $0.duration > 0
            }
            guard !words.isEmpty else { return false }
            let expected = max(semanticKeys(in: line.text).count, 1)
            let timed = semanticKeys(in: words.map(\.text).joined()).count
            let lineEnd = line.time + max(line.duration, 0.5)
            let overlaps = words.contains {
                $0.startTime <= lineEnd + 0.75
                    && $0.startTime + $0.duration >= line.time - 0.35
            }
            return overlaps && Double(timed) / Double(expected) >= 0.45
        }.count

        return timedCount >= max(1, Int(ceil(Double(meaningful.count) * 0.5)))
    }

    nonisolated static func preferredLocaleIdentifier(for lines: [LyricLine]) -> String {
        let text = lines.map(\.text).joined()
        let scalars = text.unicodeScalars
        if scalars.contains(where: { (0x3040...0x30FF).contains(Int($0.value)) }) {
            return "ja-JP"
        }
        if scalars.contains(where: { (0xAC00...0xD7AF).contains(Int($0.value)) }) {
            return "ko-KR"
        }
        if scalars.contains(where: { (0x3400...0x9FFF).contains(Int($0.value)) }) {
            return "zh-CN"
        }
        return "en-US"
    }

    nonisolated static func songKey(for song: Song) -> String {
        "\(song.musicSource.rawValue):\(song.id)"
    }

    nonisolated static func lyricFingerprint(for lines: [LyricLine]) -> String {
        let material = lines
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\u{1F}")
        return fnv1a64(material)
    }

    nonisolated static func cacheKey(songKey: String, lyricSource: String, fingerprint: String) -> String {
        "ai.lyrics.alignment.v1.\(songKey).\(lyricSource).\(fingerprint)"
    }

    nonisolated static func fnv1a64(_ string: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    nonisolated static func makeCachePayload(
        songKey: String,
        lyricSource: String,
        lyricFingerprint: String,
        confidence: Double,
        originalLines: [LyricLine],
        alignedLines: [LyricLine]
    ) -> AILyricAlignmentCachePayload {
        let payloadLines = zip(originalLines, alignedLines).map { original, aligned in
            AILyricAlignmentCachePayload.Line(
                text: original.text,
                originalTime: original.time,
                alignedTime: aligned.time,
                duration: aligned.duration,
                words: aligned.words.map {
                    AILyricAlignmentCachePayload.Word(
                        text: $0.text,
                        startTime: $0.startTime,
                        duration: $0.duration
                    )
                }
            )
        }

        return AILyricAlignmentCachePayload(
            version: AILyricAlignmentCachePayload.currentVersion,
            songKey: songKey,
            lyricSource: lyricSource,
            lyricFingerprint: lyricFingerprint,
            confidence: confidence,
            createdAt: Date(),
            lines: payloadLines
        )
    }

    nonisolated static func restore(
        payload: AILyricAlignmentCachePayload,
        onto currentLines: [LyricLine]
    ) -> [LyricLine]? {
        guard payload.version == AILyricAlignmentCachePayload.currentVersion,
              payload.lyricFingerprint == lyricFingerprint(for: currentLines),
              payload.lines.count == currentLines.count else {
            return nil
        }

        var restored: [LyricLine] = []
        restored.reserveCapacity(currentLines.count)
        for (current, cached) in zip(currentLines, payload.lines) {
            guard current.text == cached.text,
                  abs(current.time - cached.originalTime) <= 0.15 else {
                return nil
            }
            restored.append(LyricLine(
                time: cached.alignedTime,
                text: current.text,
                translation: current.translation,
                duration: cached.duration,
                words: cached.words.map {
                    LyricWord(
                        text: $0.text,
                        startTime: $0.startTime,
                        duration: $0.duration
                    )
                }
            ))
        }
        return restored
    }
}
