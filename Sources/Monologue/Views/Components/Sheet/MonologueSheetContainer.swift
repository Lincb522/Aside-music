import SwiftUI

struct MonologueSheetContainer<Content: View>: View {
    let preset: MonologueSheetPreset
    let stretchAmount: CGFloat
    let dragCoordinator: MonologueSheetDragCoordinator?
    let isInteractiveMotionActive: Bool
    let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    init(
        preset: MonologueSheetPreset = .standard,
        stretchAmount: CGFloat = 0,
        dragCoordinator: MonologueSheetDragCoordinator? = nil,
        isInteractiveMotionActive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.preset = preset
        self.stretchAmount = stretchAmount
        self.dragCoordinator = dragCoordinator
        self.isInteractiveMotionActive = isInteractiveMotionActive
        self.content = content()
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { proxy in
            let panelWidth = max(0, min(preset.maxContentWidth, proxy.size.width - (preset.horizontalPadding * 2)))
            let maximumPanelHeight = resolvedMaximumHeight(in: proxy)
            let panelHeight = resolvedPanelHeight(maximumHeight: maximumPanelHeight)
            let bottomInset = proxy.safeAreaInsets.bottom + preset.bottomPadding
            let bottomSurfaceExtension = MonologueSheetThemeStyle.attachesSurfaceToBottom ? bottomInset : 0
            let visualPanelHeight = panelHeight + bottomSurfaceExtension + max(0, stretchAmount)
            let outsideBottomPadding = MonologueSheetThemeStyle.attachesSurfaceToBottom ? 0 : bottomInset

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    // 拖动手势挂在顶部区域并使用 highPriority，避免列表/ScrollView 抢走垂直拖动。
                    if preset.showsHandle {
                        ZStack {
                            if let coordinator = dragCoordinator {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(
                                        DragGesture(minimumDistance: 8)
                                            .onChanged { coordinator.applyDragTranslation(fromGestureHeight: $0.translation.height) }
                                            .onEnded { coordinator.endDrag($0) }
                                    )
                            }

                            MonologueSheetHandleView()
                                .padding(.top, 12)
                                .padding(.bottom, 14)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: sheetTopChromeHeight)
                    } else if let coordinator = dragCoordinator {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: sheetTopChromeHeight)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 8)
                                    .onChanged { coordinator.applyDragTranslation(fromGestureHeight: $0.translation.height) }
                                    .onEnded { coordinator.endDrag($0) }
                            )
                    }

                    content
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(width: panelWidth)
                .frame(height: visualPanelHeight, alignment: .top)
                .background(
                    MonologueSheetSurfaceBackground(cornerRadius: resolvedCornerRadius)
                )
                .clipShape(panelShape)
                .modifier(
                    MonologueSheetLiquidSurfaceModifier(
                        cornerRadius: resolvedCornerRadius,
                        isEnabled: !isInteractiveMotionActive && !MonologueSheetThemeStyle.usesCustomThemeSurface
                    )
                )
                .overlay {
                    MonologueSheetSurfaceOverlay(
                        cornerRadius: resolvedCornerRadius,
                        isInteractiveMotionActive: isInteractiveMotionActive
                    )
                }
                .shadow(
                    color: MonologueSheetThemeStyle.shadowColor,
                    radius: MonologueSheetThemeStyle.shadowRadius(
                        colorScheme: colorScheme,
                        isInteractiveMotionActive: isInteractiveMotionActive
                    ),
                    x: 0,
                    y: MonologueSheetThemeStyle.shadowYOffset(isInteractiveMotionActive: isInteractiveMotionActive)
                )
                .themeRenderSheetLayer(isEnabled: !isInteractiveMotionActive)
                .padding(.horizontal, preset.horizontalPadding)
                .padding(.bottom, outsideBottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .background(Color.clear)
    }

    /// 顶部拖动手势热区高度（与 `resolvedPanelHeight` 中 handle 占位一致）。
    private var sheetTopChromeHeight: CGFloat { 44 }

    private var panelShape: MonologueSheetSurfaceShape {
        MonologueSheetSurfaceShape(
            cornerRadius: resolvedCornerRadius,
            attachesToBottom: MonologueSheetThemeStyle.attachesSurfaceToBottom
        )
    }

    private var resolvedCornerRadius: CGFloat {
        preset.monologueResolvedCornerRadius
    }

    private func resolvedMaximumHeight(in proxy: GeometryProxy) -> CGFloat {
        let availableHeight = proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
        let clampedAvailableHeight = max(0, availableHeight - preset.minTopSpacing)

        switch preset.heightConstraint {
        case .fixed(let value):
            return min(value, clampedAvailableHeight)
        case .maximumRatio(let value):
            return clampedAvailableHeight * value
        }
    }

    private func resolvedPanelHeight(maximumHeight: CGFloat) -> CGFloat {
        maximumHeight
    }
}

private struct MonologueSheetLiquidSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *), isEnabled {
            content
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
        }
    }
}

enum MonologueSheetThemeStyle {
    static var usesCustomThemeSurface: Bool {
        MangaStyle.isActive || PetWhiteStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || CapsuleStyle.isActive || SequoiaStyle.isActive || LiquidGlassStyle.isActive || ClayStyle.isActive || SignalStyle.isActive || BentoStyle.isActive
    }

    static var attachesSurfaceToBottom: Bool {
        MangaStyle.isActive || PetWhiteStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || CapsuleStyle.isActive || LiquidGlassStyle.isActive || ClayStyle.isActive || SignalStyle.isActive || BentoStyle.isActive
    }

    static var shadowColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink.opacity(0.22) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.stroke.opacity(0.18) }
        if MujiStyle.isActive { return Color.black.opacity(0.07) }
        if NeumorphicStyle.isActive { return Color.black.opacity(0.16) }
        if CapsuleStyle.isActive { return CapsuleStyle.accent.opacity(0.16) }
        if SequoiaStyle.isActive { return Color(light: Color(hex: "304760").opacity(0.11), dark: Color.black.opacity(0.34)) }
        if LiquidGlassStyle.isActive { return Color(light: Color(hex: "2D6B8A").opacity(0.14), dark: Color.black.opacity(0.38)) }
        if ClayStyle.isActive { return Color.black.opacity(0.14) }
        if SignalStyle.isActive { return Color.black.opacity(0.16) }
        if BentoStyle.isActive { return Color.black.opacity(0.11) }
        return Color.monologueSheetShadow
    }

    static func shadowRadius(colorScheme: ColorScheme, isInteractiveMotionActive: Bool) -> CGFloat {
        if isInteractiveMotionActive { return usesCustomThemeSurface ? 8 : 10 }
        if MangaStyle.isActive { return 0 }
        if PetWhiteStyle.isActive { return colorScheme == .dark ? 24 : 18 }
        if MujiStyle.isActive { return 18 }
        if NeumorphicStyle.isActive { return colorScheme == .dark ? 24 : 22 }
        if CapsuleStyle.isActive { return colorScheme == .dark ? 24 : 20 }
        if SequoiaStyle.isActive { return colorScheme == .dark ? 24 : 20 }
        if LiquidGlassStyle.isActive { return colorScheme == .dark ? 30 : 24 }
        if ClayStyle.isActive { return colorScheme == .dark ? 24 : 20 }
        if SignalStyle.isActive { return colorScheme == .dark ? 26 : 22 }
        if BentoStyle.isActive { return colorScheme == .dark ? 22 : 18 }
        return colorScheme == .dark ? 30 : 24
    }

    static func shadowYOffset(isInteractiveMotionActive: Bool) -> CGFloat {
        if isInteractiveMotionActive { return usesCustomThemeSurface ? 3 : 4 }
        if MangaStyle.isActive { return 5 }
        if PetWhiteStyle.isActive { return 8 }
        if MujiStyle.isActive { return 9 }
        if NeumorphicStyle.isActive { return 10 }
        if CapsuleStyle.isActive { return 9 }
        if SequoiaStyle.isActive { return 9 }
        if LiquidGlassStyle.isActive { return 11 }
        if ClayStyle.isActive { return 9 }
        if SignalStyle.isActive { return 10 }
        if BentoStyle.isActive { return 8 }
        return 14
    }
}

struct MonologueSheetSurfaceShape: InsettableShape {
    let cornerRadius: CGFloat
    var attachesToBottom: Bool = false
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)

        guard attachesToBottom else {
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .path(in: rect)
        }

        let radius = min(cornerRadius, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> MonologueSheetSurfaceShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

struct MonologueSheetHandleView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if MangaStyle.isActive {
            Capsule()
                .fill(MangaStyle.labelYellow)
                .frame(width: 48, height: 7)
                .overlay(
                    Capsule()
                        .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                )
        } else if PetWhiteStyle.isActive {
            HStack(spacing: 5) {
                Capsule()
                    .fill(PetWhiteStyle.dogOrange)
                    .frame(width: 26, height: 6)
                Capsule()
                    .fill(PetWhiteStyle.mint)
                    .frame(width: 12, height: 6)
                Capsule()
                    .fill(PetWhiteStyle.sky)
                    .frame(width: 12, height: 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(PetWhiteStyle.surfaceRaised, in: Capsule())
            .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: PetWhiteStyle.fineStrokeWidth))
        } else if MujiStyle.isActive {
            Capsule()
                .fill(MujiStyle.hairline.opacity(0.78))
                .frame(width: 38, height: 4)
                .overlay(
                    Capsule()
                        .stroke(MujiStyle.surface.opacity(0.65), lineWidth: 0.5)
                )
        } else if NeumorphicStyle.isActive {
            ZStack {
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 54, height: 12)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 9, elevated: false, pressed: true, lightweight: true))

                Capsule()
                    .fill(NeumorphicStyle.inkMuted.opacity(0.36))
                    .frame(width: 34, height: 4)
                    .shadow(color: NeumorphicStyle.lightShadow(colorScheme, intensity: 0.32), radius: 1, x: 0, y: -0.5)
            }
        } else if CapsuleStyle.isActive {
            HStack(spacing: 5) {
                Capsule()
                    .fill(LinearGradient(colors: CapsuleStyle.accentGradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: 28, height: 5)
                Capsule()
                    .fill(CapsuleStyle.cyan.opacity(0.78))
                    .frame(width: 10, height: 5)
                Capsule()
                    .fill(CapsuleStyle.inkMuted.opacity(colorScheme == .dark ? 0.32 : 0.22))
                    .frame(width: 10, height: 5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(CapsuleStyle.surfaceTint.opacity(colorScheme == .dark ? 0.64 : 0.72))
                    .overlay(Capsule().stroke(CapsuleStyle.hairline.opacity(0.72), lineWidth: 0.75))
            )
        } else if ClayStyle.isActive {
            ZStack {
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 54, height: 12)
                    .background(ClaySurfaceBackground(cornerRadius: 9, tint: ClayStyle.cream, elevated: false, pressed: true, compact: true))

                Capsule()
                    .fill(ClayStyle.accent.opacity(0.55))
                    .frame(width: 34, height: 4)
            }
        } else if SequoiaStyle.isActive {
            HStack(spacing: 5) {
                Capsule()
                    .fill(SequoiaStyle.accent.opacity(0.74))
                    .frame(width: 22, height: 4)
                Capsule()
                    .fill(SequoiaStyle.aqua.opacity(0.54))
                    .frame(width: 10, height: 4)
                Capsule()
                    .fill(SequoiaStyle.inkMuted.opacity(0.22))
                    .frame(width: 10, height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(SequoiaStyle.materialChrome.opacity(colorScheme == .dark ? 0.8 : 0.64))
                    .overlay(Capsule().stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.55))
            )
        } else if LiquidGlassStyle.isActive {
            HStack(spacing: 5) {
                Capsule()
                    .fill(LiquidGlassStyle.accent.opacity(0.82))
                    .frame(width: 24, height: 4)
                Capsule()
                    .fill(LiquidGlassStyle.cyan.opacity(0.62))
                    .frame(width: 10, height: 4)
                Capsule()
                    .fill(LiquidGlassStyle.violet.opacity(0.42))
                    .frame(width: 10, height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(LiquidGlassStyle.glassChrome.opacity(colorScheme == .dark ? 0.86 : 0.7))
                    .overlay(Capsule().stroke(LiquidGlassStyle.luminousEdge.opacity(0.36), lineWidth: 0.55))
            )
        } else if SignalStyle.isActive {
            HStack(spacing: 5) {
                Capsule()
                    .fill(SignalStyle.accent)
                    .frame(width: 22, height: 4)
                Capsule()
                    .fill(SignalStyle.mint.opacity(0.62))
                    .frame(width: 9, height: 4)
                Capsule()
                    .fill(SignalStyle.inkMuted.opacity(0.24))
                    .frame(width: 9, height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SignalStyle.control.opacity(0.86), in: Capsule())
            .overlay(Capsule().stroke(SignalStyle.separator.opacity(0.56), lineWidth: 0.7))
        } else if BentoStyle.isActive {
            HStack(spacing: 5) {
                Capsule()
                    .fill(BentoStyle.tomato)
                    .frame(width: 20, height: 5)
                Capsule()
                    .fill(BentoStyle.mustard.opacity(0.86))
                    .frame(width: 9, height: 5)
                Capsule()
                    .fill(BentoStyle.matcha.opacity(0.74))
                    .frame(width: 9, height: 5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(BentoStyle.surface.opacity(0.94), in: Capsule())
            .overlay(Capsule().stroke(BentoStyle.hairline.opacity(0.62), lineWidth: 0.7))
        } else {
            Capsule()
                .fill(Color.monologueSheetHandle)
                .frame(width: 42, height: 5)
        }
    }
}

struct MonologueSheetSurfaceBackground: View {
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = MonologueSheetSurfaceShape(
            cornerRadius: cornerRadius,
            attachesToBottom: MonologueSheetThemeStyle.attachesSurfaceToBottom
        )

        ZStack {
            if MangaStyle.isActive {
                shape
                    .fill(MangaStyle.bubbleWhite)

                LinearGradient(
                    colors: [
                        MangaStyle.labelYellow.opacity(colorScheme == .dark ? 0.18 : 0.24),
                        MangaStyle.bubblePink.opacity(colorScheme == .dark ? 0.12 : 0.18),
                        MangaStyle.paperWarm.opacity(colorScheme == .dark ? 0.2 : 0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                MangaDotsTexture(opacity: colorScheme == .dark ? 0.032 : 0.024, gap: 14)
                    .clipShape(shape)
            } else if PetWhiteStyle.isActive {
                shape
                    .fill(PetWhiteStyle.surfaceRaised)

                LinearGradient(
                    colors: [
                        PetWhiteStyle.mint.opacity(colorScheme == .dark ? 0.16 : 0.34),
                        PetWhiteStyle.surfaceRaised.opacity(0.98),
                        PetWhiteStyle.sky.opacity(colorScheme == .dark ? 0.16 : 0.30),
                        PetWhiteStyle.butter.opacity(colorScheme == .dark ? 0.12 : 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                PetWhitePawPattern()
                    .opacity(colorScheme == .dark ? 0.18 : 0.28)
                    .clipShape(shape)
            } else if MujiStyle.isActive {
                shape
                    .fill(MujiStyle.surface)

                LinearGradient(
                    colors: [
                        MujiStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.28 : 0.48),
                        MujiStyle.surface.opacity(0.96),
                        MujiStyle.tea.opacity(colorScheme == .dark ? 0.07 : 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                MujiPaperTexture(opacity: colorScheme == .dark ? 0.12 : 0.16)
                    .clipShape(shape)
            } else if NeumorphicStyle.isActive {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                NeumorphicStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.86 : 0.98),
                                NeumorphicStyle.surface.opacity(0.98),
                                NeumorphicStyle.baseWarm.opacity(colorScheme == .dark ? 0.58 : 0.42),
                                NeumorphicStyle.surfacePressed.opacity(colorScheme == .dark ? 0.74 : 0.48)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                LinearGradient(
                    colors: [
                        NeumorphicStyle.accent.opacity(colorScheme == .dark ? 0.12 : 0.08),
                        .clear,
                        NeumorphicStyle.warm.opacity(colorScheme == .dark ? 0.09 : 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                RadialGradient(
                    colors: [
                        NeumorphicStyle.lightShadow(colorScheme, intensity: colorScheme == .dark ? 0.46 : 0.7),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 260
                )
                .clipShape(shape)

                NeumorphicReliefTexture(opacity: colorScheme == .dark ? 0.045 : 0.06)
                    .clipShape(shape)
            } else if CapsuleStyle.isActive {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.9 : 0.98),
                                CapsuleStyle.surface.opacity(0.96),
                                CapsuleStyle.surfaceTint.opacity(colorScheme == .dark ? 0.74 : 0.62)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                LinearGradient(
                    colors: [
                        CapsuleStyle.accent.opacity(colorScheme == .dark ? 0.14 : 0.1),
                        .clear,
                        CapsuleStyle.cyan.opacity(colorScheme == .dark ? 0.1 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            } else if ClayStyle.isActive {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                ClayStyle.creamRaised.opacity(colorScheme == .dark ? 0.88 : 0.99),
                                ClayStyle.cream.opacity(0.98),
                                ClayStyle.butter.opacity(colorScheme == .dark ? 0.14 : 0.2),
                                ClayStyle.creamPressed.opacity(colorScheme == .dark ? 0.58 : 0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                LinearGradient(
                    colors: [
                        ClayStyle.accent.opacity(colorScheme == .dark ? 0.12 : 0.1),
                        .clear,
                        ClayStyle.mint.opacity(colorScheme == .dark ? 0.1 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            } else if SignalStyle.isActive {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                SignalStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.86 : 0.98),
                                SignalStyle.paper.opacity(0.98),
                                SignalStyle.screen.opacity(colorScheme == .dark ? 0.36 : 0.52)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                LinearGradient(
                    colors: [
                        SignalStyle.accent.opacity(colorScheme == .dark ? 0.14 : 0.12),
                        .clear,
                        SignalStyle.mint.opacity(colorScheme == .dark ? 0.1 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                SignalAmbientTexture(opacity: colorScheme == .dark ? 0.06 : 0.08)
                    .clipShape(shape)
            } else if BentoStyle.isActive {
                shape
                    .fill(BentoStyle.surface)

                LinearGradient(
                    colors: [
                        BentoStyle.paperWarm.opacity(colorScheme == .dark ? 0.22 : 0.42),
                        BentoStyle.surface.opacity(0.98),
                        BentoStyle.mustard.opacity(colorScheme == .dark ? 0.08 : 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            } else if SequoiaStyle.isActive {
                shape
                    .fill(.ultraThinMaterial)

                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                SequoiaStyle.materialFloating.opacity(colorScheme == .dark ? 0.9 : 0.76),
                                SequoiaStyle.materialChrome.opacity(colorScheme == .dark ? 0.78 : 0.62),
                                SequoiaStyle.materialList.opacity(colorScheme == .dark ? 0.58 : 0.5),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                LinearGradient(
                    colors: [
                        SequoiaStyle.highlight(colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.42),
                        .clear,
                        SequoiaStyle.accent.opacity(colorScheme == .dark ? 0.1 : 0.07),
                    ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            } else if LiquidGlassStyle.isActive {
                shape
                    .fill(.ultraThinMaterial)

                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                LiquidGlassStyle.glassFloating.opacity(colorScheme == .dark ? 0.9 : 0.78),
                                LiquidGlassStyle.glassChrome.opacity(colorScheme == .dark ? 0.78 : 0.62),
                                LiquidGlassStyle.glassList.opacity(colorScheme == .dark ? 0.58 : 0.48),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                LinearGradient(
                    colors: [
                        LiquidGlassStyle.highlight(colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.46),
                        .clear,
                        LiquidGlassStyle.accent.opacity(colorScheme == .dark ? 0.11 : 0.08),
                        LiquidGlassStyle.violet.opacity(colorScheme == .dark ? 0.08 : 0.05),
                    ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                LiquidGlassCausticField(opacity: colorScheme == .dark ? 0.04 : 0.06)
                    .clipShape(shape)
            } else if #available(iOS 26, *) {
                Color.clear
            } else {
                shape
                    .fill(
                        LinearGradient(
                            colors: [Color.monologueSheetSurfaceTop, Color.monologueSheetSurfaceBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                shape
                    .fill(
                        RadialGradient(
                            colors: [Color.monologueSheetInnerGlow, .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 280
                        )
                    )
            }
        }
    }
}

struct MonologueSheetSurfaceOverlay: View {
    let cornerRadius: CGFloat
    var isInteractiveMotionActive: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = MonologueSheetSurfaceShape(
            cornerRadius: cornerRadius,
            attachesToBottom: MonologueSheetThemeStyle.attachesSurfaceToBottom
        )

        ZStack(alignment: .top) {
            if MangaStyle.isActive {
                shape
                    .strokeBorder(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)

                if !isInteractiveMotionActive {
                    shape
                        .strokeBorder(MangaStyle.labelYellow.opacity(colorScheme == .dark ? 0.34 : 0.46), lineWidth: 0.8)
                        .padding(4)
                        .clipShape(shape)
                }
            } else if PetWhiteStyle.isActive {
                shape
                    .strokeBorder(PetWhiteStyle.stroke, lineWidth: PetWhiteStyle.strokeWidth)

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.04 : 0.32), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 116)
                    .clipShape(shape)

                    HStack(spacing: 0) {
                        PetWhiteStyle.dogOrange.frame(width: 64, height: 5)
                        PetWhiteStyle.mint.frame(width: 42, height: 5)
                        PetWhiteStyle.sky.frame(width: 38, height: 5)
                        Spacer()
                        PetWhiteStyle.blush.opacity(0.72).frame(width: 46, height: 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(shape)
                }
            } else if MujiStyle.isActive {
                shape
                    .strokeBorder(MujiStyle.hairline.opacity(colorScheme == .dark ? 0.74 : 0.66), lineWidth: 0.75)

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.04 : 0.24), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 96)
                    .clipShape(shape)
                }
            } else if NeumorphicStyle.isActive {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                NeumorphicStyle.lightShadow(colorScheme, intensity: 0.92),
                                NeumorphicStyle.separator.opacity(colorScheme == .dark ? 0.34 : 0.44),
                                NeumorphicStyle.darkShadow(colorScheme, intensity: 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [
                            NeumorphicStyle.lightShadow(colorScheme, intensity: 0.52),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 110)
                    .clipShape(shape)

                    LinearGradient(
                        colors: [
                            .clear,
                            NeumorphicStyle.darkShadow(colorScheme, intensity: 0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(shape)
                }
            } else if CapsuleStyle.isActive {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.hairline.opacity(colorScheme == .dark ? 0.22 : 0.86),
                                CapsuleStyle.separator.opacity(colorScheme == .dark ? 0.54 : 0.58),
                                CapsuleStyle.accent.opacity(colorScheme == .dark ? 0.26 : 0.18),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.28),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 104)
                    .clipShape(shape)

                    HStack(spacing: 0) {
                        CapsuleStyle.accent.frame(width: 78, height: 5)
                        CapsuleStyle.cyan.frame(width: 42, height: 5)
                        CapsuleStyle.violet.frame(width: 48, height: 5)
                        Spacer()
                        CapsuleStyle.mint.frame(width: 58, height: 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(shape)
                }
            } else if ClayStyle.isActive {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                ClayStyle.highlightColor(colorScheme, intensity: 0.9),
                                ClayStyle.separator.opacity(colorScheme == .dark ? 0.34 : 0.46),
                                ClayStyle.shadowColor(colorScheme, intensity: 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.06 : 0.28), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 110)
                    .clipShape(shape)
                }
            } else if SignalStyle.isActive {
                shape
                    .strokeBorder(SignalStyle.separator.opacity(colorScheme == .dark ? 0.72 : 0.66), lineWidth: 0.8)

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.06 : 0.28), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 110)
                    .clipShape(shape)
                }
            } else if BentoStyle.isActive {
                shape
                    .strokeBorder(BentoStyle.hairline.opacity(colorScheme == .dark ? 0.72 : 0.66), lineWidth: 0.8)

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.04 : 0.22), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 96)
                    .clipShape(shape)
                }
            } else if SequoiaStyle.isActive {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.2 : 0.62),
                                SequoiaStyle.separator.opacity(0.86),
                                SequoiaStyle.strongSeparator.opacity(colorScheme == .dark ? 0.34 : 0.22),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.72
                    )

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.055 : 0.32),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 112)
                    .clipShape(shape)
                }
            } else if LiquidGlassStyle.isActive {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LiquidGlassStyle.luminousEdge.opacity(colorScheme == .dark ? 0.24 : 0.74),
                                LiquidGlassStyle.separator.opacity(0.9),
                                LiquidGlassStyle.strongSeparator.opacity(colorScheme == .dark ? 0.36 : 0.26),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.34),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .clipShape(shape)
                }
            } else {
                shape
                    .strokeBorder(Color.monologueSheetStroke, lineWidth: 1)

                if !isInteractiveMotionActive {
                    LinearGradient(
                        colors: [Color.monologueSheetHighlight, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .clipShape(shape)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
