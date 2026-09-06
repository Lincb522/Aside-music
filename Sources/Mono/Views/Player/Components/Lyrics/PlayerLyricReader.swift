import SwiftUI

/// Keeps lyric-line updates inside the subtree that displays them.
struct PlayerLyricReader<Content: View>: View {
    @ObservedObject private var lyrics = LyricViewModel.shared
    private let content: (LyricViewModel) -> Content

    init(@ViewBuilder content: @escaping (LyricViewModel) -> Content) {
        self.content = content
    }

    var body: some View {
        content(lyrics)
    }
}
