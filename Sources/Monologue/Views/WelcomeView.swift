import SwiftUI

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    @Binding var isPresented: Bool
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false

    @State private var backgroundOpacity = 0.0
    @State private var backgroundScale: CGFloat = 1.018
    @State private var plateOpacity = 0.0
    @State private var plateScale: CGFloat = 0.82
    @State private var plateOffset: CGFloat = 28
    @State private var titleOpacity = 0.0
    @State private var titleOffset: CGFloat = 18
    @State private var subtitleOpacity = 0.0
    @State private var subtitleOffset: CGFloat = 26
    @State private var accentOpacity = 0.0
    @State private var accentScaleX: CGFloat = 0.28
    @State private var footerOpacity = 0.0
    @State private var sceneOffset: CGFloat = 0
    @State private var sceneScale: CGFloat = 1
    @State private var isDismissing = false
    @State private var animationTask: Task<Void, Never>?

    private enum Timing {
        static let preloadStartDelay: TimeInterval = 0.08
        static let titleDelay: TimeInterval = 0.14
        static let subtitleDelay: TimeInterval = 0.26
        static let footerDelay: TimeInterval = 0.42
        static let dismissDelay: TimeInterval = 2.05
    }

    private var plateSize: CGFloat {
        DeviceLayout.isPad ? 198 : 160
    }

    private var logoSize: CGFloat {
        DeviceLayout.isPad ? 122 : 100
    }

    private var heroSpring: Animation {
        .spring(response: reduceMotion ? 0.24 : 0.54, dampingFraction: 0.82)
    }

    private var secondarySpring: Animation {
        .spring(response: reduceMotion ? 0.2 : 0.36, dampingFraction: 0.88)
    }

    private var fadeAnimation: Animation {
        .easeOut(duration: reduceMotion ? 0.16 : 0.3)
    }

    private var dismissAnimation: Animation {
        .easeInOut(duration: dismissDuration)
    }

    private var dismissDuration: TimeInterval {
        reduceMotion ? 0.18 : 0.42
    }

    var body: some View {
        ZStack {
            welcomeBaseColor
                .ignoresSafeArea()

            welcomeBackdrop
                .opacity(MangaStyle.isActive && !isDismissing ? 1 : backgroundOpacity)
                .scaleEffect(backgroundScale)

            welcomeDecor
                .opacity(backgroundOpacity)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                heroSection

                Spacer()

                Text("© 2026 ZIJIU STUDIO")
                    .font(footerFont)
                    .foregroundColor(footerColor)
                    .padding(.bottom, DeviceLayout.isPad ? 48 : 36)
                    .opacity(footerOpacity)
            }
            .padding(.horizontal, 28)
        }
        .scaleEffect(sceneScale)
        .offset(y: sceneOffset)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    private var welcomeBaseColor: Color {
        if MangaStyle.isActive { return MangaStyle.paper }
        if NeumorphicStyle.isActive { return NeumorphicStyle.base }
        if MujiStyle.isActive { return MujiStyle.paper }
        return colorScheme == .dark ? Color(hex: "03050D") : Color(hex: "F7FAFA")
    }

    @ViewBuilder
    private var welcomeBackdrop: some View {
        if MangaStyle.isActive {
            MangaWelcomeBackdrop()
        } else if NeumorphicStyle.isActive {
            NeumorphicWelcomeBackdrop()
        } else if MujiStyle.isActive {
            MujiWelcomeBackdrop()
        } else {
            DefaultWelcomeBackdrop()
        }
    }

    @ViewBuilder
    private var welcomeDecor: some View {
        if MangaStyle.isActive {
            MangaWelcomeDecor()
                .scaleEffect(plateScale)
        } else if NeumorphicStyle.isActive {
            NeumorphicWelcomeDecor()
                .opacity(accentOpacity)
                .scaleEffect(plateScale)
        } else if MujiStyle.isActive {
            MujiWelcomeDecor()
                .offset(y: plateOffset * 0.18)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if MangaStyle.isActive {
            mangaHeroSection
        } else if NeumorphicStyle.isActive {
            neumorphicHeroSection
        } else if MujiStyle.isActive {
            mujiHeroSection
        } else {
            defaultHeroSection
        }
    }

    private var defaultHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 34 : 28) {
            ZStack {
                DefaultWelcomeLogoStage(
                    accent: defaultAccent,
                    accentOpacity: accentOpacity,
                    isAnimating: !isDismissing && !reduceMotion
                )
                .frame(width: plateSize * 2.1, height: plateSize * 1.56)

                welcomeLogoImage(size: logoSize * 1.1)
                    .scaleEffect(plateScale > 0.96 ? 1 : 0.9)
                    .offset(y: -plateSize * 0.12)
            }
            .frame(width: plateSize * 2.12, height: plateSize * 1.58)
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            defaultTitleBlock
        }
    }

    private var mujiHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 28 : 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(MujiStyle.hairline.opacity(colorScheme == .dark ? 0.24 : 0.22))
                    .frame(width: plateSize * 0.86, height: plateSize * 0.94)
                    .offset(x: 10, y: 12)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MujiStyle.surfaceRaised)
                    .overlay(MujiPaperTexture(opacity: colorScheme == .dark ? 0.08 : 0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(MujiStyle.hairline.opacity(colorScheme == .dark ? 0.58 : 0.72), lineWidth: 0.7)
                    }

                VStack(spacing: 12) {
                    welcomeLogoImage(size: logoSize)

                    Rectangle()
                        .fill(MujiStyle.clay.opacity(0.76))
                        .frame(width: DeviceLayout.isPad ? 72 : 58, height: 1)
                        .scaleEffect(x: accentScaleX, y: 1)
                        .opacity(accentOpacity)
                }
            }
            .frame(width: plateSize, height: plateSize)
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            mujiTitleBlock
        }
    }

    private var mangaHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 26 : 20) {
            ZStack {
                welcomeLogoImage(size: logoSize * 1.42)
                    .scaleEffect(plateScale > 0.96 ? 1 : 0.96)

                MangaWelcomeFloatingMark(kind: .star, tint: MangaStyle.labelYellow, size: DeviceLayout.isPad ? 38 : 32)
                    .offset(x: -plateSize * 0.47, y: -plateSize * 0.36)
                    .rotationEffect(.degrees(-12))
                    .scaleEffect(accentScaleX)
                    .opacity(accentOpacity)

                MangaWelcomeFloatingMark(kind: .heart, tint: MangaStyle.accentPink, size: DeviceLayout.isPad ? 35 : 29)
                    .offset(x: plateSize * 0.45, y: -plateSize * 0.22)
                    .rotationEffect(.degrees(10))
                    .scaleEffect(accentScaleX)
                    .opacity(accentOpacity)

                MangaWelcomeFloatingMark(kind: .heart, tint: MangaStyle.bubblePink, size: DeviceLayout.isPad ? 25 : 21)
                    .offset(x: -plateSize * 0.38, y: plateSize * 0.32)
                    .rotationEffect(.degrees(13))
                    .scaleEffect(accentScaleX)
                    .opacity(accentOpacity)

                MangaWelcomeFloatingMark(kind: .star, tint: MangaStyle.decoBlue, size: DeviceLayout.isPad ? 27 : 23)
                    .offset(x: plateSize * 0.42, y: plateSize * 0.35)
                    .rotationEffect(.degrees(15))
                    .scaleEffect(accentScaleX)
                    .opacity(accentOpacity)
            }
            .frame(width: plateSize * 1.22, height: plateSize * 1.16)
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            mangaTitleBlock
        }
    }

    private var neumorphicHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 30 : 24) {
            ZStack {
                RoundedRectangle(cornerRadius: plateSize * 0.22, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: plateSize * 0.98, height: plateSize * 0.98)
                    .background(NeumorphicSurfaceBackground(cornerRadius: plateSize * 0.22, elevated: true))

                RoundedRectangle(cornerRadius: plateSize * 0.18, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: plateSize * 0.68, height: plateSize * 0.68)
                    .background(NeumorphicSurfaceBackground(cornerRadius: plateSize * 0.18, elevated: false, pressed: true, lightweight: true))
                    .opacity(0.92)

                welcomeLogoImage(size: logoSize)
            }
            .frame(width: plateSize, height: plateSize)
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            neumorphicTitleBlock
        }
    }

    private var defaultTitleBlock: some View {
        VStack(spacing: 12) {
            Text("Monologue")
                .font(.system(size: DeviceLayout.isPad ? 40 : 32, weight: .semibold, design: .rounded))
                .foregroundStyle(defaultTitleStyle)
                .tracking(0.4)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            Text(LocalizedStringKey("welcome_slogan"))
                .font(.system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .tracking(DeviceLayout.isPad ? 1.8 : 1.35)
                .multilineTextAlignment(.center)
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)

            DefaultWelcomeConstellationDivider(
                accent: defaultAccent,
                isAnimating: !isDismissing && !reduceMotion
            )
            .frame(width: DeviceLayout.isPad ? 132 : 112, height: 22)
            .scaleEffect(x: accentScaleX, y: 1, anchor: .center)
            .opacity(accentOpacity)
            .padding(.top, 2)
        }
    }

    private var mujiTitleBlock: some View {
        VStack(spacing: 11) {
            Text("Monologue")
                .font(MujiStyle.titleFont(DeviceLayout.isPad ? 38 : 31, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .tracking(0.7)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            Text(LocalizedStringKey("welcome_slogan"))
                .font(MujiStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .regular))
                .foregroundStyle(MujiStyle.inkSoft)
                .tracking(1.2)
                .multilineTextAlignment(.center)
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(MujiStyle.hairline.opacity(0.72))
                    .frame(width: DeviceLayout.isPad ? 72 : 56, height: 0.7)
                Circle()
                    .fill(MujiStyle.clay)
                    .frame(width: 5, height: 5)
                Rectangle()
                    .fill(MujiStyle.hairline.opacity(0.72))
                    .frame(width: DeviceLayout.isPad ? 72 : 56, height: 0.7)
            }
            .scaleEffect(x: accentScaleX, y: 1)
            .opacity(accentOpacity)
            .padding(.top, 2)
        }
    }

    private var mangaTitleBlock: some View {
        VStack(spacing: 11) {
            Text("MONOLOGUE")
                .font(MangaStyle.titleFont(DeviceLayout.isPad ? 38 : 31, weight: .black))
                .foregroundStyle(MangaStyle.ink)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            Text(LocalizedStringKey("welcome_slogan"))
                .font(MangaStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .bold))
                .foregroundStyle(MangaStyle.inkSub)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)

            HStack(spacing: 10) {
                MangaWelcomeFloatingMark(kind: .heart, tint: MangaStyle.accentPink, size: 16)
                MangaWelcomeFloatingMark(kind: .star, tint: MangaStyle.labelYellow, size: 18)
                MangaWelcomeFloatingMark(kind: .heart, tint: MangaStyle.bubblePink, size: 14)
            }
            .scaleEffect(accentScaleX)
            .opacity(accentOpacity)
            .padding(.top, 2)
        }
    }

    private var neumorphicTitleBlock: some View {
        VStack(spacing: 12) {
            Text("Monologue")
                .font(NeumorphicStyle.titleFont(DeviceLayout.isPad ? 38 : 31, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            Text(LocalizedStringKey("welcome_slogan"))
                .font(NeumorphicStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .medium))
                .foregroundStyle(NeumorphicStyle.inkSoft)
                .tracking(1.0)
                .multilineTextAlignment(.center)
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)

            HStack(spacing: 8) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Capsule()
                        .fill(index == 1 ? NeumorphicStyle.accent : NeumorphicStyle.separator.opacity(0.65))
                        .frame(width: index == 1 ? 28 : 16, height: 5)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 5, elevated: false, pressed: true, lightweight: true))
                }
            }
            .scaleEffect(x: accentScaleX, y: 1)
            .opacity(accentOpacity)
            .padding(.top, 2)
        }
    }

    private func welcomeLogoImage(size: CGFloat) -> some View {
        let appearance = welcomeLogoAppearance
        let glowColor = Color(hex: settings.appBrandStyle.logoGlowColor(for: appearance))
        let glowOpacity = appearance == .dark ? 0.24 : 0.14

        return Image(settings.appBrandStyle.logoAssetName(for: appearance))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: glowColor.opacity(glowOpacity), radius: size * 0.18, x: 0, y: 0)
            .shadow(color: logoShadowColor, radius: size * 0.08, x: 0, y: size * 0.04)
    }

    private var welcomeLogoAppearance: AppBrandAppearance {
        colorScheme == .dark ? .dark : .light
    }

    private var defaultAccent: Color {
        colorScheme == .dark ? Color(hex: "DDE3EA") : Color(hex: "8C949D")
    }

    private var defaultTitleStyle: LinearGradient {
        LinearGradient(
            colors: [
                Color.monologueTextPrimary,
                Color.monologueTextPrimary.opacity(colorScheme == .dark ? 0.84 : 0.7),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var logoShadowColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(colorScheme == .dark ? 0.42 : 0.22) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.darkShadow(colorScheme, intensity: colorScheme == .dark ? 0.64 : 0.4) }
        if MujiStyle.isActive { return Color.black.opacity(colorScheme == .dark ? 0.26 : 0.09) }
        return Color.black.opacity(colorScheme == .dark ? 0.28 : 0.16)
    }

    private var footerFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(10, weight: .black) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(10, weight: .medium) }
        if MujiStyle.isActive { return MujiStyle.labelFont(10, weight: .regular) }
        return .system(size: 10, weight: .medium, design: .monospaced)
    }

    private var footerColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkMuted.opacity(0.78) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.inkMuted.opacity(0.72) }
        return .monologueTextSecondary.opacity(0.62)
    }

    private func startAnimation() {
        animationTask?.cancel()
        isDismissing = false

        backgroundOpacity = 0
        backgroundScale = reduceMotion ? 1 : 1.018
        plateOpacity = 0
        plateScale = MangaStyle.isActive ? 0.78 : (NeumorphicStyle.isActive ? 0.84 : 0.82)
        plateOffset = MujiStyle.isActive ? 18 : (NeumorphicStyle.isActive ? 22 : 28)
        titleOpacity = 0
        titleOffset = 18
        subtitleOpacity = 0
        subtitleOffset = 26
        accentOpacity = 0
        accentScaleX = 0.28
        footerOpacity = 0
        sceneOffset = 0
        sceneScale = 1

        withAnimation(fadeAnimation) {
            backgroundOpacity = 1
            backgroundScale = 1
        }

        withAnimation(heroSpring) {
            plateOpacity = 1
            plateScale = 1
            plateOffset = 0
        }

        let isLoggedIn = isAppLoggedIn
        Task(priority: .utility) {
            try? await sleep(seconds: Timing.preloadStartDelay)
            await loadDataInBackground(isLoggedIn: isLoggedIn)
        }

        animationTask = Task {
            do {
                try await sleep(seconds: Timing.titleDelay)
                await MainActor.run {
                    withAnimation(secondarySpring) {
                        titleOpacity = 1
                        titleOffset = 0
                    }
                }

                try await sleep(seconds: Timing.subtitleDelay - Timing.titleDelay)
                await MainActor.run {
                    withAnimation(secondarySpring) {
                        subtitleOpacity = 1
                        subtitleOffset = 0
                        accentOpacity = 1
                        accentScaleX = 1
                    }
                }

                try await sleep(seconds: Timing.footerDelay - Timing.subtitleDelay)
                await MainActor.run {
                    withAnimation(fadeAnimation) {
                        footerOpacity = 1
                    }
                }

                try await sleep(seconds: Timing.dismissDelay - Timing.footerDelay)
                await MainActor.run {
                    dismissWelcome()
                }
            } catch {
                return
            }
        }
    }

    private func loadDataInBackground(isLoggedIn: Bool) async {
        await OptimizedCacheManager.shared.quickPreload()

        guard isLoggedIn, OnlineAccessManager.shared.hasStoredToken else { return }

        do {
            _ = try await APIService.shared.fetchLoginStatus().async()
        } catch {
            AppLogger.warning("登录状态检查失败: \(error)")
        }

        let needsRefresh = await MainActor.run {
            GlobalRefreshManager.shared.checkDailyRefreshNeeded()
        }
        await MainActor.run {
            GlobalRefreshManager.shared.refreshHomePublisher.send(needsRefresh)
            GlobalRefreshManager.shared.refreshLibraryPublisher.send(false)
            GlobalRefreshManager.shared.refreshProfilePublisher.send(false)
        }
    }

    private func dismissWelcome() {
        guard !isDismissing else { return }
        isDismissing = true

        withAnimation(dismissAnimation, completionCriteria: .logicallyComplete) {
            sceneOffset = -(ScreenInfo.mainScreenSize.height + DeviceLayout.safeAreaTop + DeviceLayout.safeAreaBottom + 80)
            sceneScale = reduceMotion ? 1 : 1.015
            backgroundScale = 1.03
            plateScale = MangaStyle.isActive ? 0.98 : (NeumorphicStyle.isActive ? 0.99 : 1.02)
            plateOffset = -18
            titleOffset = -14
            subtitleOffset = -12
        } completion: {
            isPresented = false
        }
    }

    private func sleep(seconds: TimeInterval) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

private struct DefaultWelcomeBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let mountainHeight = max(proxy.size.height * 0.68, DeviceLayout.isPad ? 600 : 520)

            ZStack(alignment: .bottom) {
                defaultSky

                ParallaxMountainHeader(height: mountainHeight)
                    .frame(height: mountainHeight)
                    .scaleEffect(x: 1.24, y: 1.16, anchor: .bottom)
                    .offset(y: DeviceLayout.isPad ? 58 : 48)
                    .opacity(colorScheme == .dark ? 0.96 : 0.84)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.34),
                                .init(color: .white.opacity(0.76), location: 0.48),
                                .init(color: .white, location: 0.62),
                                .init(color: .white, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.clear, Color(hex: "03050D").opacity(0.06), Color(hex: "03050D").opacity(0.34)]
                        : [Color.clear, Color(hex: "F7FAFA").opacity(0.1), Color(hex: "F7FAFA").opacity(0.46)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.025 : 0.24),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.68
                )
                .blendMode(colorScheme == .dark ? .plusLighter : .normal)
            }
        }
        .ignoresSafeArea()
    }

    private var defaultSky: some View {
        LinearGradient(
            stops: colorScheme == .dark
                ? [
                    .init(color: Color(hex: "03050D"), location: 0),
                    .init(color: Color(hex: "08102A"), location: 0.42),
                    .init(color: Color(hex: "111836"), location: 0.74),
                    .init(color: Color(hex: "05070D"), location: 1),
                ]
                : [
                    .init(color: Color(hex: "B9CAD6"), location: 0),
                    .init(color: Color(hex: "D7E1E8"), location: 0.42),
                    .init(color: Color(hex: "EDF2F4"), location: 0.78),
                    .init(color: Color(hex: "F7FAFA"), location: 1),
                ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct DefaultWelcomeLogoStage: View {
    var accent: Color
    var accentOpacity: Double
    var isAnimating: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimating)) { timeline in
            let time = isAnimating ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.44)
                let glowRadius = min(size.width, size.height) * 0.42
                let neutralGlow = colorScheme == .dark ? Color(hex: "DDE3EA") : Color.white
                let softInk = colorScheme == .dark ? Color(hex: "A9B2BE") : Color(hex: "AEB8C1")

                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius * 0.82, width: glowRadius * 2, height: glowRadius * 1.64)),
                    with: .radialGradient(
                        Gradient(colors: [
                            neutralGlow.opacity(colorScheme == .dark ? 0.16 : 0.62),
                            softInk.opacity((colorScheme == .dark ? 0.08 : 0.12) * max(0.35, accentOpacity)),
                            Color.clear,
                        ]),
                        center: center,
                        startRadius: 2,
                        endRadius: glowRadius
                    )
                )

                let breath = CGFloat((sin(time * 0.22) + 1) / 2)
                let groundWidth = size.width * (0.28 + breath * 0.025)
                let groundHeight = size.height * 0.035
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - groundWidth / 2, y: center.y + glowRadius * 0.48, width: groundWidth, height: groundHeight)),
                    with: .color(softInk.opacity(colorScheme == .dark ? 0.09 : 0.12))
                )
            }
        }
    }
}

private struct DefaultWelcomeConstellationDivider: View {
    var accent: Color
    var isAnimating: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimating)) { _ in
            Canvas { context, size in
                let baseline = size.height * 0.5
                var line = Path()
                line.move(to: CGPoint(x: size.width * 0.06, y: baseline))
                line.addLine(to: CGPoint(x: size.width * 0.94, y: baseline))
                context.stroke(
                    line,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.clear,
                            Color.monologueTextSecondary.opacity(colorScheme == .dark ? 0.22 : 0.14),
                            accent.opacity(colorScheme == .dark ? 0.16 : 0.11),
                            Color.clear,
                        ]),
                        startPoint: CGPoint(x: 0, y: baseline),
                        endPoint: CGPoint(x: size.width, y: baseline)
                    ),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
            }
        }
    }
}

private struct MujiWelcomeBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            MujiRootBackdrop()

            VStack {
                Rectangle()
                    .fill(MujiStyle.hairline.opacity(colorScheme == .dark ? 0.2 : 0.26))
                    .frame(height: 0.7)
                    .padding(.top, DeviceLayout.isPad ? 140 : 104)
                Spacer()
                Rectangle()
                    .fill(MujiStyle.hairline.opacity(colorScheme == .dark ? 0.16 : 0.2))
                    .frame(height: 0.7)
                    .padding(.bottom, DeviceLayout.isPad ? 142 : 112)
            }
            .padding(.horizontal, DeviceLayout.isPad ? 92 : 36)
        }
        .ignoresSafeArea()
    }
}

private struct MujiWelcomeDecor: View {
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(0 ..< 4, id: \.self) { index in
                    Rectangle()
                        .fill((index == 0 ? MujiStyle.clay : MujiStyle.hairline).opacity(index == 0 ? 0.44 : 0.28))
                        .frame(width: CGFloat(88 - index * 12), height: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, DeviceLayout.isPad ? 96 : 38)
            .padding(.top, DeviceLayout.isPad ? 176 : 136)

            VStack(alignment: .trailing, spacing: 9) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Rectangle()
                        .fill((index == 1 ? MujiStyle.tea : MujiStyle.hairline).opacity(index == 1 ? 0.34 : 0.24))
                        .frame(width: CGFloat(54 + index * 18), height: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, DeviceLayout.isPad ? 104 : 42)
            .padding(.bottom, DeviceLayout.isPad ? 176 : 136)
        }
        .ignoresSafeArea()
    }
}

private struct NeumorphicWelcomeBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeRenderBackdrop(theme: .neumorphic)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.white.opacity(0.045), .clear]
                        : [Color.white.opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: DeviceLayout.isPad ? 360 : 280)

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()

                NeumorphicWelcomeFloor()
                    .frame(height: DeviceLayout.isPad ? 260 : 210)
                    .opacity(colorScheme == .dark ? 0.52 : 0.74)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct NeumorphicWelcomeDecor: View {
    var body: some View {
        ZStack {
            NeumorphicWelcomeSoftPill(width: DeviceLayout.isPad ? 126 : 96, height: 18, tint: NeumorphicStyle.accent.opacity(0.34))
                .rotationEffect(.degrees(-10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, DeviceLayout.isPad ? 100 : 34)
                .padding(.top, DeviceLayout.isPad ? 170 : 128)

            NeumorphicWelcomeSoftPill(width: DeviceLayout.isPad ? 92 : 72, height: 16, tint: NeumorphicStyle.warm.opacity(0.3))
                .rotationEffect(.degrees(12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, DeviceLayout.isPad ? 112 : 36)
                .padding(.top, DeviceLayout.isPad ? 214 : 168)

            NeumorphicWelcomeSoftPill(width: DeviceLayout.isPad ? 116 : 88, height: 18, tint: NeumorphicStyle.sage.opacity(0.28))
                .rotationEffect(.degrees(9))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, DeviceLayout.isPad ? 116 : 42)
                .padding(.bottom, DeviceLayout.isPad ? 190 : 146)
        }
        .ignoresSafeArea()
    }
}

private struct NeumorphicWelcomeSoftPill: View {
    let width: CGFloat
    let height: CGFloat
    let tint: Color

    var body: some View {
        Capsule()
            .fill(tint)
            .frame(width: width, height: height)
            .background(NeumorphicSurfaceBackground(cornerRadius: height / 2, elevated: false))
    }
}

private struct NeumorphicWelcomeFloor: View {
    var body: some View {
        Canvas { context, size in
            let shadow = NeumorphicStyle.separator.opacity(0.34)
            let highlight = Color.white.opacity(0.28)

            for index in 0 ..< 5 {
                let y = size.height * (0.18 + CGFloat(index) * 0.14)
                var path = Path()
                path.move(to: CGPoint(x: -20, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width + 20, y: y + CGFloat(index % 2 == 0 ? 18 : -14)),
                    control1: CGPoint(x: size.width * 0.28, y: y - 18),
                    control2: CGPoint(x: size.width * 0.72, y: y + 22)
                )
                context.stroke(path, with: .color(shadow.opacity(0.5 - Double(index) * 0.06)), lineWidth: 1.2)

                var hi = path
                hi = hi.offsetBy(dx: 0, dy: -2)
                context.stroke(hi, with: .color(highlight.opacity(0.26)), lineWidth: 0.7)
            }
        }
    }
}

private struct MangaWelcomeBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [MangaStyle.paper, MangaStyle.paperWarm, MangaStyle.paperCool.opacity(0.9)]
                : [MangaStyle.surface, MangaStyle.paper, MangaStyle.paperWarm],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct MangaWelcomeDecor: View {
    var body: some View {
        ZStack {
            MangaWelcomeFloatingMark(kind: .heart, tint: MangaStyle.bubblePink.opacity(0.78), size: 34, strokeOpacity: 0.18)
                .rotationEffect(.degrees(-14))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, DeviceLayout.isPad ? 108 : 34)
                .padding(.top, DeviceLayout.isPad ? 150 : 116)

            MangaWelcomeFloatingMark(kind: .star, tint: MangaStyle.labelYellow.opacity(0.86), size: 30, strokeOpacity: 0.2)
                .rotationEffect(.degrees(16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, DeviceLayout.isPad ? 118 : 42)
                .padding(.top, DeviceLayout.isPad ? 184 : 146)

            MangaWelcomeFloatingMark(kind: .heart, tint: MangaStyle.accentPink.opacity(0.64), size: 24, strokeOpacity: 0.18)
                .rotationEffect(.degrees(10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, DeviceLayout.isPad ? 120 : 44)
                .padding(.bottom, DeviceLayout.isPad ? 164 : 126)
        }
        .ignoresSafeArea()
    }
}

private struct MangaWelcomeFloatingMark: View {
    var kind: MangaSectionMarkKind
    var tint: Color
    var size: CGFloat
    var strokeOpacity: Double = 1

    var body: some View {
        Group {
            if kind == .heart {
                MangaRoundedHeartShape()
                    .fill(tint)
            } else {
                MangaRoundedStarShape()
                    .fill(tint)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if kind == .heart {
                MangaRoundedHeartShape()
                    .stroke(MangaStyle.strokeInk.opacity(strokeOpacity), lineWidth: max(1, size * 0.055))
            } else {
                MangaRoundedStarShape()
                    .stroke(MangaStyle.strokeInk.opacity(strokeOpacity), lineWidth: max(1, size * 0.055))
            }
        }
    }
}
