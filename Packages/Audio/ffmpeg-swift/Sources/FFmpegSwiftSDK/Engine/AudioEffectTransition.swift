// AudioEffectTransition.swift
// FFmpegSwiftSDK

/// Mixes aligned dry/wet PCM without leaving a wet tail when a fade-out ends
/// partway through a render block. Returns the remaining ramp length.
enum AudioEffectTransition {
    static func mix(
        wetData: UnsafeMutablePointer<Float>,
        dryData: UnsafePointer<Float>,
        wetFrameCount: Int,
        dryFrameCount: Int,
        wetChannelCount: Int,
        dryChannelCount: Int,
        durationFrames: Int,
        remainingFrames: Int,
        fadingIn: Bool
    ) -> Int {
        let channels = min(wetChannelCount, dryChannelCount)
        let frames = min(wetFrameCount, dryFrameCount)
        guard remainingFrames > 0, durationFrames > 0, channels > 0, frames > 0 else {
            return remainingFrames
        }
        let completed = durationFrames - remainingFrames
        for frame in 0..<frames {
            let progress = min(1, Float(completed + frame + 1) / Float(durationFrames))
            let eased = progress * progress * (3 - 2 * progress)
            let wetMix = fadingIn ? eased : 1 - eased
            for channel in 0..<channels {
                let wetIndex = frame * wetChannelCount + channel
                let dryIndex = frame * dryChannelCount + channel
                wetData[wetIndex] = dryData[dryIndex] * (1 - wetMix) + wetData[wetIndex] * wetMix
            }
        }
        return max(0, remainingFrames - frames)
    }
}
