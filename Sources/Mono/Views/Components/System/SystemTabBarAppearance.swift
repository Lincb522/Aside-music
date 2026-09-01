import SwiftUI
import UIKit

/// 为 SwiftUI `TabView` 提供接近 Apple Music 的原生底部导航：
/// 选中状态只通过强调色和字重表达，图标内容保持稳定，不再叠加胶囊选中底；
/// iOS 26 保留系统 Liquid Glass，iOS 16–25 使用贴近系统背景的音乐应用栏材质。
@MainActor
struct SystemTabBarAppearanceBridge: UIViewControllerRepresentable {
    let accent: Color
    let colorScheme: ColorScheme
    let revision: Int

    func makeUIViewController(context: Context) -> SystemTabBarAppearanceController {
        let controller = SystemTabBarAppearanceController()
        controller.update(
            accent: UIColor(accent),
            colorScheme: colorScheme,
            revision: revision
        )
        return controller
    }

    func updateUIViewController(
        _ controller: SystemTabBarAppearanceController,
        context: Context
    ) {
        controller.update(
            accent: UIColor(accent),
            colorScheme: colorScheme,
            revision: revision
        )
    }
}

@MainActor
final class SystemTabBarAppearanceController: UIViewController {
    private var accent = UIColor.label
    private var colorScheme: ColorScheme = .light
    private var revision = 0
    private var lastSignature = ""
    private var transitionRetryScheduled = false

    override func loadView() {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        self.view = view
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        scheduleConfiguration(force: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleConfiguration(force: true)
    }

    func update(accent: UIColor, colorScheme: ColorScheme, revision: Int) {
        let appearanceInputsChanged = !self.accent.isEqual(accent)
            || self.colorScheme != colorScheme
            || self.revision != revision
        guard appearanceInputsChanged else { return }

        self.accent = accent
        self.colorScheme = colorScheme
        self.revision = revision
        scheduleConfiguration(force: false)
    }

    private func scheduleConfiguration(force: Bool) {
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.configureIfNeeded(force: force)
        }
    }

    private func configureIfNeeded(force: Bool = false) {
        guard let tabController = resolvedTabBarController() else { return }

        // 不在 UITabBarController 正搬移子 UINavigationController 时改写外观。
        // iOS 26 的导航栏一致性检查更严格，转场中触发布局更新可能让新旧
        // UINavigationItem 短暂落到不同 UINavigationBar 上。
        if tabController.transitionCoordinator != nil {
            scheduleRetryAfterTransition()
            return
        }

        transitionRetryScheduled = false
        let tabBar = tabController.tabBar
        guard tabBar.bounds.width > 0 else { return }

        let resolvedAccent = readableAccent(
            accent.resolvedColor(with: tabBar.traitCollection)
        )
        let itemCount = max(tabBar.items?.count ?? 0, 1)
        let signature = [
            "\(revision)",
            colorScheme == .dark ? "dark" : "light",
            resolvedAccent.description,
            "\(Int(tabBar.bounds.width.rounded()))",
            "\(itemCount)",
        ].joined(separator: "|")

        guard force || signature != lastSignature else { return }
        lastSignature = signature

        let appearance: UITabBarAppearance
        if #available(iOS 26.0, *) {
            appearance = tabBar.standardAppearance
        } else {
            appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(
                colorScheme == .dark ? 0.86 : 0.92
            )
            appearance.shadowColor = UIColor.separator.withAlphaComponent(
                colorScheme == .dark ? 0.34 : 0.24
            )
        }

        tabBar.selectionIndicatorImage = nil

        configureItemAppearance(appearance.stackedLayoutAppearance, accent: resolvedAccent)
        configureItemAppearance(appearance.inlineLayoutAppearance, accent: resolvedAccent)
        configureItemAppearance(appearance.compactInlineLayoutAppearance, accent: resolvedAccent)

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = resolvedAccent
        tabBar.unselectedItemTintColor = normalItemColor
        tabBar.isTranslucent = true

        if #unavailable(iOS 26.0) {
            if tabBar.bounds.width >= 600 {
                tabBar.itemPositioning = .centered
                tabBar.itemWidth = 76
                tabBar.itemSpacing = 18
            } else {
                tabBar.itemPositioning = .fill
                tabBar.itemWidth = 0
                tabBar.itemSpacing = 0
            }
        }

        tabBar.items?.forEach { item in
            item.imageInsets = .zero
            item.titlePositionAdjustment = .zero
        }
    }

    private func configureItemAppearance(
        _ appearance: UITabBarItemAppearance,
        accent: UIColor
    ) {
        appearance.normal.iconColor = normalItemColor
        appearance.normal.titleTextAttributes = [
            .foregroundColor: normalItemColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
        ]

        appearance.selected.iconColor = accent
        appearance.selected.titleTextAttributes = [
            .foregroundColor: accent,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        ]

        appearance.disabled.iconColor = UIColor.tertiaryLabel
        appearance.disabled.titleTextAttributes = [
            .foregroundColor: UIColor.tertiaryLabel,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
        ]
    }

    private var normalItemColor: UIColor {
        UIColor.secondaryLabel.withAlphaComponent(colorScheme == .dark ? 0.74 : 0.68)
    }

    private func readableAccent(_ color: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return color
        }

        let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
        if colorScheme == .dark, luminance < 0.26 {
            return blended(color, with: .white, amount: 0.34)
        }
        if colorScheme == .light, luminance > 0.78 {
            return blended(color, with: .black, amount: 0.30)
        }
        return color
    }

    private func blended(_ color: UIColor, with target: UIColor, amount: CGFloat) -> UIColor {
        var sourceRed: CGFloat = 0
        var sourceGreen: CGFloat = 0
        var sourceBlue: CGFloat = 0
        var sourceAlpha: CGFloat = 0
        var targetRed: CGFloat = 0
        var targetGreen: CGFloat = 0
        var targetBlue: CGFloat = 0
        var targetAlpha: CGFloat = 0

        guard color.getRed(
            &sourceRed,
            green: &sourceGreen,
            blue: &sourceBlue,
            alpha: &sourceAlpha
        ), target.getRed(
            &targetRed,
            green: &targetGreen,
            blue: &targetBlue,
            alpha: &targetAlpha
        ) else {
            return color
        }

        let clampedAmount = min(max(amount, 0), 1)
        return UIColor(
            red: sourceRed + (targetRed - sourceRed) * clampedAmount,
            green: sourceGreen + (targetGreen - sourceGreen) * clampedAmount,
            blue: sourceBlue + (targetBlue - sourceBlue) * clampedAmount,
            alpha: sourceAlpha
        )
    }

    private func resolvedTabBarController() -> UITabBarController? {
        var ancestor: UIViewController? = self
        while let current = ancestor {
            if let tabController = current as? UITabBarController {
                return tabController
            }
            ancestor = current.parent
        }

        return findTabBarController(in: view.window?.rootViewController)
    }

    private func scheduleRetryAfterTransition() {
        guard !transitionRetryScheduled else { return }
        transitionRetryScheduled = true

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self else { return }
            self.transitionRetryScheduled = false
            self.configureIfNeeded(force: true)
        }
    }

    private func findTabBarController(in controller: UIViewController?) -> UITabBarController? {
        guard let controller else { return nil }
        if let tabController = controller as? UITabBarController {
            return tabController
        }
        for child in controller.children {
            if let match = findTabBarController(in: child) {
                return match
            }
        }
        if let presented = controller.presentedViewController {
            return findTabBarController(in: presented)
        }
        return nil
    }
}
