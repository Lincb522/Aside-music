#!/bin/bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dsp_source="$package_root/Sources/FFmpegSwiftSDK"
test_output="$(mktemp -d /tmp/mono-audio-regression.XXXXXX)"

# Compile only the native DSP sources on macOS, without building the iOS app
# or resolving FFmpeg binary dependencies.
xcrun swiftc -O -whole-module-optimization -o "$test_output/audio-realtime-tests" \
    "$dsp_source/Models/AudioBuffer.swift" \
    "$dsp_source/Models/EQBand.swift" \
    "$dsp_source/Engine/RealtimeLock.swift" \
    "$dsp_source/Engine/AudioEffectTransition.swift" \
    "$dsp_source/Engine/EQFilter.swift" \
    "$dsp_source/Engine/AudioRepairEngine.swift" \
    "$package_root/Tools/AudioRealtimeRegression/ContinuityTests.swift" \
    "$package_root/Tools/AudioRealtimeRegression/main.swift"
"$test_output/audio-realtime-tests"
