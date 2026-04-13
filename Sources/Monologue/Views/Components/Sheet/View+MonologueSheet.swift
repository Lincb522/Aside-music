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
    let root = VStack(spacing: 0) {
        if preset.showsHandle {
            Capsule()
                .fill(Color.monologueSheetHandle)
                .frame(width: 42, height: 5)
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

    if #available(iOS 16.0, macOS 13.0, *) {
        if #available(iOS 16.4, macOS 13.3, *) {
            root
                .presentationDetents(preset.systemDetents)
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(!preset.allowsDragToDismiss)
                .presentationCornerRadius(preset.cornerRadius)
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
