#!/usr/bin/env python3
"""Run owning audio-policy/recovery methods with synthetic platform dependencies.

No app singleton, media account, device audio session or user defaults are accessed.
The fixture is compiled with Swift 6; methods are extracted unchanged from source.
"""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def extract(source, declaration):
    start = source.index(declaration)
    end = source.index('{', start) + 1
    depth = 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

def run():
    audio = (ROOT / 'Sources/Mono/Playback/Session/AudioSessionCoordinator.swift').read_text()
    apple = (ROOT / 'Sources/Mono/Playback/Sources/AppleMusicPlaybackCoordinator.swift').read_text()
    game = (ROOT / 'Sources/Mono/Managers/Settings/GameModeManager.swift').read_text()
    fixture = Path(__file__).with_name('background_audio_fixture.swift').read_text()
    methods = '\n'.join(extract(audio, 'func ' + name) for name in [
        'audioSessionOptions(', 'handleBackgroundAudioPolicySettingChanged(',
        'handleGameModeDuckingChanged(', 'reapplyAudioSessionOptions(',
        'isPlaybackWorkCurrent(', 'prepareForExplicitPlayback(',
        'activateAudioSessionForPlaybackChecked(', 'cancelScheduledAutoResumeWork(',
        'resumeAfterInterruption(', 'scheduleAudioOutputRecoveryIfNeeded(',
        'recoverUnavailableAudioOutput(', 'scheduleResumeAfterRouteChangeIfNeeded(',
        'scheduleInterruptionResumeRetry(', 'cancelInterruptionResumeRetry(',
        'sampleOtherAudioState(', 'updateGameModeVoiceDucking('
    ])
    # Use the actual delayed-ended task, including the production delay and guards.
    ended = audio[audio.index('if shouldResume {'):]
    delayed = extract(ended, 'Task { @MainActor [weak self] in')
    methods += '\nfunc scheduleEndedResume() -> Task<Void, Never> {\nlet token = playbackWorkToken\nlet task = ' + delayed + '\ninterruptionEndedResumeTask = task\nreturn task\n}\n'
    methods += '\n' + extract(audio, 'var isGameModeEnabledWithoutInitializingManager:')
    fixture = fixture.replace('// INTERRUPTION_STATE', extract(audio, 'var isUnderInterruption:'))
    methods += '\n' + extract(audio, 'var canAutoResumeWithOtherAudio:')
    methods += '\n' + extract(audio, 'func isAutoResumePermittedNow(')
    fixture = fixture.replace('// AUDIO_METHODS', methods)
    fixture = fixture.replace('// APPLE_METHODS', '\n'.join(extract(apple, 'func ' + n) for n in ['start(', 'resume()', 'pause()']))
    fixture = fixture.replace('// GAME_METHODS', '\n'.join([
        extract(game, 'var sharedEnabled:')
    ] + [extract(game, 'func ' + n) for n in [
        'restoreSharedState()', 'syncFromAppGroup()', 'transition(', 'enter()', 'exit()',
        'observeOtherAudio(', 'scheduleAutoExitCheck()'
    ]]))
    token = (ROOT / 'Sources/Mono/Playback/Session/AudioSessionWorkToken.swift').read_text()
    # Integration requirements: both playback backends sample audio state before
    # the heartbeat's Apple Music early return; MusicKit startup must apply policy.
    heartbeat = (ROOT / 'Sources/Mono/Playback/State/PlaybackHeartbeat.swift').read_text()
    assert heartbeat.index('sampleOtherAudioState()') < heartbeat.index('appleMusicPlayback.tick()')
    start = extract(apple, 'func start(')
    assert start.index('activateAudioSessionForPlaybackChecked') < start.index('try await musicPlayer.play()')
    with tempfile.TemporaryDirectory(prefix='mono-background-regressions-') as directory:
        directory = Path(directory)
        executor_fixture = Path(__file__).with_name('audio_session_executor_fixture.swift').read_text()
        executor_fixture = executor_fixture.replace('// EXECUTOR', extract(audio, 'private final class AudioSessionMutationExecutor:'))
        for name, contents in [('recovery', fixture), ('executor', executor_fixture)]:
            source = directory / f'{name}.swift'
            source.write_text(token + '\n' + contents)
            binary = directory / name
            subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-parse-as-library', str(source), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True, timeout=45)

if __name__ == '__main__':
    run()
