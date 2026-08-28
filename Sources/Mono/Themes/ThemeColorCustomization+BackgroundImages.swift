import Foundation
import SwiftUI
import UIKit

extension ThemeColorCustomization {
    // MARK: - 背景图（壁纸式铺满）

    /// 目前仅默认主题支持自定义背景图。
    static func supportsImageBackground(_ theme: GlobalThemeId) -> Bool {
        theme == .default
    }


    @MainActor
    static func installMemoryManagement() {
        guard !didRegisterMemoryResource else { return }
        didRegisterMemoryResource = true
        MonoMemoryEngine.shared.registerResource(
            id: "cache.theme-background",
            priority: .recreatable,
            budgetWeight: 0.05,
            minimumBudgetBytes: 4 * 1024 * 1024,
            applyBudget: { _ in },
            trim: { context in
                guard context.level >= .background else { return .none }
                let bytes = backgroundImageCache.values.reduce(0) { partial, image in
                    partial + (image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
                }
                let count = backgroundImageCache.count
                backgroundImageCache.removeAll(keepingCapacity: false)
                return .init(
                    releasedItemCount: count,
                    estimatedReleasedBytes: bytes,
                    preservedItemCount: 0
                )
            },
            measureUsage: {
                .init(
                    itemCount: backgroundImageCache.count,
                    estimatedBytes: backgroundImageCache.values.reduce(0) { partial, image in
                        partial + (image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
                    }
                )
            }
        )
    }

    static func backgroundImageDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ThemeBackgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func backgroundImageFileKeySuffix(dark: Bool) -> String {
        dark ? "darkImageFile" : "imageFile"
    }

    static func backgroundImageFileName(for theme: GlobalThemeId, dark: Bool = false) -> String? {
        let stored = UserDefaults.standard.string(forKey: key(theme, .background, backgroundImageFileKeySuffix(dark: dark)))
        return stored?.isEmpty == false ? stored : nil
    }

    static func backgroundImageURL(for theme: GlobalThemeId, dark: Bool = false) -> URL? {
        guard let fileName = backgroundImageFileName(for: theme, dark: dark) else { return nil }
        let url = backgroundImageDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func hasBackgroundImage(for theme: GlobalThemeId, dark: Bool = false) -> Bool {
        backgroundImageURL(for: theme, dark: dark) != nil
    }

    static func usesImageBackground(for theme: GlobalThemeId) -> Bool {
        customColorsEnabled
            && supportsImageBackground(theme)
            && mode(for: theme, role: .background) == .image
            && hasBackgroundImage(for: theme)
    }

    /// 加载壁纸背景图；参考系统壁纸，整张图缩放填满屏幕显示。
    @MainActor
    static func backgroundImage(for theme: GlobalThemeId, dark: Bool = false) -> UIImage? {
        installMemoryManagement()
        guard let url = backgroundImageURL(for: theme, dark: dark) else { return nil }

        let cacheKey = url.lastPathComponent
        if let cached = backgroundImageCache[cacheKey] {
            return cached
        }

        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        backgroundImageCache[cacheKey] = image
        return image
    }

    @MainActor
    @discardableResult
    static func setBackgroundImageData(_ data: Data, for theme: GlobalThemeId, dark: Bool = false) -> Bool {
        installMemoryManagement()
        guard supportsImageBackground(theme), let raw = UIImage(data: data) else { return false }

        // 压缩上限取设备屏幕像素长边（不低于 2048px），保证壁纸清晰的同时避免超大图占用过多磁盘与内存
        let screenLongestPixel = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale
        let maxPixel: CGFloat = max(2048, screenLongestPixel)
        let pixelWidth = raw.size.width * raw.scale
        let pixelHeight = raw.size.height * raw.scale
        let ratio = min(1, maxPixel / max(pixelWidth, pixelHeight))
        let targetSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            raw.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let output = resized.pngData() else { return false }

        removeBackgroundImageFile(for: theme, dark: dark)

        let fileName = "\(theme.rawValue)-bg\(dark ? "-dark" : "")-\(UUID().uuidString).png"
        let url = backgroundImageDirectory().appendingPathComponent(fileName)
        do {
            try output.write(to: url)
        } catch {
            return false
        }

        let defaults = UserDefaults.standard
        defaults.set(fileName, forKey: key(theme, .background, backgroundImageFileKeySuffix(dark: dark)))
        if dark {
            defaults.set(ThemeDarkBackgroundKind.image.rawValue, forKey: key(theme, .background, "darkKind"))
            defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        } else {
            defaults.set(ThemeCustomColorMode.image.rawValue, forKey: key(theme, .background, "mode"))
            defaults.removeObject(forKey: selectedPresetKey(theme))
        }
        SettingsManager.shared.notifyThemeCustomizationChanged()
        return true
    }

    @MainActor
    static func clearBackgroundImage(for theme: GlobalThemeId, dark: Bool = false) {
        removeBackgroundImageFile(for: theme, dark: dark)
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key(theme, .background, backgroundImageFileKeySuffix(dark: dark)))
        if dark {
            if darkBackgroundKind(for: theme) == .image {
                defaults.removeObject(forKey: key(theme, .background, "darkKind"))
            }
            defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        } else {
            if mode(for: theme, role: .background) == .image {
                defaults.removeObject(forKey: key(theme, .background, "mode"))
            }
            defaults.removeObject(forKey: selectedPresetKey(theme))
        }
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func removeBackgroundImageFile(for theme: GlobalThemeId, dark: Bool = false) {
        if let fileName = backgroundImageFileName(for: theme, dark: dark) {
            backgroundImageCache.removeValue(forKey: fileName)
            let url = backgroundImageDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
    }

}
