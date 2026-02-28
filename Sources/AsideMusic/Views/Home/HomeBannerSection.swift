import SwiftUI

/// Banner — 采用 TabView 分页滑动样式，参考博客/播客页设计
struct HomeBannerSection: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var bannerIndex: Int = 0
    private let timer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $bannerIndex) {
            ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                Button(action: { onTap(banner) }) {
                    CachedAsyncImage(url: banner.imageUrl) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.asideGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 140)
        .onReceive(timer) { _ in
            guard !banners.isEmpty else { return }
            withAnimation {
                bannerIndex = (bannerIndex + 1) % banners.count
            }
        }
    }
}
