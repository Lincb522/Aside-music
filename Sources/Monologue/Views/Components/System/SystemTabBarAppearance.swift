import SwiftUI
import UIKit

/// 为 SwiftUI `TabView` 使用的原生 TabBar 提供统一外观。
/// iOS 26 保留系统 Liquid Glass，只调整项目的图标与文字状态；
/// iOS 16–25 使用系统材质、轻量选中底和更清晰的层级。
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureIfNeeded()
    }

    func update(accent: UIColor, colorScheme: ColorScheme, revision: Int) {
        self.accent = accent
        self.colorScheme = colorScheme
        self.revision = revision
        scheduleConfiguration(force: true)
    }

    private func scheduleConfiguration(force: Bool) {
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.configureIfNeeded(force: force)
        }
    }

    private func configureIfNeeded(force: Bool = false) {
        guard let tabBar = resolvedTabBar(), tabBar.bounds.width > 0 else { return }

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
            tabBar.selectionIndicatorImage = nil
        } else {
            appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
            appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(
                colorScheme == .dark ? 0.34 : 0.52
            )
            appearance.shadowColor = UIColor.separator.withAlphaComponent(0.22)
            tabBar.selectionIndicatorImage = selectionIndicatorImage(
                tabBarWidth: tabBar.bounds.width,
                itemCount: itemCount,
                accent: resolvedAccent
            )
        }

        configureItemAppearance(appearance.stackedLayoutAppearance, accent: resolvedAccent)
        configureItemAppearance(appearance.inlineLayoutAppearance, accent: resolvedAccent)
        configureItemAppearance(appearance.compactInlineLayoutAppearance, accent: resolvedAccent)

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = resolvedAccent
        tabBar.unselectedItemTintColor = normalItemColor
        tabBar.isTranslucent = true

        if #unavailable(iOS 26.0) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                tabBar.itemPositioning = .centered
                tabBar.itemWidth = 72
                tabBar.itemSpacing = 14
            } else {
                tabBar.itemPositioning = .fill
            }
        }

        tabBar.items?.forEach { item in
            item.imageInsets = UIEdgeInsets(top: -1, left: 0, bottom: 1, right: 0)
            item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 1)
        }
    }

    private func configureItemAppearance(
        _ appearance: UITabBarItemAppearance,
        accent: UIColor
    ) {
        appearance.normal.iconColor = normalItemColor
        appearance.normal.titleTextAttributes = [
            .foregroundColor: normalItemColor,
            .font: UIFont.systemFont(ofSize: 10.5, weight: .medium),
        ]

        appearance.selected.iconColor = accent
        appearance.selected.titleTextAttributes = [
            .foregroundColor: accent,
            .font: UIFont.systemFont(ofSize: 10.5, weight: .semibold),
        ]

        appearance.disabled.iconColor = UIColor.tertiaryLabel
        appearance.disabled.titleTextAttributes = [
            .foregroundColor: UIColor.tertiaryLabel,
            .font: UIFont.systemFont(ofSize: 10.5, weight: .medium),
        ]
    }

    private var normalItemColor: UIColor {
        UIColor.secondaryLabel.withAlphaComponent(colorScheme == .dark ? 0.78 : 0.72)
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

    private func selectionIndicatorImage(
        tabBarWidth: CGFloat,
        itemCount: Int,
        accent: UIColor
    ) -> UIImage {
        let availableItemWidth = tabBarWidth / CGFloat(max(itemCount, 1))
        let width = min(max(availableItemWidth - 22, 54), 84)
        let size = CGSize(width: width, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 1.5)
            accent.withAlphaComponent(colorScheme == .dark ? 0.15 : 0.09).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 14).fill()
        }
        .withRenderingMode(.alwaysOriginal)
    }

    private func resolvedTabBar() -> UITabBar? {
        var ancestor: UIViewController? = self
        while let current = ancestor {
            if let tabController = current as? UITabBarController {
                return tabController.tabBar
            }
            ancestor = current.parent
        }

        return findTabBarController(in: view.window?.rootViewController)?.tabBar
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
