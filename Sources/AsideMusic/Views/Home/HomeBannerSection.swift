import SwiftUI

/// Banner — 全宽圆角卡片，paging 滚动 + scrollTransition 视差
struct HomeBannerSection: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(banners) { banner in
                    Button(action: { onTap(banner) }) {
                        CachedAsyncImage(url: banner.imageUrl) {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.asideSeparator)
                        }
                        .aspectRatio(16/7, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
                    .containerRelativeFrame(.horizontal)
                    .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.93)
                            .opacity(phase.isIdentity ? 1 : 0.5)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
    }
}
