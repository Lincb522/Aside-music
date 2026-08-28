import PhotosUI
import SwiftUI

struct SettingsDisclosureReveal<Content: View>: View {
    let isExpanded: Bool
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var measuredHeight: CGFloat = 0

    private var targetHeight: CGFloat {
        isExpanded ? measuredHeight : 0
    }

    private var revealAnimation: Animation {
        if reduceMotion {
            return .linear(duration: 0.01)
        }
        return .easeInOut(duration: 0.22)
    }

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .opacity(isExpanded ? 1 : 0)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateMeasuredHeight(proxy.size.height) }
                        .onChange(of: proxy.size.height) { _, newValue in
                            updateMeasuredHeight(newValue)
                        }
                }
            }
            .frame(height: targetHeight, alignment: .top)
            .clipped()
            .contentShape(Rectangle())
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
            .animation(revealAnimation, value: isExpanded)
    }

    private func updateMeasuredHeight(_ height: CGFloat) {
        guard height > 0, abs(measuredHeight - height) > 0.5 else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            measuredHeight = height
        }
    }
}
