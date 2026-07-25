import SwiftUI

/// 带轻微浮动/呼吸光晕动画的 App Logo，跟随品牌风格设置换肤；
/// 尊重系统"减弱动态效果"并在不需要动画时暂停 TimelineView。
struct AnimatedLogoView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var settings = SettingsManager.shared

    let size: CGFloat
    var animated: Bool = true

    private var shouldAnimate: Bool {
        animated && !reduceMotion
    }

    private var glowColor: Color {
        Color(hex: settings.appBrandStyle.logoGlowColor(for: settings.appBrandAppearance))
    }

    private var glowOpacityMultiplier: CGFloat {
        settings.appBrandAppearance == .dark ? 0.72 : 1
    }

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(paused: !shouldAnimate)) { timeline in
            let time = shouldAnimate ? timeline.date.timeIntervalSinceReferenceDate : 0
            let bobOffset = shouldAnimate ? CGFloat(sin(time * 1.5)) * size * 0.02 : 0
            let squash = shouldAnimate ? 1 + CGFloat(sin(time * 1.5 + 0.4)) * 0.012 : 1
            let glowOpacity = shouldAnimate ? 0.16 + CGFloat(sin(time * 1.2)) * 0.04 : 0.16

            ZStack {
                Circle()
                    .fill(glowColor.opacity(Double(glowOpacity * glowOpacityMultiplier)))
                    .frame(width: size * 0.92, height: size * 0.92)
                    .blur(radius: size * 0.1)
                    .scaleEffect(squash)

                Image(settings.appLogoAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: size * 0.06, x: 0, y: size * 0.035)
                    .scaleEffect(x: 1 - (squash - 1) * 0.45, y: squash)
                    .offset(y: bobOffset)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AnimatedLogoView(size: 220)
    }
}
