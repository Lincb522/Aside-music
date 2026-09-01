import SwiftUI

/// Banner — 采用 TabView 分页滑动样式，参考博客/播客页设计
struct HomeBannerSection: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var bannerIndex: Int = 0
    @State private var isVisible = false
    private let timer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()
    private var bannerRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 14 }
        if NeumorphicStyle.isActive { return DeviceLayout.usesExpandedLayout ? 30 : 26 }
        if MujiStyle.isActive { return DeviceLayout.usesExpandedLayout ? 26 : 20 }
        return DeviceLayout.usesExpandedLayout ? 28 : 22
    }
    private var sideInset: CGFloat {
        if MinimalWhiteStyle.isActive { return DeviceLayout.homeHorizontalPadding }
        return DeviceLayout.homeHorizontalPadding + (DeviceLayout.usesExpandedLayout ? 12 : 8)
    }

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $bannerIndex) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                    Button(action: { onTap(banner) }) {
                        HomeBannerArtwork(
                            url: banner.imageUrl,
                            cornerRadius: bannerRadius,
                            placeholder: {
                                RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                    .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint))
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: DeviceLayout.bannerHeight)
                        .background(
                            RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint))
                        )
                        .compositingGroup()
                        .clipShape(RoundedRectangle(cornerRadius: bannerRadius, style: .continuous))
                        .overlay {
                            if NeumorphicStyle.isActive {
                                RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                    .stroke(NeumorphicStyle.lightShadow(colorScheme, intensity: 0.66), lineWidth: 1)
                            } else if MujiStyle.isActive {
                                RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                    .stroke(MujiStyle.hairline.opacity(0.56), lineWidth: 0.7)
                            } else if MinimalWhiteStyle.isActive {
                                RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                    .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                            } else {
                                RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.38), lineWidth: 1.2)
                                RoundedRectangle(cornerRadius: bannerRadius, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                            }
                        }
                        .shadow(
                            color: NeumorphicStyle.isActive ? NeumorphicStyle.darkShadow(colorScheme, intensity: 0.5) : .clear,
                            radius: NeumorphicStyle.isActive ? 14 : 0,
                            x: NeumorphicStyle.isActive ? 7 : 0,
                            y: NeumorphicStyle.isActive ? 9 : 0
                        )
                        .themeRenderSurfaceLayer(isEnabled: NeumorphicStyle.isActive)
                        .padding(.horizontal, sideInset)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: DeviceLayout.bannerHeight + 32)
            .onReceive(timer) { _ in
                guard isVisible, !banners.isEmpty else { return }
                withAnimation {
                    bannerIndex = (bannerIndex + 1) % banners.count
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }

            if banners.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<banners.count, id: \.self) { index in
                        Capsule()
                            .fill(index == bannerIndex
                                  ? activeDotColor
                                  : Color.monoTextSecondary.opacity(MinimalWhiteStyle.isActive ? 0.18 : 0.25))
                            .frame(width: index == bannerIndex ? 16 : 6, height: 6)
                            .animation(.spring(duration: 0.3), value: bannerIndex)
                    }
                }
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private var activeDotColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink.opacity(0.7) }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monoTextPrimary.opacity(0.8)
    }
}

struct HomeBannerArtwork<Placeholder: View>: View {
    let url: URL?
    let cornerRadius: CGFloat
    let placeholder: Placeholder

    init(
        url: URL?,
        cornerRadius: CGFloat,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CachedAsyncImage(
                    url: url,
                    width: proxy.size.width,
                    height: proxy.size.height,
                    placeholder: {
                        placeholder
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    },
                    contentMode: .fill,
                    resizesArtworkURL: false
                )
                .blur(radius: 18)
                .scaleEffect(1.08)
                .opacity(0.34)
                .frame(width: proxy.size.width, height: proxy.size.height)

                CachedAsyncImage(
                    url: url,
                    width: proxy.size.width,
                    height: proxy.size.height,
                    placeholder: {
                        placeholder
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    },
                    contentMode: .fit,
                    resizesArtworkURL: false
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
