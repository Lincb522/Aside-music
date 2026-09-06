
import Foundation
struct Options: OptionSet, Sendable {
    let rawValue: UInt
    static let mixWithOthers = Self(rawValue: 1)
}
enum BackgroundAudioPolicy { case exclusive, automatic, alwaysMix }
@MainActor final class SettingsManager {
    static let shared = SettingsManager()
    var backgroundAudioPolicy = BackgroundAudioPolicy.exclusive
    var gameModeEnabled = false
    var gameModeAutoExit = true
    var gameModeAutoDucking = true
}
@MainActor final class AVAudioSession {
    typealias CategoryOptions = Options
    static let shared = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { shared }
    var secondaryAudioShouldBeSilencedHint = false
    var appliedOptions: UInt = 0
    var isOtherAudioPlaying = false
}
@MainActor final class AudioSessionMutationExecutor {
    static let shared = AudioSessionMutationExecutor()
    var requests: [(UInt, Bool)] = []
    var beforeMutation: (() -> Void)?
    var afterMutation: (() -> Void)?
    func configurePlayback(optionsRawValue: UInt, activate: Bool, authorization: AudioSessionWorkToken) async throws {
        beforeMutation?()
        try authorization.checkCancellation()
        requests.append((optionsRawValue, activate))
        AVAudioSession.shared.appliedOptions = optionsRawValue
        afterMutation?()
    }
}
enum AppLogger {
    static func info(_ message: String, step: String = "") {}
    static func success(_ message: String, step: String = "") {}
    static func warning(_ message: String) {}
    static func debug(_ message: String) {}
}
struct Song: Equatable {
    var isAppleMusic = false
    var name = "fixture"
    var dt: Int? = 180000
    var coverUrl: URL?
}
@MainActor final class Stream {
    enum State { case playing, paused, idle }
    var state = State.paused
    private var outputRunning = false
    var outputReadObserver: (() -> Void)?
    var isAudioOutputRunning: Bool {
        get { outputReadObserver?(); return outputRunning }
        set { outputRunning = newValue }
    }
    var outputVolume: Float = 1
    var duckingVolume: Float = 1
    func resume() -> Bool { state = .playing; isAudioOutputRunning = true; return true }
    func cancelNextPreparation() {}
    func stop() { state = .idle; isAudioOutputRunning = false }
    func pause() { state = .paused; isAudioOutputRunning = false }
}
@MainActor final class DummyApple {
    var isActive = false
    func matches(_ song: Song) -> Bool { true }
    func resume() async throws -> Bool { true }
}
@MainActor final class PlayerManager {
    static let shared = PlayerManager()
    let streamPlayer = Stream()
    let appleMusicPlayback = DummyApple()
    var currentSong: Song? = Song()
    var playbackSessionId = 7
    var isPlaying = false
    var isLoading = false
    var currentTime: Double = 20
    var userPausedPlaybackSessionId: Int?
    var audioSessionCoordinator: AudioProbe { coordinator }
    var isUnderInterruption: Bool { coordinator.isUnderInterruption }
    func activateAudioSessionForPlaybackChecked(reason: String) async -> Bool {
        await coordinator.activateAudioSessionForPlaybackChecked(reason: reason)
    }
    func saveStateImmediately() {}
    func beginTransitionKeepAlive(reason: String) {}
    func endTransitionKeepAlive() {}
    var lastPausedAt: Date?
    var suppressStopHandlingUntil = Date.distantPast
    static func playbackIdentityKey(for song: Song) -> String { song.name }
    var isResumeLikelyStale = false
    lazy var coordinator = AudioProbe(player: self)
    func refreshPlaybackSurfaceState() {}
    func saveState() {}
    func updateNowPlayingInfo() {}
    func updateNowPlayingArtwork(for song: Song?) {}
    func showPlaybackError(song: Song, error: Error) {}
    func matchesPlaybackTarget(_ value: Song?, expected: Song) -> Bool { value == expected }
    func beginPlaybackFade(to volume: Double, duration: Double) {}
    func cancelPlaybackFade(restoreVolume: Bool) {}
    func loadAndPlay(song: Song, startTime: Double, fadeInDuration: Double = 0, fadeInReason: String = "") {}
    func handleBackgroundAudioPolicySettingChanged() { coordinator.handleBackgroundAudioPolicySettingChanged() }
    func handleGameModeDuckingChanged() { coordinator.handleGameModeDuckingChanged() }
}
@MainActor final class AudioProbe {
    let player: PlayerManager
    init(player: PlayerManager) { self.player = player }
    static let playbackAudioSessionOptions: Options = []
    static let mixingAudioSessionOptions: Options = [.mixWithOthers]
    var lastAppliedAudioSessionOptions: Options? = []
    // INTERRUPTION_STATE
    var playbackWorkToken = AudioSessionWorkToken()
    var interruptionEndedResumeTask: Task<Void, Never>?
    var stalledOutputRecoveryTask: Task<Void, Never>?
    func resetPlaybackOutputLiveness() {}
    var wasPlayingBeforeInterruption = false
    var routeChangeResumeWorkItem: DispatchWorkItem?
    var audioOutputRecoveryTask: Task<Void, Never>?
    var activationDuringInterruption = 0
    var gameVoiceDuckingTask: Task<Void, Never>?
    var gameVoiceDuckingTarget: Float = 1
    var interruptionResumeTask: Task<Void, Never>?
    static let interruptionResumeBackoff: [Double] = [1.5, 3, 6]
    enum Level { case info, debug, warning, error }
    func markSelfManagedSessionMutation() {}
    func recordAudioDiagnostic(_ text: String, level: Level, event: String, context: [String:String] = [:]) {}
    func cancelInterruptionWatchdog() {}


// AUDIO_METHODS
}

@MainActor final class MPNowPlayingInfoCenter {
    static let shared = MPNowPlayingInfoCenter()
    static func `default`() -> MPNowPlayingInfoCenter { shared }
    var nowPlayingInfo: [String: Any]?
}
struct CatalogSong {
    struct ID { var rawValue = "fixture" }
    struct Artwork { func url(width: Int, height: Int) -> URL? { nil } }
    struct Album { var artwork: Artwork? }
    var id = ID()
    var artwork: Artwork?
    var albums: [Album]?
}
@MainActor final class AppleMusicService {
    static let shared = AppleMusicService()
    func playableSong(for song: Song) async throws -> CatalogSong { CatalogSong() }
}
enum ApplicationMusicPlayer {
    struct Queue {
        init(for songs: [CatalogSong], startingAt song: CatalogSong) {}
    }
}
@MainActor final class FakeMusicPlayer {
    var playCalls = 0
    var pauseCalls = 0
    var playbackTime: Double = 0
    var queue = ApplicationMusicPlayer.Queue(for: [], startingAt: CatalogSong())
    func prepareToPlay() async throws {}
    var onPlay: (() -> Void)?
    func play() async throws { playCalls += 1; onPlay?() }
    func pause() { pauseCalls += 1 }
}
struct AppleMusicPlaybackSnapshot {
    var playbackTime: Double
    var isPlaying: Bool
    var isStopped: Bool
    var isPaused: Bool
}
@MainActor final class AppleProbe {
    let player: PlayerManager
    init(player: PlayerManager) { self.player = player }
    var isActive = true
    var musicPlayer: FakeMusicPlayer? = FakeMusicPlayer()
    var lastPlaybackTime: Double = 0
    var artworkResolutionTask: Task<Void, Never>?
    var activeCatalogID: String?
    var activeRequestedIdentity: String?
    var activeArtworkURL: URL?
    func resolvedMusicPlayer() -> FakeMusicPlayer { musicPlayer! }
    func resolveMissingArtwork(for song: Song, preferred: CatalogSong, sessionID: Int) {}
    func resetLocalPlaybackClock(playbackTime: Double, isPlaying: Bool, isStopped: Bool, isPaused: Bool) {}
    var latestSnapshot = AppleMusicPlaybackSnapshot(playbackTime: 0, isPlaying: false, isStopped: false, isPaused: true)
    var wasAudiblyPlaying = false
    var didReportNaturalEnd = false
    func resolvedLocalPlaybackTime() -> Double { 20 }
    func updateLocalPlaybackClock(position: Double, isPlaying: Bool) {}

// APPLE_METHODS
}

enum AppConfig {
    enum StorageKeys { static let gameModeSavedBackgroundPolicy = "savedPolicy" }
}
@MainActor final class UserDefaults {
    static let standard = UserDefaults(suiteName: "fixture")!
    static var groupValue: Bool?
    static var hasSavedPolicy = false
    init?(suiteName: String) {}
    func object(forKey key: String) -> Any? {
        key == "savedPolicy" ? (Self.hasSavedPolicy ? "exclusive" : nil) : Self.groupValue
    }
}
@MainActor final class GameModeManager {
    static let shared = GameModeManager()
    let settings = SettingsManager.shared
    var isActive = false
    var enterCount = 0
    var exitCount = 0
    var backups = 0
    var autoExitDelayTask: Task<Void, Never>?
    var lastObservedOtherAudio: Bool?
    static let autoExitDelay: Double = 12
    func applyEnter(persist: Bool) {
        enterCount += 1
        if persist { backups += 1; UserDefaults.hasSavedPolicy = true }
        settings.backgroundAudioPolicy = .alwaysMix
        PlayerManager.shared.handleBackgroundAudioPolicySettingChanged()
    }
    func applyExit(persist: Bool) {
        exitCount += 1
        UserDefaults.hasSavedPolicy = false
        settings.backgroundAudioPolicy = .exclusive
        PlayerManager.shared.handleBackgroundAudioPolicySettingChanged()
    }
    func syncToAppGroup(active: Bool) { UserDefaults.groupValue = active }

// GAME_METHODS
}

@main struct BackgroundAudioRegressions {
    @MainActor static func settle() async {
        for _ in 0..<60 { await Task.yield() }
    }

    @MainActor static func main() async throws {
        let p = PlayerManager.shared
        let c = p.coordinator
        let executor = AudioSessionMutationExecutor.shared
        func reset() {
            c.cancelScheduledAutoResumeWork()
            c.isUnderInterruption = false
            c.wasPlayingBeforeInterruption = false
            c.lastAppliedAudioSessionOptions = nil
            p.userPausedPlaybackSessionId = nil
            p.playbackSessionId = 7
            p.currentSong = Song()
            p.isPlaying = false
            p.isLoading = false
            p.appleMusicPlayback.isActive = false
            p.streamPlayer.pause()
            SettingsManager.shared.backgroundAudioPolicy = .exclusive
            AVAudioSession.shared.secondaryAudioShouldBeSilencedHint = false
            AVAudioSession.shared.isOtherAudioPlaying = false
            executor.requests = []
            executor.beforeMutation = nil
            executor.afterMutation = nil
        }
        for policy in [BackgroundAudioPolicy.exclusive, .automatic, .alwaysMix] {
            for hint in [false, true] {
                SettingsManager.shared.backgroundAudioPolicy = policy
                let mixed = c.audioSessionOptions(primaryAudioActive: hint).contains(.mixWithOthers)
                precondition(mixed == (policy == .alwaysMix || (policy == .automatic && hint)))
            }
        }
        print("PASS: all 6 policy and primary-audio combinations")

        reset()
        p.appleMusicPlayback.isActive = true
        SettingsManager.shared.backgroundAudioPolicy = .alwaysMix
        c.handleBackgroundAudioPolicySettingChanged()
        await settle()
        precondition(executor.requests.isEmpty)
        print("PASS B01: changing policy with paused Apple Music does not mutate or activate audio")

        for policy in [BackgroundAudioPolicy.exclusive, .automatic, .alwaysMix] {
            for hint in [false, true] {
                reset()
                p.appleMusicPlayback.isActive = true
                p.isPlaying = true
                SettingsManager.shared.backgroundAudioPolicy = policy
                AVAudioSession.shared.secondaryAudioShouldBeSilencedHint = hint
                c.handleBackgroundAudioPolicySettingChanged()
                await settle()
                precondition(executor.requests.isEmpty)
                let apple = AppleProbe(player: p)
                _ = apple.pause()
                let resumed = try await apple.resume()
                precondition(resumed)
                let shouldMix = policy == .alwaysMix || (policy == .automatic && hint)
                precondition(executor.requests.last?.0 == (shouldMix ? 1 : 0))
                precondition(apple.musicPlayer?.playCalls == 1)
            }
        }
        print("PASS B02: Apple Music resume applies all 6 policy/hint combinations before play")
        for autoPlay in [false, true] {
            for policy in [BackgroundAudioPolicy.exclusive, .automatic, .alwaysMix] {
                for hint in [false, true] {
                    reset()
                    SettingsManager.shared.backgroundAudioPolicy = policy
                    AVAudioSession.shared.secondaryAudioShouldBeSilencedHint = hint
                    let apple = AppleProbe(player: p)
                    try await apple.start(song: Song(isAppleMusic: true), autoPlay: autoPlay, startTime: 0, sessionID: p.playbackSessionId)
                    precondition(executor.requests.count == (autoPlay ? 1 : 0))
                    precondition(apple.musicPlayer?.playCalls == (autoPlay ? 1 : 0))
                    if autoPlay {
                        let shouldMix = policy == .alwaysMix || (policy == .automatic && hint)
                        precondition(executor.requests.last?.0 == (shouldMix ? 1 : 0))
                    }
                }
            }
        }
        print("PASS B02: all 12 MusicKit startup combinations; preload stays inactive")

        reset()
        let interruptedStart = AppleProbe(player: p)
        interruptedStart.musicPlayer?.onPlay = { c.isUnderInterruption = true }
        do {
            try await interruptedStart.start(song: Song(isAppleMusic: true), autoPlay: true, startTime: 0, sessionID: p.playbackSessionId)
            preconditionFailure("interrupted start committed")
        } catch is CancellationError {}
        precondition(interruptedStart.musicPlayer?.pauseCalls == 1)
        precondition(c.isUnderInterruption && !p.isPlaying)
        print("PASS: interruption during MusicKit start pauses late output and prevents commit")


        reset()
        c.wasPlayingBeforeInterruption = true
        let oldEnded = c.scheduleEndedResume()
        c.isUnderInterruption = true
        await oldEnded.value
        precondition(executor.requests.isEmpty && c.isUnderInterruption && !p.isPlaying)
        // A second end cannot make an older end task valid again.
        c.isUnderInterruption = false
        let newerEnded = c.scheduleEndedResume()
        await newerEnded.value
        precondition(p.isPlaying && !c.wasPlayingBeforeInterruption && executor.requests.count == 1)
        print("PASS B03: a new interruption cancels the old end; only the new end resumes")

        reset()
        c.wasPlayingBeforeInterruption = true
        c.isUnderInterruption = true
        let interruptedResume = await c.resumeAfterInterruption()
        precondition(!interruptedResume)
        c.isUnderInterruption = false
        c.wasPlayingBeforeInterruption = false // ended without shouldResume
        let unapprovedResume = await c.resumeAfterInterruption()
        precondition(!unapprovedResume)
        precondition(executor.requests.isEmpty)
        print("PASS: no automatic activation during interruption or without resume intent")

        reset()
        p.isPlaying = true
        p.streamPlayer.state = .playing
        p.streamPlayer.isAudioOutputRunning = false
        // Observe the real recovery task's second delay, rather than guessing
        // when its first sleep ends.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var reads = 0
            p.streamPlayer.outputReadObserver = {
                reads += 1
                if reads == 2 {
                    p.streamPlayer.outputReadObserver = nil
                    continuation.resume()
                }
            }
            c.scheduleAudioOutputRecoveryIfNeeded(reason: "fixture output failure")
        }
        let pendingRecovery = c.audioOutputRecoveryTask
        precondition(pendingRecovery != nil)
        c.isUnderInterruption = true
        c.wasPlayingBeforeInterruption = true
        p.isPlaying = false
        p.streamPlayer.pause()
        await pendingRecovery?.value
        precondition(executor.requests.isEmpty && !p.isPlaying && c.isUnderInterruption)
        print("PASS B07: interruption in the second recovery delay prevents activation and playback")

        reset()
        p.isPlaying = true
        executor.beforeMutation = { c.isUnderInterruption = true; p.isPlaying = false }
        let queuedRecovery = await c.recoverUnavailableAudioOutput(reason: "queued request")
        precondition(!queuedRecovery)
        precondition(executor.requests.isEmpty && !p.isPlaying && c.isUnderInterruption)
        print("PASS: a queued activation invalidated before mutation cannot execute")

        reset()
        p.isPlaying = true
        executor.afterMutation = { c.isUnderInterruption = true; p.isPlaying = false; c.wasPlayingBeforeInterruption = true }
        let inFlightRecovery = await c.recoverUnavailableAudioOutput(reason: "in-flight request")
        precondition(!inFlightRecovery)
        precondition(!p.isPlaying && c.isUnderInterruption && c.wasPlayingBeforeInterruption)
        print("PASS: interruption during activation prevents stale completion from resuming or clearing state")

        reset()
        p.isPlaying = true
        c.wasPlayingBeforeInterruption = true
        let pendingPause = c.scheduleEndedResume()
        c.cancelScheduledAutoResumeWork()
        p.userPausedPlaybackSessionId = p.playbackSessionId
        p.isPlaying = false
        c.wasPlayingBeforeInterruption = false
        await pendingPause.value
        precondition(executor.requests.isEmpty && !p.isPlaying)
        c.reapplyAudioSessionOptions(reason: "paused mode change")
        await settle()
        precondition(executor.requests.isEmpty)
        print("PASS: manual pause invalidates pending work and mode changes leave audio idle")

        reset()
        c.wasPlayingBeforeInterruption = true
        let supersededResume = c.scheduleEndedResume()
        c.prepareForExplicitPlayback(replacingCurrentSong: true)
        p.playbackSessionId += 1
        p.currentSong = Song(name: "new selection")
        p.isLoading = true
        await supersededResume.value
        precondition(executor.requests.isEmpty && p.isLoading && !c.wasPlayingBeforeInterruption)
        print("PASS: a new explicit song selection invalidates the old resume without clearing the new load")


        for useWidget in [false, true] {
            reset()
            p.isPlaying = true
            p.streamPlayer.state = .playing
            p.streamPlayer.isAudioOutputRunning = true
            let game = GameModeManager()
            if useWidget { UserDefaults.groupValue = true; game.syncFromAppGroup() }
            else { game.enter() }
            await settle()
            precondition(game.isActive && executor.requests.last?.0 == 1)
            precondition(game.enterCount == 1 && game.backups == 1)
            game.syncFromAppGroup()
            precondition(game.enterCount == 1 && game.backups == 1)
            if useWidget { UserDefaults.groupValue = false; game.syncFromAppGroup() }
            else { game.exit() }
            await settle()
            precondition(!game.isActive && game.exitCount == 1 && executor.requests.last?.0 == 0)
        }
        print("PASS B04: app and Control Center enter/exit apply identical session policy; echoes do not overwrite backups")

        for shared in [nil, false, true] as [Bool?] {
            for legacy in [false, true] {
                reset()
                UserDefaults.groupValue = shared
                UserDefaults.hasSavedPolicy = true
                SettingsManager.shared.gameModeEnabled = legacy
                let game = GameModeManager()
                game.restoreSharedState()
                let expected = shared ?? legacy
                precondition(game.isActive == expected && UserDefaults.groupValue == expected)
                precondition(game.backups == 0)
                precondition(game.exitCount == (expected ? 0 : 1))
                await settle()
                precondition(executor.requests.isEmpty)
            }
        }
        print("PASS B05: all 6 shared/legacy combinations; explicit false wins and saved policy restores")

        reset()
        let game = GameModeManager()
        game.isActive = true
        game.observeOtherAudio(isPlaying: false)
        precondition(game.autoExitDelayTask == nil)
        game.observeOtherAudio(isPlaying: true)
        game.observeOtherAudio(isPlaying: false)
        let cancelledExit = game.autoExitDelayTask
        precondition(cancelledExit != nil)
        game.observeOtherAudio(isPlaying: true)
        await cancelledExit?.value
        precondition(game.isActive && game.autoExitDelayTask == nil)
        game.observeOtherAudio(isPlaying: false)
        await game.autoExitDelayTask?.value
        precondition(!game.isActive)
        print("PASS B06: sampled external audio needs a real stop transition; restart cancels exit; 12s silence exits")
        reset()
        p.appleMusicPlayback.isActive = true
        let interruptedApple = AppleProbe(player: p)
        interruptedApple.musicPlayer?.onPlay = { c.isUnderInterruption = true }
        let appleResumed = try await interruptedApple.resume()
        precondition(!appleResumed && !p.isPlaying && c.isUnderInterruption)
        print("PASS: MusicKit completion cannot publish playing after a new interruption")

        reset()
        c.wasPlayingBeforeInterruption = true
        c.scheduleInterruptionResumeRetry(reason: "fixture retry")
        let retry = c.interruptionResumeTask
        c.isUnderInterruption = true
        await retry?.value
        precondition(executor.requests.isEmpty && c.isUnderInterruption)
        c.prepareForExplicitPlayback()
        let manualResume = await c.resumeAfterInterruption(reason: "user command")
        precondition(manualResume && p.isPlaying)
        print("PASS: retry is cancelled by interruption; an explicit play command can resume")

        reset()
        UserDefaults.groupValue = true
        AVAudioSession.shared.secondaryAudioShouldBeSilencedHint = true
        c.sampleOtherAudioState()
        await c.gameVoiceDuckingTask?.value
        precondition(abs(p.streamPlayer.duckingVolume - 0.32) < 0.001)
        // Sampling, with no foreground notification, restores volume on hint end.
        AVAudioSession.shared.secondaryAudioShouldBeSilencedHint = false
        c.sampleOtherAudioState()
        await c.gameVoiceDuckingTask?.value
        precondition(abs(p.streamPlayer.duckingVolume - 1) < 0.001)
        p.appleMusicPlayback.isActive = true
        AVAudioSession.shared.secondaryAudioShouldBeSilencedHint = true
        c.sampleOtherAudioState()
        await c.gameVoiceDuckingTask?.value
        precondition(p.streamPlayer.duckingVolume == 1)
        print("PASS B06: heartbeat samples duck/restore without notifications; MusicKit is excluded")

        // Reversing a just-started fade must cancel it even if the current volume
        // still equals the new target before the first animation step.
        p.appleMusicPlayback.isActive = false
        c.sampleOtherAudioState()
        let obsoleteDuck = c.gameVoiceDuckingTask
        UserDefaults.groupValue = false
        c.sampleOtherAudioState()
        await obsoleteDuck?.value
        precondition(p.streamPlayer.duckingVolume == 1)
        print("PASS: exiting game mode immediately cancels a not-yet-started duck fade")
        print("Background audio regressions passed (system services and media output are synthetic).")
    }
}
