import SwiftUI

extension View {
    /// 带主题化外观的系统 sheet 封装（isPresented 版本）；内部注入统一的把手、圆角与 dismiss 环境值。
    func monoSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        preset: MonoSheetPreset = .standard,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            monoSystemSheetContent(
                preset: preset,
                dismissAction: MonoSheetDismissAction {
                    guard isPresented.wrappedValue else { return }
                    isPresented.wrappedValue = false
                },
                content: content
            )
        }
    }

    /// 同上，item 驱动版本。
    func monoSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        preset: MonoSheetPreset = .standard,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { presentedItem in
            monoSystemSheetContent(
                preset: preset,
                dismissAction: MonoSheetDismissAction {
                    guard item.wrappedValue != nil else { return }
                    item.wrappedValue = nil
                },
                content: {
                    content(presentedItem)
                }
            )
        }
    }
}

/// 组装 sheet 内容：把手 + 内容 + 主题自定义背景/描边；
/// iOS 16.4+ 优先用 presentationBackground 承载主题背景，旧系统回退到 backgroundPreferenceValue 方案。
@ViewBuilder
private func monoSystemSheetContent<SheetContent: View>(
    preset: MonoSheetPreset,
    dismissAction: MonoSheetDismissAction,
    @ViewBuilder content: () -> SheetContent
) -> some View {
    let attachesToBottom = MonoSheetThemeStyle.attachesSurfaceToBottom
    let root = VStack(spacing: 0) {
        if preset.showsHandle {
            MonoSheetHandleView()
                .padding(.top, 12)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }

        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    .environment(\.monoSheetContext, MonoSheetContext(preset: preset))
    .environment(\.monoSheetDismiss, dismissAction)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .backgroundPreferenceValue(MonoSheetSurfacePreferenceKey.self) { customSurface in
        ZStack {
            if let customSurface {
                customSurface.view
            } else if MonoSheetThemeStyle.usesCustomThemeSurface && !supportsPresentationBackground {
                monoSheetBottomAttachedSurface(
                    MonoSheetSurfaceBackground(cornerRadius: preset.monoResolvedCornerRadius),
                    attachesToBottom: attachesToBottom
                )
            }
        }
    }
    .overlay {
        if MonoSheetThemeStyle.usesCustomThemeSurface {
            monoSheetBottomAttachedSurface(
                MonoSheetSurfaceOverlay(cornerRadius: preset.monoResolvedCornerRadius),
                attachesToBottom: attachesToBottom
            )
        }
    }

    if #available(iOS 16.0, *) {
        if #available(iOS 16.4, *) {
            if MonoSheetThemeStyle.usesCustomThemeSurface {
                root
                    .presentationDetents(preset.systemDetents)
                    .presentationBackground {
                        monoSheetBottomAttachedSurface(
                            MonoSheetSurfaceBackground(cornerRadius: preset.monoResolvedCornerRadius),
                            attachesToBottom: attachesToBottom
                        )
                    }
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled(!preset.allowsDragToDismiss)
                    .compatPresentationCornerRadius(preset.monoResolvedCornerRadius)
            } else {
                root
                    .presentationDetents(preset.systemDetents)
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled(!preset.allowsDragToDismiss)
                    .compatPresentationCornerRadius(preset.cornerRadius)
            }
        } else {
            root
                .presentationDetents(preset.systemDetents)
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(!preset.allowsDragToDismiss)
        }
    } else {
        root
    }
}

private var supportsPresentationBackground: Bool {
    if #available(iOS 16.4, *) {
        return true
    }
    return false
}

@ViewBuilder
private func monoSheetBottomAttachedSurface<Content: View>(
    _ content: Content,
    attachesToBottom: Bool
) -> some View {
    if attachesToBottom {
        content.ignoresSafeArea(edges: .bottom)
    } else {
        content
    }
}
