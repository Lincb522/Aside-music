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

                            Capsule()
                                .fill(Color.monologueSheetHandle)
                                .frame(width: 42, height: 5)
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
                .frame(height: panelHeight, alignment: .top)
                .background(panelBackground)
                .clipShape(panelShape)
                .modifier(
                    MonologueSheetLiquidSurfaceModifier(
                        cornerRadius: preset.cornerRadius,
                        isEnabled: !isInteractiveMotionActive
                    )
                )
                .overlay {
                    panelShape
                        .strokeBorder(Color.monologueSheetStroke, lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    if !isInteractiveMotionActive {
                        LinearGradient(
                            colors: [Color.monologueSheetHighlight, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                        .clipShape(panelShape)
                        .allowsHitTesting(false)
                    }
                }
                .shadow(
                    color: Color.monologueSheetShadow,
                    radius: isInteractiveMotionActive ? 10 : (colorScheme == .dark ? 30 : 24),
                    x: 0,
                    y: isInteractiveMotionActive ? 4 : 14
                )
                .padding(.horizontal, preset.horizontalPadding)
                .padding(.bottom, bottomInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .background(Color.clear)
    }

    /// 顶部拖动手势热区高度（与 `resolvedPanelHeight` 中 handle 占位一致）。
    private var sheetTopChromeHeight: CGFloat { 44 }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: preset.cornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26, *), !isInteractiveMotionActive {
            Color.clear
        } else {
            ZStack {
                panelShape
                    .fill(
                        LinearGradient(
                            colors: [Color.monologueSheetSurfaceTop, Color.monologueSheetSurfaceBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                panelShape
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
