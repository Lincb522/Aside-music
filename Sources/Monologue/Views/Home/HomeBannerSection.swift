import SwiftUI

/// Banner — 采用 TabView 分页滑动样式，参考博客/播客页设计
struct HomeBannerSection: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var bannerIndex: Int = 0
    private let timer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $bannerIndex) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                    Button(action: { onTap(banner) }) {
                        CachedAsyncImage(url: banner.imageUrl) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.monologueGlassTint)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(height: DeviceLayout.bannerHeight)
                        .clipShape(RoundedRectangle(cornerRadius: DeviceLayout.isPad ? 22 : 16, style: .continuous))
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: DeviceLayout.bannerHeight + 20)
            .onReceive(timer) { _ in
                guard !banners.isEmpty else { return }
                withAnimation {
                    bannerIndex = (bannerIndex + 1) % banners.count
                }
            }

            if banners.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<banners.count, id: \.self) { index in
                        Capsule()
                            .fill(index == bannerIndex
                                  ? Color.monologueTextPrimary.opacity(0.8)
                                  : Color.monologueTextSecondary.opacity(0.25))
                            .frame(width: index == bannerIndex ? 16 : 6, height: 6)
                            .animation(.spring(duration: 0.3), value: bannerIndex)
                    }
                }
            }
        }
    }
}
