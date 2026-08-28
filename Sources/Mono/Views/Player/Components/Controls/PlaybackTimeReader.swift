import SwiftUI

/// Restricts playback-clock invalidation to the subtree that renders progress.
struct PlaybackTimeReader<Content: View>: View {
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    private let content: (Double, Double) -> Content

    init(@ViewBuilder content: @escaping (Double, Double) -> Content) {
        self.content = content
    }

    var body: some View {
        content(timePublisher.currentTime, timePublisher.duration)
    }
}
