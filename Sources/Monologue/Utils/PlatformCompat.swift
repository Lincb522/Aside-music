// iOS 类型别名和界面辅助方法

import SwiftUI
import UIKit

public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
public typealias PlatformApplication = UIApplication

// MARK: - PlatformImage → SwiftUI Image

extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}

// MARK: - Screen Size

enum ScreenInfo {
    static var mainScreenSize: CGSize {
        MainActor.assumeIsolated {
            UIScreen.main.bounds.size
        }
    }

    static var mainScreenScale: CGFloat {
        MainActor.assumeIsolated {
            UIScreen.main.scale
        }
    }
}

// MARK: - Haptic Feedback

enum PlatformHaptic {
    static func impact(style: HapticStyle = .medium) {
        MainActor.assumeIsolated {
            let generator: UIImpactFeedbackGenerator
            switch style {
            case .light: generator = UIImpactFeedbackGenerator(style: .light)
            case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
            case .heavy: generator = UIImpactFeedbackGenerator(style: .heavy)
            }
            generator.impactOccurred()
        }
    }

    static func selection() {
        MainActor.assumeIsolated {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    enum HapticStyle {
        case light, medium, heavy
    }
}

// MARK: - Open URL

extension PlatformApplication {
    static func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

// MARK: - Pasteboard

enum PlatformPasteboard {
    static func copy(_ string: String) {
        UIPasteboard.general.string = string
    }
}

// MARK: - Platform Colors

extension Color {
    static var platformBackground: Color {
        Color(UIColor.systemBackground)
    }
}

// MARK: - iOS modifiers

extension View {

    @ViewBuilder
    func monologueFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }

    @ViewBuilder
    func monologueFullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        self.fullScreenCover(item: item, onDismiss: onDismiss, content: content)
    }

    @ViewBuilder
    func monologueNavigationBarTitleDisplayMode() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ToolbarItemPlacement

extension ToolbarItemPlacement {
    static var monologueTopBarLeading: ToolbarItemPlacement {
        .topBarLeading
    }

    static var monologueTopBarTrailing: ToolbarItemPlacement {
        .topBarTrailing
    }
}
