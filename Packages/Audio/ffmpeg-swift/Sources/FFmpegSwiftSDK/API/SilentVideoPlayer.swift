import AVFoundation
import CFFmpeg
import Foundation

/// State emitted by ``SilentVideoPlayer``.
public enum SilentVideoPlaybackState: Equatable, Sendable {
    case idle
    case loading
    case inputResolved(SilentVideoInputInfo)
    case playing(hardwareAccelerated: Bool)
    case failed(String)
}

/// A looping video-only playback surface that never creates an audio renderer.
///
/// The input may be a regular media file or an HLS playlist. Audio streams are
/// discarded at the demuxer and no `AVPlayer`, `AVAudioEngine`, or audio output
/// unit is created, so this surface cannot take ownership of the app's audio
/// session while MusicKit is playing.
public final class SilentVideoPlayer: @unchecked Sendable {
    public var videoDisplayLayer: AVSampleBufferDisplayLayer {
        videoRenderer.sampleBufferDisplayLayer
    }

    public var state: SilentVideoPlaybackState {
        stateQueue.sync { storedState }
    }

    public var onStateChange: (@Sendable (SilentVideoPlaybackState) -> Void)? {
        get { stateQueue.sync { stateChangeHandler } }
        set { stateQueue.sync { stateChangeHandler = newValue } }
    }

    private let videoRenderer = VideoRenderer()
    private let stateQueue = DispatchQueue(label: "ffmpeg.SilentVideoPlayer.state")
    private var storedState: SilentVideoPlaybackState = .idle
    private var stateChangeHandler: (@Sendable (SilentVideoPlaybackState) -> Void)?
    private var playbackTask: Task<Void, Never>?
    private var connectionManager: ConnectionManager?
    private var generation: UInt64 = 0
    private var isActive = false

    public init() {
        videoDisplayLayer.videoGravity = .resizeAspectFill
        videoDisplayLayer.backgroundColor = nil
    }

    deinit {
        stop(notify: false)
    }

    /// Starts or replaces the current looping video input.
    public func play(url: String) {
        stop(notify: false)
        videoRenderer.resetForNewSession()

        let activeGeneration = stateQueue.sync { () -> UInt64 in
            generation &+= 1
            isActive = true
            return generation
        }
        transition(to: .loading)

        let task = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.run(url: url, generation: activeGeneration)
        }
        let shouldCancel = stateQueue.sync { () -> Bool in
            guard isActive, generation == activeGeneration else { return true }
            playbackTask = task
            return false
        }
        if shouldCancel {
            task.cancel()
        }
    }

    /// Stops network I/O, decoding, and presentation immediately.
    public func stop() {
        stop(notify: true)
    }

    private func stop(notify: Bool) {
        let resources = stateQueue.sync { () -> (Task<Void, Never>?, ConnectionManager?, Bool) in
            let wasActive = isActive || storedState != .idle
            generation &+= 1
            isActive = false
            let task = playbackTask
            let connection = connectionManager
            playbackTask = nil
            connectionManager = nil
            return (task, connection, wasActive)
        }

        resources.0?.cancel()
        resources.1?.disconnect()
        videoRenderer.clear()
        if notify, resources.2 {
            transition(to: .idle)
        }
    }

    private func run(url: String, generation: UInt64) async {
        do {
            guard let sourceURL = URL(string: url) else {
                throw SilentVideoPlayerError.invalidInputURL
            }
            let resolvedInput = try await SilentVideoInputResolver.shared.resolve(sourceURL)
            guard isCurrent(generation), !Task.isCancelled else { return }
            transition(to: .inputResolved(resolvedInput.info))

            while isCurrent(generation), !Task.isCancelled {
                let manager = ConnectionManager()
                guard install(manager, generation: generation) else {
                    manager.disconnect()
                    return
                }

                let playbackURL = resolvedInput.url.absoluteString
                let context = try await manager.connect(url: playbackURL)
                guard isCurrent(generation), !Task.isCancelled else {
                    manager.disconnect()
                    return
                }

                let renderedFrameCount = try decodeSinglePass(
                    url: playbackURL,
                    formatContext: context,
                    generation: generation
                )
                manager.disconnect()
                clear(manager, generation: generation)

                guard isCurrent(generation), !Task.isCancelled else { return }
                guard renderedFrameCount > 0 else {
                    throw SilentVideoPlayerError.noDecodedFrames
                }

                // Reopen at natural EOF. This is more reliable for HLS VOD than
                // seeking an input whose media playlist may have been refreshed.
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
        } catch {
            finishWithError(error, generation: generation)
        }
    }

    private func decodeSinglePass(
        url: String,
        formatContext: FFmpegFormatContext,
        generation: UInt64
    ) throws -> Int {
        let demuxer = Demuxer(formatContext: formatContext, url: url)
        let info = try demuxer.findStreams()
        guard info.hasVideo, demuxer.currentVideoStreamIndex >= 0 else {
            throw SilentVideoPlayerError.missingVideoStream
        }

        let videoStreamIndex = Int(demuxer.currentVideoStreamIndex)
        guard let videoStream = formatContext.stream(at: videoStreamIndex),
              let codecParameters = videoStream.pointee.codecpar else {
            throw SilentVideoPlayerError.invalidVideoStream
        }

        // Stop FFmpeg from opening or feeding any companion audio rendition.
        // This is stronger than muting: audio packets never reach a decoder or
        // an output object because neither exists in this pipeline.
        for streamIndex in 0..<formatContext.streamCount where streamIndex != videoStreamIndex {
            formatContext.stream(at: streamIndex)?.pointee.discard = AVDISCARD_ALL
        }

        let decoder = try VideoDecoder(
            codecParameters: codecParameters,
            codecID: codecParameters.pointee.codec_id,
            timeBase: videoStream.pointee.time_base
        )

        var clock = SilentVideoClock()
        var renderedFrameCount = 0
        var consecutiveDecodeFailures = 0

        while isCurrent(generation), !Task.isCancelled {
            guard let packet = try demuxer.readNextPacket() else { break }

            switch packet {
            case .audio(let audioPacket):
                release(audioPacket)

            case .video(let videoPacket):
                defer { release(videoPacket) }
                do {
                    let frame = try decoder.decode(packet: videoPacket)
                    consecutiveDecodeFailures = 0
                    guard waitUntilPresentation(
                        frame: frame,
                        clock: &clock,
                        generation: generation
                    ) else {
                        continue
                    }

                    videoRenderer.renderImmediately(frame)
                    renderedFrameCount += 1
                    if renderedFrameCount == 1 {
                        transition(
                            to: .playing(
                                hardwareAccelerated: decoder.isHardwareAccelerated
                            )
                        )
                    }
                } catch let error as FFmpegError where !error.isUnrecoverable {
                    consecutiveDecodeFailures += 1
                    if consecutiveDecodeFailures >= 240 {
                        throw SilentVideoPlayerError.decoderMadeNoProgress
                    }
                }
            }
        }

        return renderedFrameCount
    }

    private func waitUntilPresentation(
        frame: VideoFrame,
        clock: inout SilentVideoClock,
        generation: UInt64
    ) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let fallbackDuration = frame.duration.isFinite && frame.duration > 0
            ? min(frame.duration, 0.25)
            : 1.0 / 30.0
        var presentationTime = frame.pts

        if !presentationTime.isFinite {
            presentationTime = (clock.lastPresentationTime ?? 0) + fallbackDuration
        } else if let previous = clock.lastPresentationTime,
                  presentationTime <= previous {
            presentationTime = previous + fallbackDuration
        }

        if clock.originPresentationTime == nil {
            clock.originPresentationTime = presentationTime
            clock.originUptime = now
        } else if let previous = clock.lastPresentationTime,
                  presentationTime - previous > 2.0 {
            // HLS discontinuities use a new timestamp epoch. Rebase instead of
            // freezing the cover while waiting for an unrelated large PTS gap.
            clock.originPresentationTime = presentationTime
            clock.originUptime = now
        }
        clock.lastPresentationTime = presentationTime

        guard let originPresentationTime = clock.originPresentationTime else {
            return false
        }
        let target = clock.originUptime + max(0, presentationTime - originPresentationTime)

        while isCurrent(generation), !Task.isCancelled {
            let delay = target - ProcessInfo.processInfo.systemUptime
            if delay <= 0.001 { break }
            Thread.sleep(forTimeInterval: min(delay, 0.025))
        }
        guard isCurrent(generation), !Task.isCancelled else { return false }

        let lateness = ProcessInfo.processInfo.systemUptime - target
        if lateness >= 0.50 {
            // A long segment fetch must not leave the cover permanently behind
            // its clock. Resume from the newest decoded frame after the stall.
            clock.originPresentationTime = presentationTime
            clock.originUptime = ProcessInfo.processInfo.systemUptime
            return true
        }

        // Drop a short burst of stale frames, then continue at normal cadence.
        return lateness < 0.20
    }

    private func install(_ manager: ConnectionManager, generation: UInt64) -> Bool {
        stateQueue.sync {
            guard isActive, self.generation == generation else { return false }
            connectionManager = manager
            return true
        }
    }

    private func clear(_ manager: ConnectionManager, generation: UInt64) {
        stateQueue.sync {
            guard self.generation == generation,
                  connectionManager === manager else { return }
            connectionManager = nil
        }
    }

    private func finishWithError(_ error: Error, generation: UInt64) {
        let result = stateQueue.sync { () -> (ConnectionManager?, Bool) in
            guard isActive, self.generation == generation else { return (nil, false) }
            isActive = false
            playbackTask = nil
            let manager = connectionManager
            connectionManager = nil
            return (manager, true)
        }
        guard result.1 else { return }

        result.0?.disconnect()
        videoRenderer.clear()
        transition(to: .failed(Self.errorDescription(error)))
    }

    private func transition(to newState: SilentVideoPlaybackState) {
        let callback = stateQueue.sync { () -> (@Sendable (SilentVideoPlaybackState) -> Void)? in
            guard storedState != newState else { return nil }
            storedState = newState
            return stateChangeHandler
        }
        guard let callback else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.state == newState else { return }
            callback(newState)
        }
    }

    private func isCurrent(_ generation: UInt64) -> Bool {
        stateQueue.sync {
            isActive && self.generation == generation
        }
    }

    private func release(_ packet: UnsafeMutablePointer<AVPacket>) {
        var ownedPacket: UnsafeMutablePointer<AVPacket>? = packet
        av_packet_unref(packet)
        av_packet_free(&ownedPacket)
    }

    private static func errorDescription(_ error: Error) -> String {
        if let error = error as? FFmpegError {
            return error.description
        }
        if let error = error as? LocalizedError,
           let description = error.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

private struct SilentVideoClock {
    var originPresentationTime: TimeInterval?
    var originUptime: TimeInterval = 0
    var lastPresentationTime: TimeInterval?
}

private enum SilentVideoPlayerError: LocalizedError {
    case invalidInputURL
    case missingVideoStream
    case invalidVideoStream
    case noDecodedFrames
    case decoderMadeNoProgress

    var errorDescription: String? {
        switch self {
        case .invalidInputURL:
            return "The video input URL is invalid"
        case .missingVideoStream:
            return "The input does not contain a video stream"
        case .invalidVideoStream:
            return "The video stream metadata is invalid"
        case .noDecodedFrames:
            return "The video stream ended before producing a frame"
        case .decoderMadeNoProgress:
            return "The video decoder could not produce frames"
        }
    }
}
