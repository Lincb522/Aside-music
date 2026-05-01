// PlatformCompat.swift
// Monologue
//
// 跨平台类型别名和兼容层，支持 iOS / macOS 共享代码

import SwiftUI

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
public typealias PlatformApplication = UIApplication
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
public typealias PlatformApplication = NSApplication
#endif

// MARK: - PlatformImage → SwiftUI Image

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

// MARK: - PlatformImage Helpers

extension PlatformImage {
    #if os(macOS)
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    func jpegData(compressionQuality: CGFloat = 0.8) -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }

    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    #endif
}

// MARK: - PlatformColor Helpers

extension PlatformColor {
    #if os(macOS)
    convenience init(dynamicProvider: @escaping (NSAppearance?) -> NSColor) {
        self.init(name: nil, dynamicProvider: { appearance in
            dynamicProvider(appearance)
        })
    }
    #endif
}

// MARK: - Screen Size

enum ScreenInfo {
    static var mainScreenSize: CGSize {
        #if os(iOS)
        MainActor.assumeIsolated {
            UIScreen.main.bounds.size
        }
        #elseif os(macOS)
        NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
        #endif
    }

    static var mainScreenScale: CGFloat {
        #if os(iOS)
        MainActor.assumeIsolated {
            UIScreen.main.scale
        }
        #elseif os(macOS)
        NSScreen.main?.backingScaleFactor ?? 2.0
        #endif
    }
}

// MARK: - Haptic Feedback

enum PlatformHaptic {
    static func impact(style: HapticStyle = .medium) {
        #if os(iOS)
        MainActor.assumeIsolated {
            let generator: UIImpactFeedbackGenerator
            switch style {
            case .light: generator = UIImpactFeedbackGenerator(style: .light)
            case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
            case .heavy: generator = UIImpactFeedbackGenerator(style: .heavy)
            }
            generator.impactOccurred()
        }
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }

    static func selection() {
        #if os(iOS)
        MainActor.assumeIsolated {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #endif
    }

    enum HapticStyle {
        case light, medium, heavy
    }
}

// MARK: - Open URL

extension PlatformApplication {
    static func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - NSBezierPath cgPath

#if os(macOS)
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let element = self.element(at: i, associatedPoints: &points)
            switch element {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            case .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
            @unknown default: break
            }
        }
        return path
    }
}
#endif

// MARK: - Pasteboard

enum PlatformPasteboard {
    static func copy(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}

// MARK: - Platform Colors

extension Color {
    static var platformBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #elseif os(macOS)
        Color(NSColor.windowBackgroundColor)
        #endif
    }
}

// MARK: - Cross-platform modifiers

extension View {

    // MARK: fullScreenCover → sheet on macOS

    @ViewBuilder
    func monologueFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #elseif os(macOS)
        self.monologueSheet(isPresented: isPresented, onDismiss: onDismiss, preset: .detail, content: content)
        #endif
    }

    @ViewBuilder
    func monologueFullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #elseif os(macOS)
        self.monologueSheet(item: item, onDismiss: onDismiss, preset: .detail, content: content)
        #endif
    }

    // MARK: navigationBarTitleDisplayMode (no-op on macOS)

    @ViewBuilder
    func monologueNavigationBarTitleDisplayMode() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - Cross-platform ToolbarItemPlacement

extension ToolbarItemPlacement {
    static var monologueTopBarLeading: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }

    static var monologueTopBarTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}
