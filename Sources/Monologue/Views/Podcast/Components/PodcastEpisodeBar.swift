import SwiftUI

struct PodcastEpisodeBar: View {
    let currentIndex: Int
    let currentEpisodeNumber: Int
    let totalCount: Int

    private var progress: CGFloat {
        totalCount > 1
            ? CGFloat(currentIndex) / CGFloat(totalCount - 1)
            : 0.5
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<40, id: \.self) { i in
                            let isMajor = i % 5 == 0
                            Rectangle()
                                .fill(Color.monologueTextSecondary.opacity(isMajor ? 0.4 : 0.15))
                                .frame(width: 1, height: isMajor ? 16 : 8)
                            if i < 39 { Spacer() }
                        }
                    }

                    Circle()
                        .fill(Color.monologueAccentRed)
                        .frame(width: 10, height: 10)
                        .shadow(color: .monologueAccentRed.opacity(0.5), radius: 4)
                        .offset(x: progress * (geo.size.width - 10))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentIndex)
                }
                .frame(height: 16)
            }
            .frame(height: 16)

            Text(String(format: String(localized: "podcast_episode_indicator"), currentEpisodeNumber, totalCount))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.monologueTextSecondary)
        }
    }
}
