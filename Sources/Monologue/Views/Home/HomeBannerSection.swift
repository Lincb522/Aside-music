import SwiftUI

/// Banner — 采用 TabView 分页滑动样式，参考博客/播客页设计
struct HomeBannerSection: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var bannerIndex: Int = 0
    private let timer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()
    private var bannerRadius: CGFloat {
        if NeumorphicStyle.isActive { return DeviceLayout.isPad ? 26 : 22 }
        if MujiStyle.isActive { return DeviceLayout.isPad ? 22 : 16 }
        return DeviceLayout.isPad ? 22 : 16
    }

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $bannerIndex) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                    Button(action: { onTap(banner) }) {
                        CachedAsyncImage(url: banner.imageUrl) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(height: DeviceLayout.bannerHeight)
                        .compositingGroup()
                        .clipShape(RoundedRectangle(cornerRadius: bannerRadius, style: .continuous))
                        .overlay {
                            if NeumorphicStyle.isActive {
                                RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                    .stroke(NeumorphicStyle.lightShadow(colorScheme, intensity: 0.66), lineWidth: 1)
                            } else if MujiStyle.isActive {
                                RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                    .stroke(MujiStyle.hairline.opacity(0.56), lineWidth: 0.7)
                            }
                        }
                        .shadow(
                            color: NeumorphicStyle.isActive ? NeumorphicStyle.darkShadow(colorScheme, intensity: 0.5) : .clear,
                            radius: NeumorphicStyle.isActive ? 14 : 0,
                            x: NeumorphicStyle.isActive ? 7 : 0,
                            y: NeumorphicStyle.isActive ? 9 : 0
                        )
                        .themeRenderSurfaceLayer(isEnabled: NeumorphicStyle.isActive)
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
                                  ? activeDotColor
                                  : Color.monologueTextSecondary.opacity(0.25))
                            .frame(width: index == bannerIndex ? 16 : 6, height: 6)
                            .animation(.spring(duration: 0.3), value: bannerIndex)
                    }
                }
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private var activeDotColor: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monologueTextPrimary.opacity(0.8)
    }
}
