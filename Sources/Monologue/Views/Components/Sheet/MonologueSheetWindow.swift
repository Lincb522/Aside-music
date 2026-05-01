import SwiftUI
import Combine

@MainActor
final class MonologueSheetWindow {
    static let shared = MonologueSheetWindow()

    private var window: MonologueSheetPassthroughWindow?
    private var cancellable: AnyCancellable?

    private init() {}

    func setup() {
        guard window == nil, let windowScene = preferredWindowScene() else { return }

        let overlayWindow = MonologueSheetPassthroughWindow(windowScene: windowScene)
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: MonologueSheetWindowContent())
        hostingController.view.backgroundColor = .clear
        overlayWindow.rootViewController = hostingController
        overlayWindow.isHidden = false

        window = overlayWindow

        cancellable = MonologueSheetManager.shared.$entries
            .receive(on: RunLoop.main)
            .sink { [weak overlayWindow] entries in
                overlayWindow?.sheetActive = !entries.isEmpty
            }

        overlayWindow.sheetActive = MonologueSheetManager.shared.hasActiveSheet
    }

    private func preferredWindowScene() -> UIWindowScene? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication }

        return windowScenes.first(where: { $0.activationState == .foregroundActive })
            ?? windowScenes.first
    }
}

private final class MonologueSheetPassthroughWindow: UIWindow {
    var sheetActive = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard sheetActive else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct MonologueSheetWindowContent: View {
    @ObservedObject private var sheetManager = MonologueSheetManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ZStack {
            ForEach(Array(sheetManager.entries.enumerated()), id: \.element.id) { index, entry in
                MonologuePresentedSheetView(
                    entry: entry,
                    isTopmost: index == sheetManager.entries.count - 1
                )
                .zIndex(Double(index))
            }
        }
        .environment(\.themeRenderContext, sheetRenderContext)
        .environment(\.themeCustomizationRevision, settings.globalThemeRevision)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var sheetRenderContext: ThemeRenderContext {
        ThemeRenderContext(
            theme: settings.globalThemeId,
            revision: settings.globalThemeRevision,
            colorScheme: settings.activeColorScheme,
            isHosted: true
        )
    }
}

private struct MonologuePresentedSheetView: View {
    let entry: MonologueSheetEntry
    let isTopmost: Bool

    @StateObject private var dragCoordinator = MonologueSheetDragCoordinator()
    @Environment(\.themeCustomizationRevision) private var themeRevision

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black
                    .opacity(isTopmost && entry.isVisible ? entry.preset.backdropOpacity : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .allowsHitTesting(isTopmost && entry.isVisible && entry.preset.allowsBackgroundDismiss)
                    .onTapGesture(perform: dismissFromBackground)

                MonologueSheetContainer(
                    preset: entry.preset,
                    stretchAmount: upwardStretchAmount,
                    dragCoordinator: activeDragCoordinator,
                    isInteractiveMotionActive: isInteractiveMotionActive
                ) {
                    MonologueStaticSheetContentHost(
                        version: entry.contentVersion,
                        themeRevision: themeRevision,
                        content: entry.content
                    )
                    .equatable()
                }
                .offset(y: combinedOffset(for: proxy.size.height))
                .animation(nil, value: dragCoordinator.translation)
                .animation(nil, value: dragCoordinator.dismissalBaseline)
                .opacity(isTopmost ? 1 : 0.001)
                .scaleEffect(isTopmost ? 1 : 0.985, anchor: .bottom)
                .allowsHitTesting(isTopmost && entry.isVisible)
                .accessibilityHidden(!isTopmost)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(MonologueSheetAnimation.present, value: entry.isVisible)
        .animation(MonologueSheetAnimation.present, value: isTopmost)
        .onAppear(perform: syncDragCoordinator)
        .onChange(of: entry.id) { _, _ in syncDragCoordinator() }
        .onChange(of: isTopmost) { _, _ in syncDragCoordinator() }
        .onChange(of: entry.isVisible) { _, _ in
            if !entry.isVisible {
                dragCoordinator.clearTranslationForVisibilityHide()
            }
            syncDragCoordinator()
        }
    }

    private func combinedOffset(for containerHeight: CGFloat) -> CGFloat {
        let drag = max(0, dragCoordinator.translation)
        let dismissalBaseline = max(0, dragCoordinator.dismissalBaseline)
        let visibility: CGFloat = entry.isVisible ? 0 : containerHeight + 80
        return entry.isVisible ? drag : max(drag, dismissalBaseline) + visibility
    }

    private var upwardStretchAmount: CGFloat {
        max(0, -dragCoordinator.translation)
    }

    private var isInteractiveMotionActive: Bool {
        max(abs(dragCoordinator.translation), abs(dragCoordinator.dismissalBaseline)) > 0.5
    }

    /// 不检查 isVisible，避免 dismiss 时环境值切换导致 glass effect 内容树重建闪烁。
    /// 协调器内部已自行判断 isVisible，不会处理 dismiss 后的手势。
    private var activeDragCoordinator: MonologueSheetDragCoordinator? {
        guard isTopmost, entry.preset.allowsDragToDismiss else { return nil }
        return dragCoordinator
    }

    private func syncDragCoordinator() {
        dragCoordinator.sync(
            isTopmost: isTopmost,
            isVisible: entry.isVisible,
            allowsDragToDismiss: entry.preset.allowsDragToDismiss,
            requestDismiss: entry.requestDismiss
        )
    }

    private func dismissFromBackground() {
        guard isTopmost, entry.preset.allowsBackgroundDismiss else { return }
        entry.requestDismiss()
    }
}

private struct MonologueStaticSheetContentHost: View, Equatable {
    let version: Int
    let themeRevision: Int
    let content: AnyView

    nonisolated static func == (lhs: MonologueStaticSheetContentHost, rhs: MonologueStaticSheetContentHost) -> Bool {
        lhs.version == rhs.version && lhs.themeRevision == rhs.themeRevision
    }

    var body: some View {
        content
    }
}
