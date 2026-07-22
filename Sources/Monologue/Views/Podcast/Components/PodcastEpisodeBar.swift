import SwiftUI

struct PodcastEpisodeBar: View {
    let currentIndex: Int
    let currentEpisodeNumber: Int
    let totalCount: Int

    private var isAside: Bool {
        !ThemedPageStyle.isActive
    }

    private var progress: CGFloat {
        totalCount > 1
            ? CGFloat(currentIndex) / CGFloat(totalCount - 1)
            : 0.5
    }

    private var dotColor: Color {
        isAside ? .monologueAccent : .monologueAccentRed
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<40, id: \.self) { i in
                            let isMajor = i % 5 == 0
                            Rectangle()
                                .fill(Color.monologueTextSecondary.opacity(isAside ? (isMajor ? 0.32 : 0.12) : (isMajor ? 0.4 : 0.15)))
                                .frame(width: 1, height: isMajor ? 16 : 8)
                            if i < 39 { Spacer() }
                        }
                    }

                    Circle()
                        .fill(dotColor)
                        .frame(width: 9, height: 9)
                        .shadow(color: dotColor.opacity(0.5), radius: 4)
                        .offset(x: progress * (geo.size.width - 9))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentIndex)
                }
                .frame(height: 16)
            }
            .frame(height: 16)

            Text(String(format: String(localized: "podcast_episode_indicator"), currentEpisodeNumber, totalCount))
                .font(.system(size: isAside ? 10.5 : 11, weight: .medium, design: .monospaced))
                .foregroundColor(.monologueTextSecondary.opacity(isAside ? 0.85 : 1))
        }
    }
}
