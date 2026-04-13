import SwiftUI

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    @Binding var isPresented: Bool
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false

    @State private var backgroundOpacity = 0.0
    @State private var backgroundScale: CGFloat = 0.92
    @State private var plateOpacity = 0.0
    @State private var plateScale: CGFloat = 0.84
    @State private var plateOffset: CGFloat = 24
    @State private var plateTilt: Double = -10
    @State private var titleOpacity = 0.0
    @State private var titleOffset: CGFloat = 18
    @State private var subtitleOpacity = 0.0
    @State private var subtitleOffset: CGFloat = 26
    @State private var accentOpacity = 0.0
    @State private var accentScaleX: CGFloat = 0.35
    @State private var footerOpacity = 0.0
    @State private var isDismissing = false
    @State private var animationTask: Task<Void, Never>?

    private enum Timing {
        static let preloadStartDelay: TimeInterval = 0.08
        static let titleDelay: TimeInterval = 0.12
        static let subtitleDelay: TimeInterval = 0.22
        static let footerDelay: TimeInterval = 0.34
        static let dismissDelay: TimeInterval = 1.55
    }

    private var plateSize: CGFloat {
        DeviceLayout.isPad ? 188 : 152
    }

    private var logoSize: CGFloat {
        DeviceLayout.isPad ? 134 : 108
    }

    private var heroSpring: Animation {
        .spring(response: reduceMotion ? 0.24 : 0.52, dampingFraction: 0.84)
    }

    private var secondarySpring: Animation {
        .spring(response: reduceMotion ? 0.2 : 0.34, dampingFraction: 0.9)
    }

    private var fadeAnimation: Animation {
        .easeOut(duration: reduceMotion ? 0.16 : 0.28)
    }

    private var logoPlateColors: [Color] {
        settings.appBrandStyle
            .logoPlateColors(for: settings.appBrandAppearance)
            .map(Color.init(hex:))
    }

    private var logoPlateStrokeColors: [Color] {
        if settings.appBrandAppearance == .dark {
            return [
                Color.white.opacity(0.18),
                Color.white.opacity(0.05)
            ]
        }

        return [
            Color.white.opacity(0.92),
            Color.white.opacity(0.2)
        ]
    }

    private var plateGradient: [Color] {
        logoPlateColors
    }

    private var plateStrokeGradient: [Color] {
        logoPlateStrokeColors
    }

    private var accentGradient: [Color] {
        colorScheme == .dark
            ? [Color(hex: "7EDBFF"), Color(hex: "7C90FF")]
            : [Color(hex: "6CB8FF"), Color(hex: "7C90FF")]
    }

    var body: some View {
        ZStack {
            MonologueBackground()

            backgroundOrbs
                .opacity(backgroundOpacity)
                .scaleEffect(backgroundScale)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                heroSection

                Spacer()

                Text("© 2026 ZIJIU STUDIO")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.monologueTextSecondary.opacity(0.62))
                    .padding(.bottom, DeviceLayout.isPad ? 48 : 36)
                    .opacity(footerOpacity)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    private var backgroundOrbs: some View {
        ZStack {
            orb(
                size: DeviceLayout.isPad ? 560 : 360,
                colors: [Color(hex: "7EDBFF").opacity(colorScheme == .dark ? 0.22 : 0.16), .clear],
                offset: CGSize(width: DeviceLayout.isPad ? -180 : -110, height: DeviceLayout.isPad ? -180 : -120)
            )

            orb(
                size: DeviceLayout.isPad ? 620 : 420,
                colors: [Color(hex: "7C90FF").opacity(colorScheme == .dark ? 0.2 : 0.14), .clear],
                offset: CGSize(width: DeviceLayout.isPad ? 220 : 150, height: DeviceLayout.isPad ? 220 : 180)
            )

            orb(
                size: DeviceLayout.isPad ? 420 : 280,
                colors: [Color.monologueTextPrimary.opacity(colorScheme == .dark ? 0.12 : 0.05), .clear],
                offset: CGSize(width: DeviceLayout.isPad ? 150 : 90, height: DeviceLayout.isPad ? -210 : -150)
            )
        }
    }

    private var heroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 30 : 24) {
            ZStack {
                RoundedRectangle(cornerRadius: DeviceLayout.isPad ? 46 : 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: plateGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: DeviceLayout.isPad ? 46 : 34, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: plateStrokeGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: .black.opacity(settings.appBrandAppearance == .dark ? 0.32 : 0.12),
                        radius: 26,
                        x: 0,
                        y: 18
                    )

                AnimatedLogoView(size: logoSize, animated: !isDismissing)
            }
            .frame(width: plateSize, height: plateSize)
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)
            .rotation3DEffect(.degrees(plateTilt), axis: (x: 1, y: 0, z: 0))

            VStack(spacing: 10) {
                Text("Monologue")
                    .font(.system(size: DeviceLayout.isPad ? 36 : 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                Text(LocalizedStringKey("welcome_slogan"))
                    .font(.system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .tracking(DeviceLayout.isPad ? 1.9 : 1.5)
                    .multilineTextAlignment(.center)
                    .opacity(subtitleOpacity)
                    .offset(y: subtitleOffset)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: accentGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: DeviceLayout.isPad ? 110 : 88, height: 4)
                    .scaleEffect(x: accentScaleX, y: 1, anchor: .center)
                    .opacity(accentOpacity)
                    .padding(.top, 4)
            }
        }
    }

    private func orb(size: CGFloat, colors: [Color], offset: CGSize) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: colors,
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .frame(width: size, height: size)
            .blur(radius: size * 0.12)
            .offset(offset)
    }

    private func startAnimation() {
        animationTask?.cancel()
        isDismissing = false

        backgroundOpacity = 0
        backgroundScale = 0.92
        plateOpacity = 0
        plateScale = 0.84
        plateOffset = 24
        plateTilt = reduceMotion ? 0 : -10
        titleOpacity = 0
        titleOffset = 18
        subtitleOpacity = 0
        subtitleOffset = 26
        accentOpacity = 0
        accentScaleX = 0.35
        footerOpacity = 0

        withAnimation(fadeAnimation) {
            backgroundOpacity = 1
            backgroundScale = 1
        }

        withAnimation(heroSpring) {
            plateOpacity = 1
            plateScale = 1
            plateOffset = 0
            plateTilt = 0
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
            let _ = try await APIService.shared.fetchLoginStatus().async()
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

        withAnimation(.easeInOut(duration: reduceMotion ? 0.18 : 0.32), completionCriteria: .logicallyComplete) {
            backgroundOpacity = 0
            plateOpacity = 0
            plateScale = 1.05
            plateOffset = -12
            titleOpacity = 0
            subtitleOpacity = 0
            accentOpacity = 0
            footerOpacity = 0
        } completion: {
            isPresented = false
        }
    }

    private func sleep(seconds: TimeInterval) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
