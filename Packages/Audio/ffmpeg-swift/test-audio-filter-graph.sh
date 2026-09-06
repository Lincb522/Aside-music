#!/bin/bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ffmpeg_prefix="${1:?Usage: bash test-audio-filter-graph.sh /path/to/host/ffmpeg/prefix}"
dsp_source="$package_root/Sources/FFmpegSwiftSDK"
test_source="$package_root/Tools/AudioFilterGraphRegression"
test_output="$(mktemp -d /tmp/mono-audio-graph-regression.XXXXXX)"

# This standalone macOS integration test does not build the iOS application.
xcrun swiftc -O -whole-module-optimization \
    -I "$test_source/CFFmpeg" -I "$ffmpeg_prefix/include" \
    -L "$ffmpeg_prefix/lib" -lavfilter -lavutil \
    -o "$test_output/audio-filter-graph-tests" \
    "$dsp_source/Models/AudioBuffer.swift" \
    "$dsp_source/Engine/AudioEffectTransition.swift" \
    "$dsp_source/API/AudioEffects.swift" \
    "$dsp_source/Engine/AudioFilterGraph.swift" \
    "$test_source/main.swift"
"$test_output/audio-filter-graph-tests"
