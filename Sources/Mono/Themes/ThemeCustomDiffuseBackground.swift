import Foundation
import SwiftUI
import UIKit

struct ThemeCustomDiffuseBackground: View {
    let theme: GlobalThemeId
    let fallbackHexes: [String]
    var accentFallbackHexes: [String] = []
    var opacity: Double = 1
    var colorsOverride: [Color]? = nil
    var accentColorsOverride: [Color]? = nil
    var gradientStyleOverride: ThemeCustomGradientStyle? = nil

    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        let colors = colorsOverride
            ?? ThemeColorCustomization.backgroundGradientColors(
                for: theme,
                fallbackHexes: fallbackHexes
            )
        let accentColors = accentColorsOverride
            ?? ThemeColorCustomization.accentGradientColors(
                for: theme,
                fallback: accentFallbackHexes.map { Color(hex: $0) },
                fallbackHexes: accentFallbackHexes
            )
        let style = gradientStyleOverride
            ?? ThemeColorCustomization.gradientStyle(for: theme, role: .background)
        let points = style.points

        GeometryReader { proxy in
            ZStack {
                baseLayer(colors: colors, style: style, size: proxy.size, points: points)

                if theme != .muji {
                    accentLayer(colors: colors, accentColors: accentColors, style: style, size: proxy.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func baseLayer(colors: [Color], style: ThemeCustomGradientStyle, size: CGSize, points: (start: UnitPoint, end: UnitPoint)) -> some View {
        if colors.count == 1 {
            colors[0]
        } else if style == .radial {
            RadialGradient(
                colors: colors,
                center: .center,
                startRadius: max(size.width, size.height) * 0.04,
                endRadius: max(size.width, size.height) * 0.78
            )
        } else if style == .conic {
            AngularGradient(
                gradient: Gradient(colors: colors + [colors.first ?? .clear]),
                center: .center,
                angle: .degrees(-35)
            )
        } else if style == .mesh {
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas(rendersAsynchronously: true) { context, _ in
                    let width = max(size.width, 1)
                    let height = max(size.height, 1)
                    drawGlow(context, center: CGPoint(x: width * 0.18, y: height * 0.16), radius: width * 0.52, color: colors.first ?? .clear, opacity: 0.24 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.82, y: height * 0.22), radius: width * 0.48, color: colors.dropFirst().first ?? colors.first ?? .clear, opacity: 0.2 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.28, y: height * 0.82), radius: width * 0.56, color: colors.dropFirst(2).first ?? colors.last ?? .clear, opacity: 0.18 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.9, y: height * 0.78), radius: width * 0.5, color: colors.dropFirst(3).first ?? colors.last ?? .clear, opacity: 0.16 * opacity)
                }
                .blur(radius: 38)
                .blendMode(.softLight)
            }
        } else {
            LinearGradient(colors: colors, startPoint: points.start, endPoint: points.end)
        }
    }

    @ViewBuilder
    private func accentLayer(colors: [Color], accentColors: [Color], style: ThemeCustomGradientStyle, size: CGSize) -> some View {
        let firstAccent = accentColors.first ?? colors.first ?? .clear
        let secondAccent = accentColors.dropFirst().first ?? colors.last ?? firstAccent
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        Group {
            if style == .diffuse && theme != .neumorphic {
                Canvas(rendersAsynchronously: true) { context, _ in
                    drawGlow(context, center: CGPoint(x: width * 0.16, y: height * 0.12), radius: width * 0.58, color: firstAccent, opacity: 0.18 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.88, y: height * 0.36), radius: width * 0.52, color: secondAccent, opacity: 0.14 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.42, y: height * 0.86), radius: width * 0.62, color: colors.last ?? secondAccent, opacity: 0.12 * opacity)
                }
                .blur(radius: 44)
                .blendMode(.softLight)
            } else if theme == .neumorphic {
                LinearGradient(
                    colors: [
                        firstAccent.opacity(0.12 * opacity),
                        .clear,
                        secondAccent.opacity(0.1 * opacity),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        firstAccent.opacity(0.15 * opacity),
                        .clear,
                        secondAccent.opacity((style == .radial || style == .conic || style == .mesh ? 0.2 : 0.12) * opacity),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.softLight)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private func drawGlow(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), color.opacity(0)]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
}
