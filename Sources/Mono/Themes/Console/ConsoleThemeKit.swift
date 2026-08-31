import SwiftUI

enum SignalStyle {
    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .signal
    }

    static var base: Color {
        Color(hex: "07090C")
    }

    static var accent: Color {
        Color(hex: "5AD68C")
    }

    static let baseWarm = Color(hex: "090C10")
    static let surface = Color(hex: "0F1318")
    static let surfaceRaised = Color(hex: "151A20")
    static let surfaceInset = Color(hex: "090C10")
    static let control = Color(hex: "171C22")
    static let controlPressed = Color(hex: "0B0F13")
    static let paper = Color(hex: "0D1116")
    static let screen = Color(hex: "090C10")
    static let separator = Color(hex: "293039")
    static let ink = Color(hex: "F4F6F5")
    static let inkSoft = Color(hex: "A9B0AD")
    static let inkMuted = Color(hex: "69716D")
    static let onAccent = Color(hex: "07120B")
    static let red = Color(hex: "ED7180")
    static let aqua = Color(hex: "78CFA2")
    static let mint = Color(hex: "42B976")
    static let moss = Color(hex: "789180")
    static let clay = Color(hex: "AEB5B1")
    static let lavender = Color(hex: "8993A0")
    static let amber = Color(hex: "C1A567")

    static let device = surface
    static let deviceRaised = surfaceRaised
    static let paperInk = ink
    static let paperMeta = inkSoft
    static let olive = moss
    static let rust = clay
    static let violet = lavender

    static let cardRadius: CGFloat = 14
    static let compactRadius: CGFloat = 10
    static let buttonRadius: CGFloat = 12

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func darkShadow(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        Color.black.opacity(0.72 * intensity)
    }

    static func lightShadow(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        Color.white.opacity(0.025 * intensity)
    }

    static func hardShadow(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        darkShadow(scheme, intensity: intensity * 0.58)
    }
}

struct SignalRootBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SignalStyle.baseWarm, SignalStyle.base, Color(hex: "05070A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            SignalBreathingGlow()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.018),
                    .clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

struct SignalRenderBackdrop: View {
    var body: some View {
        SignalRootBackdrop()
    }
}

struct SignalAmbientTexture: View {
    var opacity: Double = 0.2

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Circle()
                    .fill(SignalStyle.accent.opacity(opacity * 0.18))
                    .frame(width: size.width * 0.72, height: size.width * 0.72)
                    .blur(radius: 54)
                    .offset(x: -size.width * 0.34, y: -size.height * 0.26)

                Circle()
                    .fill(Color.white.opacity(opacity * 0.08))
                    .frame(width: size.width * 0.62, height: size.width * 0.62)
                    .blur(radius: 58)
                    .offset(x: size.width * 0.38, y: -size.height * 0.06)

                Circle()
                    .fill(SignalStyle.accent.opacity(opacity * 0.08))
                    .frame(width: size.width * 0.52, height: size.width * 0.52)
                    .blur(radius: 62)
                    .offset(x: size.width * 0.02, y: size.height * 0.38)
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
    }
}

struct SignalSoftPulseTexture: View {
    var opacity: Double = 0.14
    var lineOpacity: Double = 0.1

    var body: some View {
        SignalAmbientTexture(opacity: opacity + lineOpacity * 0.35)
    }
}

private struct SignalBreathingGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBright = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(SignalStyle.accent.opacity(isBright ? 0.045 : 0.018))
                    .frame(width: proxy.size.width * 0.72, height: proxy.size.width * 0.72)
                    .blur(radius: 72)
                    .scaleEffect(isBright ? 1.08 : 0.82)
                    .offset(x: proxy.size.width * 0.34, y: -proxy.size.height * 0.24)

                Circle()
                    .fill(Color.white.opacity(isBright ? 0.018 : 0.006))
                    .frame(width: proxy.size.width * 0.58, height: proxy.size.width * 0.58)
                    .blur(radius: 76)
                    .scaleEffect(isBright ? 0.88 : 1.06)
                    .offset(x: -proxy.size.width * 0.38, y: proxy.size.height * 0.32)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                isBright = true
            }
        }
    }
}

struct SignalBreathingIndicator: View {
    var size: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBright = false

    var body: some View {
        Circle()
            .fill(SignalStyle.accent)
            .frame(width: size, height: size)
            .shadow(color: SignalStyle.accent.opacity(isBright ? 0.35 : 0.08), radius: isBright ? size * 0.55 : 0)
            .scaleEffect(isBright ? 1 : 0.88)
            .opacity(isBright ? 0.92 : 0.48)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: isBright
            )
            .onAppear { isBright = !reduceMotion }
            .accessibilityHidden(true)
    }
}

struct SignalLevelMeter: View {
    var activeCount: Int = 5
    var barCount: Int = 9
    var tint: Color = SignalStyle.accent
    var height: CGFloat = 22

    private let pattern: [CGFloat] = [0.32, 0.58, 0.82, 0.46, 0.94, 0.68, 0.38, 0.74, 0.5, 0.88, 0.62, 0.4]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<max(barCount, 1), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < activeCount ? tint : SignalStyle.inkMuted.opacity(0.34))
                    .frame(
                        width: 3,
                        height: max(4, height * pattern[index % pattern.count])
                    )
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

struct SignalSurfaceBackground: View {
    var cornerRadius: CGFloat = SignalStyle.cardRadius
    var elevated: Bool = true
    var pressed: Bool = false
    var fill: Color? = nil
    var stroke: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let radius = min(max(cornerRadius, 0), 16)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let base = fill ?? (pressed ? SignalStyle.controlPressed : (elevated ? SignalStyle.surfaceRaised : SignalStyle.surface))
        let line = stroke ?? SignalStyle.separator.opacity(colorScheme == .dark ? 0.64 : 0.72)

        shape
            .fill(base)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(line.opacity(elevated ? 0.82 : 0.56))
                    .frame(height: 0.65)
                    .padding(.horizontal, radius)
            }
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}

struct SignalScreenBackground: View {
    var cornerRadius: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let radius = min(max(cornerRadius, 0), 16)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        shape
            .fill(SignalStyle.screen)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(SignalStyle.separator.opacity(colorScheme == .dark ? 0.68 : 0.74))
                    .frame(height: 0.65)
                    .padding(.horizontal, radius)
            }
    }
}

struct SignalIconBadge: View {
    let icon: MonoIcon.IconType
    var tint: Color = SignalStyle.accent
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(size * 0.24, SignalStyle.compactRadius), style: .continuous)
                .fill(tint.opacity(0.1))
                .frame(width: size * 0.72, height: size * 0.72)

            MonoIcon(icon: icon, size: size * 0.4, color: tint, lineWidth: 1.65)
        }
        .frame(width: size, height: size)
        .themeRenderInteractiveLayer()
    }
}

struct SignalPill: View {
    let text: String
    var tint: Color = SignalStyle.accent
    var icon: MonoIcon.IconType?
    var selected: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(spacing: icon == nil ? 0 : 6) {
            if let icon {
                MonoIcon(icon: icon, size: compact ? 10 : 12, color: foreground, lineWidth: 1.6)
            }

            Text(text)
                .font(SignalStyle.labelFont(compact ? 10 : 11, weight: selected ? .semibold : .medium))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .background(
            Capsule(style: .continuous)
                .fill(selected ? tint.opacity(0.16) : SignalStyle.control.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(selected ? tint.opacity(0.24) : SignalStyle.separator.opacity(0.58), lineWidth: 0.7)
        )
        .themeRenderInteractiveLayer()
    }

    private var foreground: Color {
        selected ? tint : SignalStyle.inkSoft
    }
}

struct SignalPlayPill: View {
    let title: String
    var icon: MonoIcon.IconType = .play
    var tint: Color = SignalStyle.accent

    var body: some View {
        HStack(spacing: 7) {
            MonoIcon(icon: icon, size: 12, color: SignalStyle.onAccent, lineWidth: 1.8)
            Text(title)
                .font(SignalStyle.labelFont(11, weight: .semibold))
                .foregroundStyle(SignalStyle.onAccent)
                .lineLimit(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(tint)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 9, x: 0, y: 5)
        .themeRenderInteractiveLayer()
    }
}

struct SignalActionButton<Content: View>: View {
    var size: CGFloat = 42
    var action: () -> Void
    @ViewBuilder let content: Content

    init(size: CGFloat = 42, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.size = size
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(width: size, height: size)
                .background(SignalSurfaceBackground(cornerRadius: size * 0.36, elevated: true, fill: SignalStyle.surfaceRaised))
                .contentShape(RoundedRectangle(cornerRadius: size * 0.36, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        .themeRenderInteractiveLayer()
    }
}

struct SignalSectionTitle: View {
    let title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SignalStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(SignalStyle.labelFont(10, weight: .medium))
                        .foregroundStyle(SignalStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(action: action) {
                    SignalPill(text: actionTitle, tint: SignalStyle.accent, icon: .chevronRight, compact: true)
                }
                .buttonStyle(.plain)
                .themeRenderInteractiveLayer()
            }
        }
        .themeRenderSurfaceLayer()
    }
}

struct SignalPulseDot: View {
    var tint: Color = SignalStyle.accent
    var size: CGFloat = 18

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: max(5, size * 0.34), height: max(5, size * 0.34))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

enum SignalConsoleModule {
    case appearance
    case playback
    case cloud
    case storage
    case accounts
    case game
    case legal
    case changelog
    case about
    case search
    case radio
    case broadcast
    case importData
    case track
    case system
}

struct SignalNestedPageHeader: View {
    let title: String
    let eyebrow: String
    let icon: MonoIcon.IconType
    var module: SignalConsoleModule = .system

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SignalBreathingIndicator(size: 6)

                Text(eyebrow.uppercased())
                    .font(SignalStyle.monoFont(9, weight: .semibold))
                    .foregroundStyle(SignalStyle.inkMuted)
                    .tracking(1.4)

                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.7))
                    .frame(height: 0.65)
            }

            HStack(spacing: 14) {
                Text(title)
                    .font(SignalStyle.titleFont(24, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                Spacer(minLength: 10)

                SignalModuleInstrument(module: module, icon: icon)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.72))
                .frame(height: 0.65)
        }
        .themeRenderSurfaceLayer()
        .monoPageHeaderCollapse()
    }
}

private struct SignalModuleInstrument: View {
    let module: SignalConsoleModule
    let icon: MonoIcon.IconType

    var body: some View {
        ZStack {
            instrument
                .padding(.horizontal, 8)

            MonoIcon(icon: icon, size: 15, color: SignalStyle.inkSoft, lineWidth: 1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(6)
        }
        .frame(width: 72, height: 46)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.72))
                .frame(height: 0.65)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var instrument: some View {
        switch module {
        case .appearance:
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == 1 ? SignalStyle.inkSoft.opacity(0.66) : SignalStyle.inkMuted.opacity(0.42))
                        .frame(width: 7, height: CGFloat(8 + index * 4))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .playback, .track:
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array([10, 20, 14, 26, 17, 22].enumerated()), id: \.offset) { index, height in
                    Capsule()
                        .fill(index == 3 ? SignalStyle.inkSoft.opacity(0.66) : SignalStyle.inkMuted.opacity(0.42))
                        .frame(width: 3, height: CGFloat(height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .cloud, .accounts:
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 6, y: 28))
                    path.addLine(to: CGPoint(x: 23, y: 12))
                    path.addLine(to: CGPoint(x: 43, y: 25))
                }
                .stroke(SignalStyle.inkMuted.opacity(0.56), lineWidth: 1)

                ForEach(Array([CGPoint(x: 6, y: 28), CGPoint(x: 23, y: 12), CGPoint(x: 43, y: 25)].enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(index == 1 ? SignalStyle.inkSoft : SignalStyle.inkMuted)
                        .frame(width: 5, height: 5)
                        .position(point)
                }
            }
            .frame(width: 48, height: 34, alignment: .bottomLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .storage, .importData:
            VStack(alignment: .leading, spacing: 4) {
                ForEach([0.82, 0.58, 0.34], id: \.self) { fraction in
                    GeometryReader { proxy in
                        Capsule()
                            .fill(fraction == 0.82 ? SignalStyle.inkSoft.opacity(0.66) : SignalStyle.inkMuted.opacity(0.46))
                            .frame(width: proxy.size.width * fraction)
                    }
                    .frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .game:
            ZStack {
                Circle().stroke(SignalStyle.inkMuted.opacity(0.62), lineWidth: 1)
                Circle().fill(SignalStyle.inkSoft).frame(width: 5, height: 5)
                Rectangle().fill(SignalStyle.inkMuted.opacity(0.34)).frame(width: 1)
                Rectangle().fill(SignalStyle.inkMuted.opacity(0.34)).frame(height: 1)
            }
            .frame(width: 36, height: 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .legal, .about:
            VStack(alignment: .leading, spacing: 4) {
                ForEach([0.86, 0.66, 0.76, 0.44], id: \.self) { fraction in
                    GeometryReader { proxy in
                        Capsule()
                            .fill(SignalStyle.inkSoft.opacity(0.42))
                            .frame(width: proxy.size.width * fraction)
                    }
                    .frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .changelog:
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    VStack(spacing: 3) {
                        Capsule().fill(SignalStyle.inkMuted.opacity(0.32)).frame(width: 1, height: CGFloat(5 + index * 4))
                        Circle().fill(index == 3 ? SignalStyle.inkSoft : SignalStyle.inkMuted).frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .search:
            HStack(spacing: 5) {
                Circle()
                    .stroke(SignalStyle.inkMuted.opacity(0.7), lineWidth: 1)
                    .frame(width: 15, height: 15)
                    .overlay(alignment: .bottomTrailing) {
                        Capsule().fill(SignalStyle.inkMuted).frame(width: 6, height: 1).rotationEffect(.degrees(45))
                    }
                Capsule().fill(SignalStyle.inkSoft.opacity(0.46)).frame(width: 22, height: 3)
                SignalBreathingIndicator(size: 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .radio, .broadcast:
            HStack(alignment: .bottom, spacing: 4) {
                ForEach([7, 15, 29, 20, 11, 24, 9], id: \.self) { height in
                    Capsule()
                        .fill(height == 29 ? SignalStyle.inkSoft.opacity(0.66) : SignalStyle.inkMuted.opacity(0.42))
                        .frame(width: 3, height: CGFloat(height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        case .system:
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index == 2 ? SignalStyle.inkSoft : SignalStyle.inkMuted.opacity(0.5))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

struct SignalPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(SignalStyle.titleFont(27, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(SignalStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(SignalStyle.inkSoft)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 12)
        .themeRenderSurfaceLayer()
        .monoPageHeaderCollapse()
    }
}

extension SignalPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

extension View {
    func signalStagger(_ appeared: Bool, order: Int) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.easeOut(duration: 0.24).delay(Double(order) * 0.026), value: appeared)
    }
}
