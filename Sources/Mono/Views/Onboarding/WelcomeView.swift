import SwiftUI

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    @Binding var isPresented: Bool
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false

    @State private var backgroundOpacity = 1.0
    @State private var backgroundScale: CGFloat = 1.018
    @State private var plateOpacity = 1.0
    @State private var plateScale: CGFloat = 0.82
    @State private var plateOffset: CGFloat = 28
    @State private var titleOpacity = 1.0
    @State private var titleOffset: CGFloat = 0
    @State private var subtitleOpacity = 1.0
    @State private var subtitleOffset: CGFloat = 0
    @State private var accentOpacity = 1.0
    @State private var accentScaleX: CGFloat = 1
    @State private var footerOpacity = 1.0
    @State private var sceneOffset: CGFloat = 0
    @State private var sceneScale: CGFloat = 1
    @State private var isDismissing = false
    @State private var animationTask: Task<Void, Never>?
    @State private var preloadTask: Task<Void, Never>?

    private enum Timing {
        static let preloadStartDelay: TimeInterval = 0.08
        static let dismissDelay: TimeInterval = 2.05
        static let initialContentPollInterval: TimeInterval = 0.12
        static let initialContentRetryInterval: TimeInterval = 2.0
    }

    private var plateSize: CGFloat {
        DeviceLayout.isPad ? 198 : 160
    }

    private var logoSize: CGFloat {
        DeviceLayout.isPad ? 122 : 100
    }

    private var titleWordmarkHeight: CGFloat {
        DeviceLayout.isPad ? 46 : 38
    }

    private var heroSpring: Animation {
        .spring(response: reduceMotion ? 0.24 : 0.54, dampingFraction: 0.82)
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
            preloadTask?.cancel()
        }
    }

    private var welcomeBaseColor: Color {
        if MangaStyle.isActive { return MangaStyle.paper }
        if PetWhiteStyle.isActive { return PetWhiteStyle.paper }
        if PureWhiteStyle.isActive { return PureWhiteStyle.paper }
        if NeumorphicStyle.isActive { return NeumorphicStyle.base }
        if CapsuleStyle.isActive { return CapsuleStyle.base }
        if MujiStyle.isActive { return MujiStyle.paper }
        return colorScheme == .dark ? Color(hex: "03050D") : Color(hex: "F7FAFA")
    }

    @ViewBuilder
    private var welcomeBackdrop: some View {
        if MangaStyle.isActive {
            MangaWelcomeBackdrop()
        } else if PetWhiteStyle.isActive {
            PetWhiteRootBackdrop()
        } else if PureWhiteStyle.isActive {
            PureWhiteRootBackdrop()
        } else if NeumorphicStyle.isActive {
            NeumorphicWelcomeBackdrop()
        } else if CapsuleStyle.isActive {
            CapsuleWelcomeBackdrop()
        } else if MujiStyle.isActive {
            MujiWelcomeBackdrop()
        } else {
            DefaultWelcomeBackdrop()
        }
    }

    @ViewBuilder
    private var welcomeDecor: some View {
        if MangaStyle.isActive || PetWhiteStyle.isActive || PureWhiteStyle.isActive {
            EmptyView()
        } else if NeumorphicStyle.isActive {
            NeumorphicWelcomeDecor()
                .opacity(accentOpacity)
                .scaleEffect(plateScale)
        } else if CapsuleStyle.isActive {
            CapsuleWelcomeDecor()
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
        } else if PetWhiteStyle.isActive {
            petWhiteHeroSection
        } else if PureWhiteStyle.isActive {
            pureWhiteHeroSection
        } else if NeumorphicStyle.isActive {
            neumorphicHeroSection
        } else if CapsuleStyle.isActive {
            capsuleHeroSection
        } else if MujiStyle.isActive {
            mujiHeroSection
        } else {
            defaultHeroSection
        }
    }

    private var defaultHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 34 : 28) {
            // Logo 区域 — 缩放 + 模糊渐清 + 弹簧回弹
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
            .scaleEffect(plateOpacity > 0.5 ? 1.0 : 0.85)
            .blur(radius: plateOpacity > 0.5 ? 0 : 16)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            // 标题区域 — 错峰入场(标题先于副标题)
            VStack(spacing: 12) {
                MonoWordmarkImage(height: titleWordmarkHeight)
                    .scaleEffect(titleOpacity > 0.5 ? 1.0 : 0.88)
                    .blur(radius: titleOpacity > 0.5 ? 0 : 10)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                welcomeSloganBlock(
                    font: .system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded),
                    color: .monoTextSecondary,
                    tracking: DeviceLayout.isPad ? 1.8 : 1.35
                )
                    .scaleEffect(subtitleOpacity > 0.5 ? 1.0 : 0.92)
                    .blur(radius: subtitleOpacity > 0.5 ? 0 : 8)
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
    }

    private var mujiHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 28 : 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.tea, strength: colorScheme == .dark ? 1.2 : 1.5))
                    .frame(width: plateSize * 0.86, height: plateSize * 0.94)
                    .offset(x: 10, y: 12)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MujiStyle.surface)
                    .overlay(MujiPaperTexture(opacity: colorScheme == .dark ? 0.08 : 0.14))
                    .shadow(color: MujiStyle.ink.opacity(colorScheme == .dark ? 0.0 : 0.07), radius: 14, x: 0, y: 6)

                VStack(spacing: 13) {
                    welcomeLogoImage(size: logoSize)

                    MujiWelcomeStitchBloom()
                        .frame(width: plateSize * 0.56, height: 10)
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
        VStack(spacing: DeviceLayout.isPad ? 28 : 22) {
            ZStack {
                // 硬印刷投影：先网点灰错版，再墨版
                RoundedRectangle(cornerRadius: plateSize * 0.1, style: .continuous)
                    .fill(MangaComicPalette.toneMid.opacity(0.9))
                    .frame(width: plateSize * 0.98, height: plateSize * 0.98)
                    .offset(x: 9, y: 10)

                RoundedRectangle(cornerRadius: plateSize * 0.1, style: .continuous)
                    .fill(MangaStyle.strokeInk)
                    .frame(width: plateSize * 0.98, height: plateSize * 0.98)
                    .offset(x: 4.5, y: 5)

                RoundedRectangle(cornerRadius: plateSize * 0.1, style: .continuous)
                    .fill(MangaStyle.bubbleWhite.opacity(colorScheme == .dark ? 0.92 : 0.97))
                    .frame(width: plateSize * 0.98, height: plateSize * 0.98)
                    .overlay(
                        MangaDotsTexture(opacity: colorScheme == .dark ? 0.03 : 0.024, gap: 12)
                            .clipShape(RoundedRectangle(cornerRadius: plateSize * 0.1, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: plateSize * 0.1, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: 2.4)
                    )

                welcomeLogoImage(size: logoSize * 0.86)

                // 「話数」章节印章：贴在分格右上角
                Text("VOL.1")
                    .font(MangaStyle.labelFont(10, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(MangaStyle.onStrokeInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(MangaStyle.strokeInk)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(MangaComicPalette.toneMid)
                            .offset(x: 1.8, y: 1.8)
                    )
                    .rotationEffect(.degrees(6))
                    .offset(x: plateSize * 0.4, y: -plateSize * 0.44)
                    .opacity(accentOpacity)

                // 印刷色块行：墨 + 深灰 + 浅灰
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1.5).fill(MangaStyle.strokeInk).frame(width: 30, height: 5)
                    RoundedRectangle(cornerRadius: 1.5).fill(MangaComicPalette.toneMid.opacity(0.88)).frame(width: 18, height: 5)
                    RoundedRectangle(cornerRadius: 1.5).fill(MangaStyle.mint.opacity(0.9)).frame(width: 12, height: 5)
                }
                .offset(y: plateSize * 0.43)
                .scaleEffect(x: accentScaleX, y: 1)
                .opacity(accentOpacity)
            }
            .frame(width: plateSize * 1.12, height: plateSize * 1.12)
            .rotationEffect(.degrees(-1.2))
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            mangaTitleBlock
        }
    }

    private var petWhiteHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 28 : 22) {
            ZStack {
                PetWhiteClayPuck(
                    shape: RoundedRectangle(cornerRadius: plateSize * 0.24, style: .continuous),
                    tint: PetWhiteStyle.surfaceRaised.opacity(settings.petWhiteUsesIllustratedBackground ? 0.80 : 0.96)
                )
                .frame(width: plateSize * 0.98, height: plateSize * 0.98)

                welcomeLogoImage(size: logoSize * 0.86)

                HStack(spacing: 6) {
                    Capsule().fill(PetWhiteStyle.dogOrange).frame(width: 28, height: 6)
                    Capsule().fill(PetWhiteStyle.mint).frame(width: 18, height: 6)
                    Capsule().fill(PetWhiteStyle.blush.opacity(0.78)).frame(width: 12, height: 6)
                }
                .offset(y: plateSize * 0.43)
                .scaleEffect(x: accentScaleX, y: 1)
                .opacity(accentOpacity)
            }
            .frame(width: plateSize * 1.12, height: plateSize * 1.12)
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            petWhiteTitleBlock
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

    private var pureWhiteHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 30 : 24) {
            ZStack {
                PureWhiteSurfaceBackground(cornerRadius: plateSize * 0.24, elevated: true, tint: PureWhiteStyle.surfaceRaised)
                    .frame(width: plateSize * 1.02, height: plateSize * 0.9)

                RoundedRectangle(cornerRadius: plateSize * 0.18, style: .continuous)
                    .fill(PureWhiteStyle.surfaceTint.opacity(0.88))
                    .frame(width: plateSize * 0.74, height: plateSize * 0.58)
                    .overlay(
                        RoundedRectangle(cornerRadius: plateSize * 0.18, style: .continuous)
                            .stroke(PureWhiteStyle.separator, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 6) {
                            Circle().fill(PureWhiteStyle.accent).frame(width: 6, height: 6)
                            Capsule().fill(PureWhiteStyle.separator).frame(width: 34, height: 4)
                            Capsule().fill(PureWhiteStyle.separator.opacity(0.72)).frame(width: 20, height: 4)
                        }
                        .padding(.top, 14)
                        .padding(.leading, 16)
                    }
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 6) {
                            Capsule().fill(PureWhiteStyle.accent.opacity(0.82)).frame(width: 46, height: 4)
                            Capsule().fill(PureWhiteStyle.separator).frame(width: 28, height: 4)
                            Capsule().fill(PureWhiteStyle.paperBlue.opacity(0.75)).frame(width: 36, height: 4)
                        }
                        .padding(.bottom, 16)
                    }

                welcomeLogoImage(size: logoSize * 0.78)
                    .background(
                        RoundedRectangle(cornerRadius: plateSize * 0.12, style: .continuous)
                            .fill(PureWhiteStyle.surfaceRaised)
                            .frame(width: logoSize * 1.08, height: logoSize * 1.08)
                            .overlay(
                                RoundedRectangle(cornerRadius: plateSize * 0.12, style: .continuous)
                                    .stroke(PureWhiteStyle.separator, lineWidth: 1)
                            )
                    )

                PureWhiteIconBadge(icon: .musicNote, tint: PureWhiteStyle.accent, size: 38)
                    .offset(x: plateSize * 0.39, y: -plateSize * 0.28)
                    .scaleEffect(accentScaleX)
                    .opacity(accentOpacity)

                PureWhiteIconBadge(icon: .library, tint: PureWhiteStyle.paperBlue, size: 34)
                    .offset(x: -plateSize * 0.39, y: plateSize * 0.26)
                    .scaleEffect(accentScaleX)
                    .opacity(accentOpacity)
            }
            .frame(width: plateSize * 1.2, height: plateSize * 1.12)
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            pureWhiteTitleBlock
        }
    }

    private var capsuleHeroSection: some View {
        VStack(spacing: DeviceLayout.isPad ? 30 : 24) {
            ZStack {
                RoundedRectangle(cornerRadius: plateSize * 0.28, style: .continuous)
                    .fill(CapsuleStyle.surface.opacity(colorScheme == .dark ? 0.78 : 0.84))
                    .frame(width: plateSize * 1.18, height: plateSize * 0.86)
                    .offset(y: plateSize * 0.16)
                    .overlay(
                        RoundedRectangle(cornerRadius: plateSize * 0.28, style: .continuous)
                            .stroke(CapsuleStyle.hairline.opacity(0.7), lineWidth: 1)
                            .offset(y: plateSize * 0.16)
                    )
                    .shadow(color: CapsuleStyle.accent.opacity(colorScheme == .dark ? 0.12 : 0.16), radius: 22, x: 0, y: 14)

                CapsuleWelcomeSignalStack()
                    .frame(width: plateSize * 1.42, height: plateSize * 0.72)
                    .offset(y: plateSize * 0.2)
                    .scaleEffect(x: accentScaleX, y: 1, anchor: .center)
                    .opacity(accentOpacity)

                RoundedRectangle(cornerRadius: plateSize * 0.24, style: .continuous)
                    .fill(CapsuleStyle.surfaceRaised)
                    .frame(width: plateSize * 0.76, height: plateSize * 0.76)
                    .overlay(
                        RoundedRectangle(cornerRadius: plateSize * 0.24, style: .continuous)
                            .stroke(CapsuleStyle.hairline, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 18, x: 0, y: 12)

                welcomeLogoImage(size: logoSize * 0.92)

                HStack(spacing: 7) {
                    Capsule().fill(CapsuleStyle.coral).frame(width: 12, height: 12)
                    Capsule().fill(CapsuleStyle.amber).frame(width: 12, height: 12)
                    Capsule().fill(CapsuleStyle.mint).frame(width: 12, height: 12)
                }
                .padding(8)
                .background(Capsule().fill(CapsuleStyle.surfaceTint.opacity(0.94)))
                .overlay(Capsule().stroke(CapsuleStyle.hairline.opacity(0.7), lineWidth: 0.8))
                .offset(y: -plateSize * 0.52)
                .opacity(accentOpacity)
            }
            .frame(width: plateSize * 1.55, height: plateSize * 1.2)
            .scaleEffect(plateScale)
            .opacity(plateOpacity)
            .offset(y: plateOffset)

            capsuleTitleBlock
        }
    }

    private var defaultTitleBlock: some View {
        VStack(spacing: 12) {
            MonoWordmarkImage(height: titleWordmarkHeight)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            welcomeSloganBlock(
                font: .system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded),
                color: .monoTextSecondary,
                tracking: DeviceLayout.isPad ? 1.8 : 1.35
            )
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
            MonoWordmarkImage(height: titleWordmarkHeight)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            welcomeSloganBlock(
                font: MujiStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .regular),
                color: MujiStyle.inkSoft,
                tracking: 1.2
            )
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)
        }
    }

    private var mangaTitleBlock: some View {
        VStack(spacing: 11) {
            MonoWordmarkImage(height: titleWordmarkHeight)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            welcomeSloganBlock(
                font: MangaStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .bold),
                color: MangaStyle.inkSub,
                minimumScaleFactor: 0.8,
                shortColor: MangaStyle.accentPink.opacity(0.82)
            )
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5).fill(MangaStyle.strokeInk).frame(width: 34, height: 5)
                RoundedRectangle(cornerRadius: 1.5).fill(MangaComicPalette.toneMid.opacity(0.85)).frame(width: 20, height: 5)
                RoundedRectangle(cornerRadius: 1.5).fill(MangaStyle.mint.opacity(0.9)).frame(width: 12, height: 5)
            }
            .scaleEffect(x: accentScaleX, y: 1)
            .opacity(accentOpacity)
            .padding(.top, 2)
        }
    }

    private var petWhiteTitleBlock: some View {
        VStack(spacing: 11) {
            MonoWordmarkImage(height: titleWordmarkHeight)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            welcomeSloganBlock(
                font: PetWhiteStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .black),
                color: PetWhiteStyle.inkSoft,
                tracking: 0.9,
                shortColor: PetWhiteStyle.dogOrange.opacity(0.82)
            )
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)

            HStack(spacing: 8) {
                Capsule().fill(PetWhiteStyle.dogOrange).frame(width: 36, height: 6)
                Capsule().fill(PetWhiteStyle.mint).frame(width: 22, height: 6)
                Capsule().fill(PetWhiteStyle.sky.opacity(0.72)).frame(width: 14, height: 6)
            }
            .scaleEffect(x: accentScaleX, y: 1)
            .opacity(accentOpacity)
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, settings.petWhiteUsesIllustratedBackground ? 14 : 0)
        .background {
            if settings.petWhiteUsesIllustratedBackground {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PetWhiteStyle.surfaceRaised.opacity(0.70))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(PetWhiteStyle.stroke.opacity(0.72), lineWidth: 1.2)
                    )
            }
        }
    }

    private var pureWhiteTitleBlock: some View {
        VStack(spacing: 11) {
            MonoWordmarkImage(height: titleWordmarkHeight)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            welcomeSloganBlock(
                font: PureWhiteStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .bold),
                color: PureWhiteStyle.inkSoft,
                shortColor: PureWhiteStyle.accent.opacity(0.8)
            )
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)

            HStack(spacing: 6) {
                Capsule().fill(PureWhiteStyle.accent).frame(width: 30, height: 7)
                Capsule().fill(PureWhiteStyle.separator).frame(width: 18, height: 7)
                Capsule().fill(PureWhiteStyle.paperBlue.opacity(0.88)).frame(width: 12, height: 7)
            }
            .scaleEffect(x: accentScaleX, y: 1)
            .opacity(accentOpacity)
            .padding(.top, 2)
        }
    }

    private var neumorphicTitleBlock: some View {
        VStack(spacing: 12) {
            MonoWordmarkImage(height: titleWordmarkHeight)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            welcomeSloganBlock(
                font: NeumorphicStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .medium),
                color: NeumorphicStyle.inkSoft,
                tracking: 1.0,
                shortColor: NeumorphicStyle.accent.opacity(0.78)
            )
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

    private var capsuleTitleBlock: some View {
        VStack(spacing: 12) {
            MonoWordmarkImage(height: titleWordmarkHeight)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            welcomeSloganBlock(
                font: CapsuleStyle.labelFont(DeviceLayout.isPad ? 13 : 12, weight: .semibold),
                color: CapsuleStyle.inkSoft,
                tracking: 0.8,
                shortColor: CapsuleStyle.accent.opacity(0.78)
            )
                .opacity(subtitleOpacity)
                .offset(y: subtitleOffset)

            HStack(spacing: 7) {
                Capsule().fill(CapsuleStyle.accent).frame(width: 30, height: 7)
                Capsule().fill(CapsuleStyle.cyan.opacity(0.75)).frame(width: 16, height: 7)
                Capsule().fill(CapsuleStyle.violet.opacity(0.68)).frame(width: 10, height: 7)
            }
            .scaleEffect(x: accentScaleX, y: 1)
            .opacity(accentOpacity)
            .padding(.top, 2)
        }
    }

    private func welcomeSloganBlock(
        font: Font,
        color: Color,
        tracking: CGFloat = 0,
        lineLimit: Int = 2,
        minimumScaleFactor: CGFloat = 0.82,
        shortColor: Color? = nil,
        shortTracking: CGFloat = 1.4
    ) -> some View {
        VStack(spacing: DeviceLayout.isPad ? 7 : 5) {
            Text(LocalizedStringKey("welcome_slogan"))
                .font(font)
                .foregroundColor(color)
                .tracking(tracking)
                .multilineTextAlignment(.center)
                .lineLimit(lineLimit)
                .minimumScaleFactor(minimumScaleFactor)

            Text(LocalizedStringKey("welcome_slogan_short"))
                .font(.system(size: DeviceLayout.isPad ? 10 : 9, weight: .semibold, design: .rounded))
                .foregroundColor((shortColor ?? color).opacity(0.72))
                .tracking(shortTracking)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
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
                Color.monoTextPrimary,
                Color.monoTextPrimary.opacity(colorScheme == .dark ? 0.84 : 0.7),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var logoShadowColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(colorScheme == .dark ? 0.42 : 0.22) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.strokeInk.opacity(colorScheme == .dark ? 0.34 : 0.18) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.darkShadow(colorScheme, intensity: colorScheme == .dark ? 0.64 : 0.4) }
        if CapsuleStyle.isActive { return CapsuleStyle.accent.opacity(colorScheme == .dark ? 0.32 : 0.2) }
        if MujiStyle.isActive { return Color.black.opacity(colorScheme == .dark ? 0.26 : 0.09) }
        return Color.black.opacity(colorScheme == .dark ? 0.28 : 0.16)
    }

    private var footerFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(10, weight: .black) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(10, weight: .black) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.labelFont(10, weight: .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(10, weight: .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(10, weight: .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(10, weight: .regular) }
        return .system(size: 10, weight: .medium, design: .monospaced)
    }

    private var footerColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkMuted.opacity(0.78) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted.opacity(0.74) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkMuted.opacity(0.78) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted.opacity(0.72) }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.inkMuted.opacity(0.72) }
        return .monoTextSecondary.opacity(0.62)
    }

    private func startAnimation() {
        animationTask?.cancel()
        isDismissing = false

        backgroundOpacity = 1
        backgroundScale = (reduceMotion || PetWhiteStyle.isActive) ? 1 : 1.018
        plateOpacity = 1
        plateScale = MangaStyle.isActive ? 0.78 : (PureWhiteStyle.isActive ? 0.8 : (NeumorphicStyle.isActive ? 0.84 : (CapsuleStyle.isActive ? 0.8 : 0.82)))
        plateOffset = MujiStyle.isActive ? 18 : (PureWhiteStyle.isActive ? 24 : (NeumorphicStyle.isActive ? 22 : (CapsuleStyle.isActive ? 24 : 28)))
        titleOpacity = 1
        titleOffset = 0
        subtitleOpacity = 1
        subtitleOffset = 0
        accentOpacity = 1
        accentScaleX = 1
        footerOpacity = 1
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
        preloadTask = Task(priority: .utility) {
            try? await sleep(seconds: Timing.preloadStartDelay)
            await loadDataInBackground(isLoggedIn: isLoggedIn)
        }

        animationTask = Task {
            do {
                try await sleep(seconds: Timing.dismissDelay)
                await waitForInitialHomeContentIfNeeded()
                await MainActor.run {
                    dismissWelcome()
                }
            } catch {
                return
            }
        }
    }

    private func loadDataInBackground(isLoggedIn: Bool) async {
        await MainActor.run {
            _ = HomeViewModel.shared
            _ = PodcastViewModel.shared
        }

        await OptimizedCacheManager.shared.quickPreload()
        await MainActor.run {
            HomeViewModel.shared.reloadHomeCacheIfUseful(reason: "welcome quick preload")
        }

        guard OnlineAccessManager.shared.hasStoredToken else { return }

        if isLoggedIn {
            do {
                _ = try await APIService.shared.fetchLoginStatus().async()
            } catch {
                AppLogger.warning("登录状态检查失败: \(error)")
            }
        }

        let refreshPlan = await MainActor.run {
            (
                home: GlobalRefreshManager.shared.checkDailyRefreshNeeded(for: .home),
                podcast: GlobalRefreshManager.shared.checkDailyRefreshNeeded(for: .podcast)
            )
        }
        await MainActor.run {
            let shouldLoadHome = refreshPlan.home || !HomeViewModel.shared.hasDisplayableHomeContent
            if shouldLoadHome {
                HomeViewModel.shared.fetchData(forceDaily: refreshPlan.home || !HomeViewModel.shared.hasDisplayableHomeContent)
            }
            PodcastViewModel.shared.preloadIfNeeded(
                forceDaily: refreshPlan.podcast,
                reason: "welcome preload"
            )
            GlobalRefreshManager.shared.refreshLibraryPublisher.send(false)
            GlobalRefreshManager.shared.refreshProfilePublisher.send(false)
        }
    }

    private func waitForInitialHomeContentIfNeeded() async {
        let shouldWait = await MainActor.run {
            OnlineAccessManager.shared.hasStoredToken
        }
        guard shouldWait else { return }

        var lastRetry = Date.distantPast
        while true {
            if Task.isCancelled { return }

            let isReady = await MainActor.run {
                HomeViewModel.shared.reloadHomeCacheIfUseful(reason: "welcome before dismiss")
                return HomeViewModel.shared.hasDisplayableHomeContent
            }
            if isReady { return }

            if Date().timeIntervalSince(lastRetry) >= Timing.initialContentRetryInterval {
                lastRetry = Date()
                await MainActor.run {
                    if HomeViewModel.shared.isLoading {
                        HomeViewModel.shared.ensureHomeDataLoaded(reason: "welcome waiting for initial content")
                    } else {
                        HomeViewModel.shared.fetchData(forceDaily: true)
                    }
                }
            }

            try? await sleep(seconds: Timing.initialContentPollInterval)
        }
    }

    private func dismissWelcome() {
        guard !isDismissing else { return }
        isDismissing = true

        let applyDismissState = {
            sceneOffset = -(ScreenInfo.mainScreenSize.height + DeviceLayout.safeAreaTop + DeviceLayout.safeAreaBottom + 80)
            sceneScale = reduceMotion ? 1 : 1.015
            backgroundScale = 1.03
            plateScale = MangaStyle.isActive ? 0.98 : (PureWhiteStyle.isActive ? 1.0 : (NeumorphicStyle.isActive ? 0.99 : (CapsuleStyle.isActive ? 1.0 : 1.02)))
            plateOffset = -18
            titleOffset = -14
            subtitleOffset = -12
        }

        if #available(iOS 17.0, *) {
            withAnimation(dismissAnimation, completionCriteria: .logicallyComplete) {
                applyDismissState()
            } completion: {
                isPresented = false
            }
        } else {
            withAnimation(dismissAnimation) {
                applyDismissState()
            }
            // iOS 16 无 completion 回调，按动画时长延迟收尾
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isPresented = false
            }
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
        ZStack {
            // 底层:背景图
            GeometryReader { proxy in
                Image("default_theme_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            // 中层:半透明毛玻璃
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // 顶层:柔和径向渐变(让中心 Logo 区域更聚焦)
            RadialGradient(
                colors: [
                    Color.clear,
                    (colorScheme == .dark ? Color.black : Color.white).opacity(0.18),
                ],
                center: .center,
                startRadius: 80,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

private struct DefaultWelcomeLogoStage: View {
    var accent: Color
    var accentOpacity: Double
    var isAnimating: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(paused: !isAnimating)) { timeline in
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
        TimelineView(AppFrameRate.animationTimeline(paused: !isAnimating)) { _ in
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
                            Color.monoTextSecondary.opacity(colorScheme == .dark ? 0.22 : 0.14),
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            MujiRootBackdrop()

            // 呼吸感水彩晕染:两团色浸随时间极缓慢地涨落(低帧率即可,省电)
            TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 24, paused: reduceMotion)) { timeline in
                let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let breathA = 0.5 + 0.5 * sin(time * 0.16)
                    let breathB = 0.5 + 0.5 * sin(time * 0.13 + 2.1)
                    let strength = colorScheme == .dark ? 0.10 : 0.15

                    let radiusA = size.width * (0.52 + 0.05 * breathA)
                    let centerA = CGPoint(x: size.width * 0.86, y: size.height * 0.16)
                    context.fill(
                        Path(ellipseIn: CGRect(x: centerA.x - radiusA, y: centerA.y - radiusA * 0.82, width: radiusA * 2, height: radiusA * 1.64)),
                        with: .radialGradient(
                            Gradient(colors: [MujiStyle.clay.opacity(strength * (0.72 + 0.28 * breathA)), .clear]),
                            center: centerA,
                            startRadius: 4,
                            endRadius: radiusA
                        )
                    )

                    let radiusB = size.width * (0.46 + 0.05 * breathB)
                    let centerB = CGPoint(x: size.width * 0.1, y: size.height * 0.84)
                    context.fill(
                        Path(ellipseIn: CGRect(x: centerB.x - radiusB, y: centerB.y - radiusB * 0.85, width: radiusB * 2, height: radiusB * 1.7)),
                        with: .radialGradient(
                            Gradient(colors: [MujiStyle.tea.opacity(strength * (0.66 + 0.34 * breathB)), .clear]),
                            center: centerB,
                            startRadius: 4,
                            endRadius: radiusB
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct MujiWelcomeDecor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// 漂浮的"种籽"点:横向锚点 / 纵向基线 / 尺寸 / 上升速度 / 相位 / 色序
    private static let motes: [(x: CGFloat, baseY: CGFloat, size: CGFloat, speed: Double, phase: Double, color: Int)] = [
        (0.12, 0.34, 5.5, 0.020, 0.05, 0),
        (0.20, 0.78, 4.0, 0.026, 0.42, 1),
        (0.30, 0.22, 3.0, 0.016, 0.71, 2),
        (0.44, 0.86, 3.5, 0.022, 0.18, 1),
        (0.58, 0.16, 4.5, 0.018, 0.55, 0),
        (0.70, 0.80, 3.0, 0.028, 0.87, 2),
        (0.80, 0.30, 6.0, 0.015, 0.33, 1),
        (0.88, 0.68, 4.0, 0.024, 0.62, 0),
        (0.06, 0.58, 3.0, 0.021, 0.94, 2),
        (0.94, 0.46, 3.5, 0.019, 0.26, 3),
    ]

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let palette = [MujiStyle.clay, MujiStyle.tea, MujiStyle.indigo, MujiStyle.straw]
                let baseAlpha = colorScheme == .dark ? 0.4 : 0.34

                for mote in Self.motes {
                    // 每颗种籽循环上浮一小段,中途渐显、末尾渐隐
                    let cycle = (time * mote.speed + mote.phase).truncatingRemainder(dividingBy: 1)
                    let rise = CGFloat(cycle) * size.height * 0.14
                    let sway = CGFloat(sin(time * 0.4 + mote.phase * 12)) * 7
                    let alpha = baseAlpha * sin(cycle * .pi)

                    let center = CGPoint(
                        x: size.width * mote.x + sway,
                        y: size.height * mote.baseY - rise
                    )
                    let rect = CGRect(
                        x: center.x - mote.size / 2,
                        y: center.y - mote.size / 2,
                        width: mote.size,
                        height: mote.size
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(palette[mote.color % palette.count].opacity(alpha))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// 欢迎页 Logo 下方的针脚线自绘 + 三色圆点错峰弹出
private struct MujiWelcomeStitchBloom: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lineProgress: CGFloat = 0
    @State private var dotsShown = false

    var body: some View {
        ZStack {
            MujiStitchLine()
                .trim(from: 0, to: lineProgress)
                .stroke(
                    MujiStyle.separator.opacity(0.65),
                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round, dash: [0.1, 7])
                )
                .frame(height: 2)

            HStack(spacing: 24) {
                bloomDot(MujiStyle.tea, size: 5, delay: 0.62)
                bloomDot(MujiStyle.clay, size: 6.5, delay: 0.76)
                bloomDot(MujiStyle.indigo, size: 5, delay: 0.9)
            }
        }
        .onAppear {
            if reduceMotion {
                lineProgress = 1
                dotsShown = true
            } else {
                withAnimation(.easeOut(duration: 0.85).delay(0.3)) {
                    lineProgress = 1
                }
                dotsShown = true
            }
        }
    }

    private func bloomDot(_ tint: Color, size: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(tint)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(MujiStyle.paper)
                    .frame(width: size + 6, height: size + 6)
            )
            .scaleEffect(dotsShown ? 1 : 0.01)
            .animation(
                reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.56).delay(delay),
                value: dotsShown
            )
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

private struct CapsuleWelcomeBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            CapsuleRootBackdrop()

            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.white.opacity(0.04), .clear, Color.black.opacity(0.12)]
                    : [Color.white.opacity(0.58), .clear, Color(hex: "DCE7FF").opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                CapsuleWelcomeFloor()
                    .frame(height: DeviceLayout.isPad ? 250 : 206)
                    .opacity(colorScheme == .dark ? 0.34 : 0.48)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct CapsuleWelcomeDecor: View {
    var body: some View {
        ZStack {
            CapsuleWelcomePill(width: DeviceLayout.isPad ? 132 : 104, height: 18, tint: CapsuleStyle.cyan)
                .rotationEffect(.degrees(-14))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, DeviceLayout.isPad ? 92 : 28)
                .padding(.top, DeviceLayout.isPad ? 152 : 118)

            CapsuleWelcomePill(width: DeviceLayout.isPad ? 108 : 82, height: 16, tint: CapsuleStyle.violet)
                .rotationEffect(.degrees(15))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, DeviceLayout.isPad ? 112 : 38)
                .padding(.top, DeviceLayout.isPad ? 206 : 158)

            CapsuleWelcomePill(width: DeviceLayout.isPad ? 120 : 94, height: 17, tint: CapsuleStyle.mint)
                .rotationEffect(.degrees(11))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, DeviceLayout.isPad ? 116 : 40)
                .padding(.bottom, DeviceLayout.isPad ? 184 : 138)
        }
        .ignoresSafeArea()
    }
}

private struct CapsuleWelcomePill: View {
    let width: CGFloat
    let height: CGFloat
    let tint: Color

    var body: some View {
        Capsule()
            .fill(tint.opacity(0.2))
            .frame(width: width, height: height)
            .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
            .shadow(color: tint.opacity(0.12), radius: 14, x: 0, y: 8)
    }
}

private struct CapsuleWelcomeSignalStack: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Capsule()
                    .fill(CapsuleStyle.accent.opacity(0.13))
                    .frame(width: width * 0.92, height: height * 0.14)
                    .offset(y: height * 0.08)

                Capsule()
                    .fill(CapsuleStyle.cyan.opacity(0.15))
                    .frame(width: width * 0.68, height: height * 0.11)
                    .offset(x: -width * 0.1, y: -height * 0.14)

                Capsule()
                    .fill(CapsuleStyle.violet.opacity(0.13))
                    .frame(width: width * 0.58, height: height * 0.1)
                    .offset(x: width * 0.16, y: height * 0.28)
            }
        }
    }
}

private struct CapsuleWelcomeFloor: View {
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            for index in 0..<5 {
                let y = size.height * (0.18 + CGFloat(index) * 0.16)
                let height = max(6, size.height * 0.025)
                let rect = CGRect(
                    x: size.width * CGFloat(index % 2 == 0 ? -0.08 : 0.12),
                    y: y,
                    width: size.width * CGFloat(index % 2 == 0 ? 0.78 : 0.64),
                    height: height
                )
                let path = Path(roundedRect: rect, cornerRadius: height / 2)
                let tint = [CapsuleStyle.accent, CapsuleStyle.cyan, CapsuleStyle.violet, CapsuleStyle.mint, CapsuleStyle.coral][index]
                context.fill(path, with: .color(tint.opacity(0.08)))
            }
        }
    }
}

private struct MangaWelcomeBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [MangaStyle.paper, MangaStyle.paperWarm, MangaStyle.paperCool.opacity(0.9)]
                    : [MangaStyle.surface, MangaStyle.paper, MangaStyle.paperWarm],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 集中線：向中心汇聚的手绘线稿，低帧率「boiling」抖动模拟手绘逐帧
            MangaConcentrationLines(
                opacity: colorScheme == .dark ? 0.16 : 0.13,
                animated: !reduceMotion
            )

            MangaPaperGrainTexture(opacity: colorScheme == .dark ? 0.05 : 0.07)
        }
        .ignoresSafeArea()
    }
}

/// 漫画集中線：从画面四周向中心收束的放射线，
/// 以 8fps 更新种子产生轻微「沸腾」抖动，还原手绘逐帧质感。
private struct MangaConcentrationLines: View {
    var opacity: Double
    var animated: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: animated ? 0.125 : 3600)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let maxRadius = hypot(size.width, size.height) * 0.62
                // 中心留白半径：线只画在外圈，中心留给 logo
                let clearRadius = min(size.width, size.height) * 0.4
                let lineCount = 52
                let frameSeed = animated
                    ? Int(timeline.date.timeIntervalSinceReferenceDate * 8) % 3
                    : 0

                for index in 0 ..< lineCount {
                    // 每帧用不同素数扰动角度与线长，形成 boiling 效果
                    let jitterA = Double((index * 73 + frameSeed * 131) % 100) / 100.0
                    let jitterB = Double((index * 37 + frameSeed * 97) % 100) / 100.0

                    let baseAngle = Double(index) / Double(lineCount) * .pi * 2
                    let angle = baseAngle + (jitterA - 0.5) * 0.035

                    let innerRadius = clearRadius * (1 + jitterB * 0.18)
                    let outerRadius = maxRadius * (0.86 + jitterA * 0.14)

                    var path = Path()
                    path.move(to: CGPoint(
                        x: center.x + cos(angle) * innerRadius,
                        y: center.y + sin(angle) * innerRadius
                    ))
                    path.addLine(to: CGPoint(
                        x: center.x + cos(angle) * outerRadius,
                        y: center.y + sin(angle) * outerRadius
                    ))

                    let weight: CGFloat = index % 5 == 0 ? 1.7 : (index % 3 == 0 ? 1.1 : 0.6)
                    let alpha = opacity * (index % 4 == 0 ? 1 : 0.62)
                    context.stroke(
                        path,
                        with: .color(MangaStyle.strokeInk.opacity(alpha)),
                        lineWidth: weight
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
