import SwiftUI

extension View {
    func monologueSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        preset: MonologueSheetPreset = .standard,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            monologueSystemSheetContent(
                preset: preset,
                dismissAction: MonologueSheetDismissAction {
                    guard isPresented.wrappedValue else { return }
                    isPresented.wrappedValue = false
                },
                content: content
            )
        }
    }

    func monologueSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        preset: MonologueSheetPreset = .standard,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { presentedItem in
            monologueSystemSheetContent(
                preset: preset,
                dismissAction: MonologueSheetDismissAction {
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

@ViewBuilder
private func monologueSystemSheetContent<SheetContent: View>(
    preset: MonologueSheetPreset,
    dismissAction: MonologueSheetDismissAction,
    @ViewBuilder content: () -> SheetContent
) -> some View {
    let attachesToBottom = MonologueSheetThemeStyle.attachesSurfaceToBottom
    let root = VStack(spacing: 0) {
        if preset.showsHandle {
            MonologueSheetHandleView()
                .padding(.top, 12)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }

        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    .environment(\.monologueSheetContext, MonologueSheetContext(preset: preset))
    .environment(\.monologueSheetDismiss, dismissAction)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .backgroundPreferenceValue(MonologueSheetSurfacePreferenceKey.self) { customSurface in
        ZStack {
            if let customSurface {
                customSurface.view
            } else if MonologueSheetThemeStyle.usesCustomThemeSurface && !supportsPresentationBackground {
                monologueSheetBottomAttachedSurface(
                    MonologueSheetSurfaceBackground(cornerRadius: preset.monologueResolvedCornerRadius),
                    attachesToBottom: attachesToBottom
                )
            }
        }
    }
    .overlay {
        if MonologueSheetThemeStyle.usesCustomThemeSurface {
            monologueSheetBottomAttachedSurface(
                MonologueSheetSurfaceOverlay(cornerRadius: preset.monologueResolvedCornerRadius),
                attachesToBottom: attachesToBottom
            )
        }
    }

    if #available(iOS 16.0, *) {
        if #available(iOS 16.4, *) {
            if MonologueSheetThemeStyle.usesCustomThemeSurface {
                root
                    .presentationDetents(preset.systemDetents)
                    .presentationBackground {
                        monologueSheetBottomAttachedSurface(
                            MonologueSheetSurfaceBackground(cornerRadius: preset.monologueResolvedCornerRadius),
                            attachesToBottom: attachesToBottom
                        )
                    }
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled(!preset.allowsDragToDismiss)
                    .compatPresentationCornerRadius(preset.monologueResolvedCornerRadius)
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
private func monologueSheetBottomAttachedSurface<Content: View>(
    _ content: Content,
    attachesToBottom: Bool
) -> some View {
    if attachesToBottom {
        content.ignoresSafeArea(edges: .bottom)
    } else {
        content
    }
}
