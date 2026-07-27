import SwiftUI

// MARK: - Sequoia 主题已移除 · 兼容 Shim
//
// Sequoia 主题已从 GlobalThemeId.allCases 中移除，外部不能再选中。
// 但仓库内仍有约 60 个文件、2200+ 引用点引用 SequoiaStyle.* 与 Sequoia* 视图组件。
// 为了避免一次性改动所有外部文件，这里提供「兼容 stub」：
//   - SequoiaStyle.isActive 永远返回 false
//   - 所有外部 `if SequoiaStyle.isActive { ... }` 分支永远不进入
//   - 所有视图 stub 渲染 Color.clear，运行时不会被走到

enum SequoiaStyle {
    static var isActive: Bool { false }

    static var base: Color { Color.monoBackground }

    static let canvasTop = Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "232325"))
    static let canvasMiddle = Color(light: Color(hex: "EAEAEC"), dark: Color(hex: "1A1A1C"))
    static let canvasBottom = Color(light: Color(hex: "DEDEE0"), dark: Color(hex: "151517"))

    static let material = Color(light: Color.white.opacity(0.55), dark: Color(hex: "2A2A2C").opacity(0.65))
    static let materialRaised = Color(light: Color.white.opacity(0.78), dark: Color(hex: "323234").opacity(0.78))
    static let materialPressed = Color(light: Color(hex: "E5E5E7").opacity(0.85), dark: Color(hex: "1A1A1C").opacity(0.88))
    static let materialChrome = Color(light: Color.white.opacity(0.62), dark: Color(hex: "2D2D2F").opacity(0.72))
    static let materialSidebar = Color(light: Color(hex: "F2F2F4").opacity(0.7), dark: Color(hex: "242426").opacity(0.74))
    static let materialList = Color(light: Color.white.opacity(0.4), dark: Color(hex: "1F1F21").opacity(0.55))
    static let materialFloating = Color(light: Color.white.opacity(0.92), dark: Color(hex: "2E2E30").opacity(0.92))
    static let selectedWash = Color(light: Color(hex: "007AFF").opacity(0.12), dark: Color(hex: "007AFF").opacity(0.22))

    static var glass: Color { materialList }
    static var glassRaised: Color { materialRaised }
    static var glassPressed: Color { materialPressed }

    static let ink = Color(light: Color(hex: "000000").opacity(0.85), dark: Color(hex: "FFFFFF").opacity(0.85))
    static let inkSoft = Color(light: Color(hex: "000000").opacity(0.6), dark: Color(hex: "FFFFFF").opacity(0.55))
    static let inkMuted = Color(light: Color(hex: "000000").opacity(0.4), dark: Color(hex: "FFFFFF").opacity(0.4))
    static var onAccent: Color { Color.white }

    static var accent: Color { .monoAccent }

    static let aqua = Color(light: Color(hex: "32ADE6"), dark: Color(hex: "64D2FF"))
    static let violet = Color(light: Color(hex: "AF52DE"), dark: Color(hex: "BF5AF2"))
    static let green = Color(light: Color(hex: "30D158"), dark: Color(hex: "32D74B"))
    static let yellow = Color(light: Color(hex: "FFCC00"), dark: Color(hex: "FFD60A"))
    static let red = Color(light: Color(hex: "FF3B30"), dark: Color(hex: "FF453A"))
    static let graphite = Color(light: Color(hex: "8E8E93"), dark: Color(hex: "98989F"))

    static let separator = Color(light: Color(hex: "000000").opacity(0.1), dark: Color.white.opacity(0.1))
    static let strongSeparator = Color(light: Color(hex: "000000").opacity(0.18), dark: Color.white.opacity(0.18))
    static let luminousSeparator = Color(light: Color.white.opacity(0.7), dark: Color.white.opacity(0.08))

    static let cardRadius: CGFloat = 12
    static let compactRadius: CGFloat = 8
    static let buttonRadius: CGFloat = 8
    static let toolbarRadius: CGFloat = 16

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, aqua], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var auroraGradient: LinearGradient {
        LinearGradient(colors: [accent, aqua, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func shadow(_ scheme: ColorScheme, elevated: Bool = true) -> Color {
        scheme == .dark ? Color.black.opacity(elevated ? 0.3 : 0.16) : Color.black.opacity(elevated ? 0.08 : 0.035)
    }

    static func highlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.7)
    }
}

// ── 材质角色 ──

enum SequoiaMaterialRole {
    case content, chrome, sidebar, list, floating, selected
}

// ── 视图 stub：返回空内容，运行时不会被使用（外部都被 isActive 守卫）──

struct SequoiaRootBackdrop: View {
    var body: some View { Color.clear }
}

struct SequoiaSurfaceBackground: View {
    var cornerRadius: CGFloat = SequoiaStyle.cardRadius
    var elevated: Bool = true
    var pressed: Bool = false
    var fill: Color?
    var role: SequoiaMaterialRole = .content
    var body: some View { Color.clear }
}

struct SequoiaChromeBar: View {
    var cornerRadius: CGFloat = SequoiaStyle.toolbarRadius
    var body: some View { Color.clear }
}

struct SequoiaGlassBand: View {
    var tint: Color = SequoiaStyle.accent
    var cornerRadius: CGFloat = 16
    var body: some View { Color.clear }
}

struct SequoiaIconBadge: View {
    let icon: MonoIcon.IconType
    var tint: Color = SequoiaStyle.accent
    var size: CGFloat = 40
    var body: some View { Color.clear.frame(width: size, height: size) }
}

struct SequoiaControlButton: View {
    let icon: MonoIcon.IconType
    var tint: Color = SequoiaStyle.inkSoft
    var size: CGFloat = 36
    var selected: Bool = false
    var body: some View { Color.clear.frame(width: size, height: size) }
}

struct SequoiaPill: View {
    let text: String
    var icon: MonoIcon.IconType?
    var tint: Color = SequoiaStyle.accent
    var selected: Bool = false
    var compact: Bool = false
    var body: some View { Color.clear }
}

struct SequoiaPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory
    var body: some View { Color.clear }
}

extension SequoiaPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct SequoiaSection<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let tint: Color
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        tint: Color = SequoiaStyle.accent,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View { Color.clear }
}

extension SequoiaSection where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        tint: Color = SequoiaStyle.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, subtitle: subtitle, tint: tint) { EmptyView() } content: { content() }
    }
}

struct SequoiaHairline: View {
    var tint: Color = SequoiaStyle.separator
    var body: some View { Color.clear.frame(height: 0.5) }
}

struct SequoiaListGroup<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View { Color.clear }
}

struct SequoiaMeter: View {
    var tint: Color = SequoiaStyle.accent
    var count: Int = 7
    var body: some View { Color.clear.frame(height: 18) }
}

struct SequoiaStatePanel: View {
    let title: String
    var subtitle: String?
    var icon: MonoIcon.IconType = .musicNote
    var tint: Color = SequoiaStyle.accent
    var showsProgress: Bool = false
    var body: some View { Color.clear }
}

extension View {
    func sequoiaStagger(_ appeared: Bool, order: Int) -> some View { self }
}
