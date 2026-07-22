import SwiftUI

// MARK: - Cover identity

/// The visual language for the rebuilt comic theme. These colors deliberately
/// stay print-like in both system appearances; the theme is an illustrated
/// magazine cover rather than a light/dark recoloring of the default UI.
enum MangaComicPalette {
    static let ink = Color(hex: "090909")
    static let paper = Color(hex: "F5EDDE")
    static let paperWarm = Color(hex: "EEE0CA")
    static let paperShadow = Color(hex: "D9C5A7")
    static let red = Color(hex: "D94A36")
    static let redDeep = Color(hex: "A92720")
    static let navy = Color(hex: "14233D")
    static let violet = Color(hex: "211733")
    static let mutedInk = Color(hex: "5E554C")
    static let whiteInk = Color(hex: "FFF9EC")
    static let gold = Color(hex: "F4C969")

    static func displayFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func headlineFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Foundational shapes

/// A slightly misregistered panel outline. The uneven corners are intentional:
/// regular rounded rectangles make this theme look like the default app in a costume.
struct MangaComicPanelShape: Shape {
    var corner: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let c = min(corner, min(rect.width, rect.height) * 0.22)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + c + 2, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX - c - 4, y: rect.minY + 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 1, y: rect.minY + c + 3),
            control: CGPoint(x: rect.maxX - 1, y: rect.minY + 1)
        )
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - c - 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - c - 2, y: rect.maxY - 1),
            control: CGPoint(x: rect.maxX - 2, y: rect.maxY - 1)
        )
        path.addLine(to: CGPoint(x: rect.minX + c + 1, y: rect.maxY - 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 1, y: rect.maxY - c - 4),
            control: CGPoint(x: rect.minX + 1, y: rect.maxY - 2)
        )
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.minY + c + 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + c + 2, y: rect.minY + 1),
            control: CGPoint(x: rect.minX + 2, y: rect.minY + 1)
        )
        path.closeSubpath()
        return path
    }
}

/// The diagonal paper sheet across the black status/header field.
struct MangaComicMastheadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.31))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 5))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Cut-paper tile used by the masthead actions and selected bottom tab.
struct MangaComicCutCornerShape: Shape {
    var cut: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) * 0.18)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + c, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX - c * 0.55, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - c * 0.6))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.minX + c * 0.55, y: rect.maxY - 2))
        path.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.minY + c * 0.6))
        path.closeSubpath()
        return path
    }
}

/// Hand-cut caption ribbon with the folded point visible in the reference.
struct MangaComicRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tail = min(13, rect.height * 0.34)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tail, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 7))
        path.addLine(to: CGPoint(x: rect.minX + tail, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + tail + 3, y: rect.maxY - 9))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 8))
        path.addLine(to: CGPoint(x: rect.minX + 8, y: rect.maxY * 0.52))
        path.closeSubpath()
        return path
    }
}

struct MangaComicBurstShape: Shape {
    var points: Int = 14
    var innerRatio: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        guard points > 2 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) * 0.5
        let inner = outer * innerRatio
        let count = points * 2
        var path = Path()

        for index in 0 ..< count {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * (.pi * 2 / CGFloat(count))
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct MangaComicFourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.midY - rect.height * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.midY + rect.height * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.midY + rect.height * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.midY - rect.height * 0.12))
        path.closeSubpath()
        return path
    }
}

struct MangaComicLightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.57))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.32))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.38))
        path.closeSubpath()
        return path
    }
}

// MARK: - Print textures

struct MangaComicPaperTexture: View {
    var ink: Color = MangaComicPalette.redDeep
    var opacity: Double = 0.12

    var body: some View {
        Canvas { context, size in
            let fleckCount = max(70, Int(size.width * size.height / 1300))
            for index in 0 ..< fleckCount {
                let x = CGFloat((index * 83 + 17) % 997) / 997 * size.width
                let y = CGFloat((index * 137 + 29) % 991) / 991 * size.height
                let length = CGFloat(index % 4 + 1) * 1.25
                var mark = Path()
                mark.move(to: CGPoint(x: x, y: y))
                mark.addLine(to: CGPoint(x: x + length, y: y - length * 0.42))
                context.stroke(mark, with: .color(ink.opacity(opacity * (index.isMultiple(of: 5) ? 1 : 0.55))), lineWidth: index.isMultiple(of: 7) ? 1.4 : 0.75)
            }

            for index in 0 ..< 38 {
                let x = CGFloat((index * 113 + 41) % 977) / 977 * size.width
                let y = CGFloat((index * 191 + 11) % 983) / 983 * size.height
                let side = CGFloat(index % 3 + 1) * 0.8
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)),
                    with: .color(ink.opacity(opacity * 0.7))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MangaComicHalftone: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.13
    var gap: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            var row = 0
            var y: CGFloat = gap / 2
            while y < size.height + gap {
                var x: CGFloat = row.isMultiple(of: 2) ? gap / 2 : gap
                while x < size.width + gap {
                    let progress = min(1, max(0, (x + y) / max(1, size.width + size.height)))
                    let side = 1.2 + (1 - progress) * 1.6
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)),
                        with: .color(color.opacity(opacity))
                    )
                    x += gap
                }
                row += 1
                y += gap
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MangaComicSpeedLines: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.18

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width * 0.82, y: size.height * 0.28)
            for index in 0 ..< 24 {
                let edgeProgress = CGFloat(index) / 23
                let target: CGPoint
                if index.isMultiple(of: 2) {
                    target = CGPoint(x: 0, y: edgeProgress * size.height)
                } else {
                    target = CGPoint(x: edgeProgress * size.width, y: size.height)
                }
                var line = Path()
                let inset = CGFloat(index % 4) * 8
                line.move(to: CGPoint(x: origin.x + (target.x - origin.x) * 0.16 + inset, y: origin.y + (target.y - origin.y) * 0.16))
                line.addLine(to: target)
                context.stroke(line, with: .color(color.opacity(opacity * (index.isMultiple(of: 3) ? 1 : 0.48))), lineWidth: index.isMultiple(of: 5) ? 1.5 : 0.7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MangaComicAvatarBurst: View {
    var body: some View {
        Image("MangaAvatarBurst")
            .resizable()
            .scaledToFit()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Reusable cover components

struct MangaComicPanel<Content: View>: View {
    var fill: Color = MangaComicPalette.paper
    var corner: CGFloat = 14
    var shadow: CGFloat = 4
    var innerBorder = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = MangaComicPanelShape(corner: corner)

        ZStack {
            shape
                .fill(MangaComicPalette.ink)
                .offset(x: shadow, y: shadow)

            shape.fill(fill)

            content()
                .clipShape(shape)

            MangaComicPaperTexture(opacity: fill == MangaComicPalette.ink ? 0.02 : 0.08)
                .clipShape(shape)

            shape.stroke(MangaComicPalette.ink, lineWidth: 3.2)

            if innerBorder {
                shape
                    .stroke(fill == MangaComicPalette.ink ? MangaComicPalette.paper : MangaComicPalette.ink, lineWidth: 1.15)
                    .padding(6)
            }
        }
    }
}

struct MangaComicRibbon: View {
    let text: String
    var fill: Color = MangaComicPalette.red
    var foreground: Color = MangaComicPalette.whiteInk
    var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .font(MangaComicPalette.headlineFont(15 * scale))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.leading, 18 * scale)
            .padding(.trailing, 14 * scale)
            .padding(.vertical, 7 * scale)
            .background(MangaComicRibbonShape().fill(fill))
            .overlay(MangaComicRibbonShape().stroke(MangaComicPalette.ink, lineWidth: 2.2))
            .background(
                MangaComicRibbonShape()
                    .fill(MangaComicPalette.ink)
                    .offset(x: 2.5, y: 2.5)
            )
            .rotationEffect(.degrees(-2), anchor: .leading)
    }
}

struct MangaComicSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                MangaComicBurstShape(points: 12, innerRatio: 0.62)
                    .fill(MangaComicPalette.red)
                    .overlay(MangaComicBurstShape(points: 12, innerRatio: 0.62).stroke(MangaComicPalette.ink, lineWidth: 2.3))
                MonologueIcon(icon: .like, size: 17, color: MangaComicPalette.ink, lineWidth: 2.2)
            }
            .frame(width: 43, height: 43)

            Text(title)
                .font(MangaComicPalette.displayFont(25))
                .foregroundStyle(MangaComicPalette.ink)
                .lineLimit(1)

            Rectangle()
                .fill(MangaComicPalette.ink)
                .frame(height: 3)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(MangaComicPalette.red)
                        .frame(height: 1)
                        .offset(y: -3)
                }

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(MangaComicPalette.headlineFont(12))
                        MonologueIcon(icon: .chevronRight, size: 9, color: MangaComicPalette.whiteInk, lineWidth: 2)
                    }
                    .foregroundStyle(MangaComicPalette.whiteInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(MangaComicCutCornerShape(cut: 7).fill(MangaComicPalette.red))
                    .overlay(MangaComicCutCornerShape(cut: 7).stroke(MangaComicPalette.ink, lineWidth: 2))
                    .background(MangaComicCutCornerShape(cut: 7).fill(MangaComicPalette.ink).offset(x: 2, y: 2))
                }
                .buttonStyle(MangaComicPressButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(minHeight: 52)
    }
}

struct MangaComicRoundControl: View {
    let icon: MonologueIcon.IconType
    var fill: Color = MangaComicPalette.red
    var foreground: Color = MangaComicPalette.whiteInk
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle()
                .fill(MangaComicPalette.ink)
                .offset(x: 2.5, y: 2.5)
            Circle().fill(fill)
            Circle().stroke(MangaComicPalette.ink, lineWidth: 2.7)
            Circle().stroke(foreground.opacity(0.65), lineWidth: 1).padding(5)
            MonologueIcon(icon: icon, size: size * 0.34, color: foreground, lineWidth: 2.4)
        }
        .frame(width: size, height: size)
    }
}

struct MangaComicPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -0.4 : 0))
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
    }
}
