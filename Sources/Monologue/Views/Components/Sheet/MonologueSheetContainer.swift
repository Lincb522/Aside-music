import SwiftUI

struct MonologueSheetContainer<Content: View>: View {
    let preset: MonologueSheetPreset
    let stretchAmount: CGFloat
    let dragCoordinator: MonologueSheetDragCoordinator?
    let isInteractiveMotionActive: Bool
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

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
        MangaStyle.isActive || MujiStyle.isActive
    }

    static var attachesSurfaceToBottom: Bool {
        MangaStyle.isActive || MujiStyle.isActive
    }

    static var shadowColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink.opacity(0.22) }
        if MujiStyle.isActive { return Color.black.opacity(0.07) }
        return Color.monologueSheetShadow
    }

    static func shadowRadius(colorScheme: ColorScheme, isInteractiveMotionActive: Bool) -> CGFloat {
        if isInteractiveMotionActive { return usesCustomThemeSurface ? 8 : 10 }
        if MangaStyle.isActive { return 0 }
        if MujiStyle.isActive { return 18 }
        return colorScheme == .dark ? 30 : 24
    }

    static func shadowYOffset(isInteractiveMotionActive: Bool) -> CGFloat {
        if isInteractiveMotionActive { return usesCustomThemeSurface ? 3 : 4 }
        if MangaStyle.isActive { return 5 }
        if MujiStyle.isActive { return 9 }
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
    var body: some View {
        if MangaStyle.isActive {
            Capsule()
                .fill(MangaStyle.labelYellow)
                .frame(width: 48, height: 7)
                .overlay(
                    Capsule()
                        .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                )
        } else if MujiStyle.isActive {
            Capsule()
                .fill(MujiStyle.hairline.opacity(0.78))
                .frame(width: 38, height: 4)
                .overlay(
                    Capsule()
                        .stroke(MujiStyle.surface.opacity(0.65), lineWidth: 0.5)
                )
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
            } else if MujiStyle.isActive {
                shape
                    .fill(MujiStyle.surface)

                LinearGradient(
                    colors: [
                        MujiStyle.paperWarm.opacity(colorScheme == .dark ? 0.28 : 0.48),
                        MujiStyle.surface.opacity(0.96),
                        MujiStyle.tea.opacity(colorScheme == .dark ? 0.07 : 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                MujiPaperTexture(opacity: colorScheme == .dark ? 0.12 : 0.16)
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
