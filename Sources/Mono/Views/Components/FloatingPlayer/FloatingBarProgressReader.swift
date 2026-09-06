import SwiftUI

/// Playback ticks invalidate only the progress-driven content inside this reader.
struct FloatingBarProgressReader<Content: View>: View {
    var progressOverride: Double? = nil
    @ViewBuilder var content: (Double, Double, Double) -> Content

    @ObservedObject private var playbackTime = PlaybackTimePublisher.shared

    init(
        progressOverride: Double? = nil,
        @ViewBuilder content: @escaping (Double, Double, Double) -> Content
    ) {
        self.progressOverride = progressOverride
        self.content = content
    }

    private var progress: Double {
        if let progressOverride { return progressOverride }
        guard playbackTime.duration.isFinite,
              playbackTime.duration > 0,
              playbackTime.currentTime.isFinite else { return 0 }
        return min(max(playbackTime.currentTime / playbackTime.duration, 0), 1)
    }

    var body: some View {
        content(progress, playbackTime.currentTime, playbackTime.duration)
    }
}
