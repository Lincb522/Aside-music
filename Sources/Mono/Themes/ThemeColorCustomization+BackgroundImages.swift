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
                backgroundImageLoads.values.forEach { $0.cancel() }
                backgroundImageLoads.removeAll()
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

    @MainActor
    static func hasBackgroundImage(for theme: GlobalThemeId, dark: Bool = false) -> Bool {
        backgroundImage(for: theme, dark: dark) != nil || backgroundImageURL(for: theme, dark: dark) != nil
    }

    static func usesImageBackground(for theme: GlobalThemeId) -> Bool {
        customColorsEnabled
            && supportsImageBackground(theme)
            && mode(for: theme, role: .background) == .image
    }

    /// Rendering reads memory only; file loading belongs to the view's task.
    @MainActor
    static func backgroundImage(for theme: GlobalThemeId, dark: Bool = false) -> UIImage? {
        guard let fileName = backgroundImageFileName(for: theme, dark: dark) else { return nil }
        return backgroundImageCache[fileName]
    }

    @MainActor
    static func loadBackgroundImage(for theme: GlobalThemeId, dark: Bool = false) async -> UIImage? {
        installMemoryManagement()
        guard let fileName = backgroundImageFileName(for: theme, dark: dark) else { return nil }
        if let cached = backgroundImageCache[fileName] {
            return cached
        }

        // Pages and the settings preview can request the same full-resolution image.
        let task: Task<UIImage?, Never>
        if let pending = backgroundImageLoads[fileName] {
            task = pending
        } else {
            let url = backgroundImageDirectory().appendingPathComponent(fileName)
            task = Task { await ThemeBackgroundImageDecoder.shared.load(url) }
            backgroundImageLoads[fileName] = task
        }
        let image = await task.value
        guard !task.isCancelled else { return nil }
        backgroundImageLoads.removeValue(forKey: fileName)
        guard backgroundImageFileName(for: theme, dark: dark) == fileName else { return nil }
        backgroundImageCache[fileName] = image
        return image
    }

    @MainActor
    @discardableResult
    static func setBackgroundImageData(
        _ data: Data,
        for theme: GlobalThemeId,
        dark: Bool = false,
        isCurrent: @MainActor () -> Bool
    ) async -> Bool {
        installMemoryManagement()
        guard supportsImageBackground(theme), !Task.isCancelled else { return false }

        let screenLongestPixel = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale
        let maxPixel: CGFloat = max(2048, screenLongestPixel)
        let fileName = "\(theme.rawValue)-bg\(dark ? "-dark" : "")-\(UUID().uuidString).png"
        let url = backgroundImageDirectory().appendingPathComponent(fileName)
        guard let resized = await ThemeBackgroundImageDecoder.shared.prepare(
            data, maxPixel: maxPixel, destination: url
        ) else { return false }
        guard !Task.isCancelled, isCurrent() else {
            await ThemeBackgroundImageDecoder.shared.discard(url)
            return false
        }

        // Publish only after the replacement file is ready; a cancelled picker
        // task must not replace the current wallpaper or leave a prepared file.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            removeBackgroundImageFile(for: theme, dark: dark)
            backgroundImageCache[fileName] = resized
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
        }
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
            backgroundImageLoads.removeValue(forKey: fileName)?.cancel()
            backgroundImageCache.removeValue(forKey: fileName)
            let url = backgroundImageDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
    }

}

private actor ThemeBackgroundImageDecoder {
    static let shared = ThemeBackgroundImageDecoder()

    func prepare(_ data: Data, maxPixel: CGFloat, destination: URL) -> UIImage? {
        guard !Task.isCancelled else { return nil }
        return autoreleasepool {
            guard let raw = UIImage(data: data) else { return nil }
            let pixelWidth = raw.size.width * raw.scale
            let pixelHeight = raw.size.height * raw.scale
            let ratio = min(1, maxPixel / max(pixelWidth, pixelHeight))
            let targetSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                raw.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            guard !Task.isCancelled, let output = resized.pngData(), !Task.isCancelled else { return nil }
            do {
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try output.write(to: destination, options: .atomic)
            } catch {
                discard(destination)
                return nil
            }
            guard !Task.isCancelled else {
                discard(destination)
                return nil
            }
            return resized
        }
    }

    func discard(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func load(_ url: URL) -> UIImage? {
        guard !Task.isCancelled else { return nil }
        return autoreleasepool {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
            return image.preparingForDisplay() ?? image
        }
    }
}

struct ThemeBackgroundImageReader<Content: View>: View {
    let theme: GlobalThemeId
    var dark = false
    var isEnabled = true
    @ViewBuilder var content: (UIImage?) -> Content

    @State private var loadedFileName: String?
    @State private var loadedImage: UIImage?

    init(
        theme: GlobalThemeId,
        dark: Bool = false,
        isEnabled: Bool = true,
        @ViewBuilder content: @escaping (UIImage?) -> Content
    ) {
        self.theme = theme
        self.dark = dark
        self.isEnabled = isEnabled
        self.content = content
    }

    var body: some View {
        let fileName = isEnabled ? ThemeColorCustomization.backgroundImageFileName(for: theme, dark: dark) : nil
        let image = isEnabled ? ThemeColorCustomization.backgroundImage(for: theme, dark: dark) : nil
        content(image ?? (loadedFileName == fileName ? loadedImage : nil))
            .task(id: fileName) {
                let loaded = fileName == nil ? nil : await ThemeColorCustomization.loadBackgroundImage(for: theme, dark: dark)
                guard !Task.isCancelled else { return }
                loadedImage = loaded
                loadedFileName = fileName
            }
    }
}
