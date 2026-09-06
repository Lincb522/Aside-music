import SwiftUI

/// Keeps lyric-line updates inside the text that displays them.
struct FloatingBarLyricReader<Content: View>: View {
    @State private var lineText = FloatingBarPlaybackModel.shared.lyricLineText
    private let content: (String?) -> Content

    init(@ViewBuilder content: @escaping (String?) -> Content) {
        self.content = content
    }

    var body: some View {
        content(lineText)
            .onReceive(FloatingBarPlaybackModel.shared.$lyricLineText.removeDuplicates()) { text in
                lineText = text
            }
    }
}
