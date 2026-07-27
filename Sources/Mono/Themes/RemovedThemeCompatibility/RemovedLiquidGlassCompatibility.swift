import SwiftUI

// MARK: - LiquidGlass 主题已移除 · 兼容 Shim
//
// LiquidGlass 主题已从 GlobalThemeId.allCases 中移除，外部不能再选中。
// 但仓库内仍有 ~22 个文件引用 `LiquidGlassStyle.*` / `LiquidGlassSurfaceBackground` / `LiquidGlassPill` 等符号。
// 为了避免一次性改动 700+ 处引用、保持编译通过，这里提供一份「兼容 stub」：
//   - `LiquidGlassStyle.isActive` 永远返回 false（因为 manager 已经把 `.liquidGlass` 映射到 `.default`）
//   - 所有外部 `if LiquidGlassStyle.isActive { ... }` 分支永远不会触发
//   - 各 stub 颜色/视图都映射到 default token，仅用于让编译通过；运行时不会被走到

enum LiquidGlassStyle {
    static var isActive: Bool { false }

    // ── 颜色 token（运行时不会被读取，仅供编译通过） ──
    static var base: Color { Color.monoBackground }
    static let glass = Color(light: Color.white.opacity(0.18), dark: Color(hex: "0E2138").opacity(0.46))
    static let glassRaised = Color(light: Color.white.opacity(0.46), dark: Color(hex: "1A3050").opacity(0.66))
    static let glassPressed = Color(light: Color(hex: "D4F1FF").opacity(0.5), dark: Color(hex: "030D18").opacity(0.78))
    static let glassChrome = Color(light: Color.white.opacity(0.42), dark: Color(hex: "122842").opacity(0.7))
    static let glassFloating = Color(light: Color.white.opacity(0.66), dark: Color(hex: "1B3252").opacity(0.84))
    static let glassList = Color(light: Color.white.opacity(0.22), dark: Color(hex: "081826").opacity(0.5))
    static let selectedWash = Color(light: Color(hex: "C9F1FF").opacity(0.78), dark: Color(hex: "0E3858").opacity(0.78))

    static let ink = Color(light: Color(hex: "041723"), dark: Color(hex: "F4FBFF"))
    static let inkSoft = Color(light: Color(hex: "385468"), dark: Color(hex: "BCD2E2"))
    static let inkMuted = Color(light: Color(hex: "6F8DA1"), dark: Color(hex: "788FA3"))
    static var onAccent: Color { Color.white }

    static var accent: Color { .monoAccent }
    static let cyan = Color(light: Color(hex: "0FD0EE"), dark: Color(hex: "7AF3FF"))
    static let blue = Color(light: Color(hex: "3B7BFF"), dark: Color(hex: "9CBBFF"))
    static let violet = Color(light: Color(hex: "8C5BFF"), dark: Color(hex: "C2A6FF"))
    static let mint = Color(light: Color(hex: "30D2A8"), dark: Color(hex: "82EFCB"))
    static let pink = Color(light: Color(hex: "FF6FB6"), dark: Color(hex: "FFAFD4"))
    static let amber = Color(light: Color(hex: "C28324"), dark: Color(hex: "FFCB66"))
    static let red = Color(light: Color(hex: "DC4A65"), dark: Color(hex: "FF8898"))

    static let separator = Color(light: Color(hex: "5BA1C2").opacity(0.22), dark: Color.white.opacity(0.12))
    static let strongSeparator = Color(light: Color(hex: "3F7E9D").opacity(0.32), dark: Color.white.opacity(0.22))
    static let luminousEdge = Color(light: Color.white.opacity(0.94), dark: Color.white.opacity(0.2))
    static let innerShade = Color(light: Color(hex: "1F6B89").opacity(0.07), dark: Color.black.opacity(0.2))

    static let cardRadius: CGFloat = 28
    static let compactRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 22
    static let toolbarRadius: CGFloat = 26

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, cyan, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func shadow(_ scheme: ColorScheme, elevated: Bool = true) -> Color {
        scheme == .dark ? Color.black.opacity(elevated ? 0.44 : 0.22) : Color(hex: "1A6585").opacity(elevated ? 0.13 : 0.05)
    }

    static func highlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.84)
    }
}

// ── 表面角色 / 透镜对齐枚举 ──

enum LiquidGlassSurfaceRole {
    case content, chrome, lens, list, floating, selected
}

enum LiquidGlassAmbientAlignment {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

// ── 视图 stub：返回空内容，运行时不会被使用（外部都被 isActive 守卫）──

struct LiquidGlassRootBackdrop: View {
    var body: some View { Color.clear }
}

struct LiquidGlassSurfaceBackground: View {
    var cornerRadius: CGFloat = LiquidGlassStyle.cardRadius
    var elevated: Bool = true
    var pressed: Bool = false
    var fill: Color? = nil
    var role: LiquidGlassSurfaceRole = .content

    var body: some View { Color.clear }
}

struct LiquidGlassChromeBar: View {
    var cornerRadius: CGFloat = LiquidGlassStyle.toolbarRadius
    var body: some View { Color.clear }
}

struct LiquidGlassPrismBand: View {
    var tint: Color = LiquidGlassStyle.accent
    var cornerRadius: CGFloat = 24
    var body: some View { Color.clear }
}

struct LiquidGlassAmbientLens: View {
    var tint: Color = LiquidGlassStyle.accent
    var alignment: LiquidGlassAmbientAlignment = .topLeading
    var body: some View { Color.clear }
}

struct LiquidGlassCausticField: View {
    var opacity: Double = 0.14
    var body: some View { Color.clear }
}

struct LiquidGlassIconBadge: View {
    let icon: MonoIcon.IconType
    var tint: Color = LiquidGlassStyle.accent
    var size: CGFloat = 42
    var body: some View { Color.clear.frame(width: size, height: size) }
}

struct LiquidGlassControlButton: View {
    let icon: MonoIcon.IconType
    var tint: Color = LiquidGlassStyle.inkSoft
    var size: CGFloat = 40
    var selected: Bool = false
    var body: some View { Color.clear.frame(width: size, height: size) }
}

struct LiquidGlassPill: View {
    let text: String
    var icon: MonoIcon.IconType?
    var tint: Color = LiquidGlassStyle.accent
    var selected = false
    var compact = false
    var body: some View { Color.clear }
}

struct LiquidGlassDropletMark: View {
    var tint: Color = LiquidGlassStyle.accent
    var body: some View { Color.clear.frame(width: 36, height: 36) }
}

struct LiquidGlassHairline: View {
    var tint: Color = LiquidGlassStyle.separator
    var body: some View { Color.clear.frame(height: 0.7) }
}

struct LiquidGlassPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory
    var body: some View { Color.clear }
}

extension LiquidGlassPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct LiquidGlassStatePanel: View {
    let title: String
    var subtitle: String?
    var icon: MonoIcon.IconType = .musicNote
    var tint: Color = LiquidGlassStyle.accent
    var showsProgress = false
    var body: some View { Color.clear }
}
