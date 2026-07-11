import CoreText
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ImportedFontRecord: Codable, Hashable, Identifiable {
    let id: String
    var displayName: String
    let familyName: String
    let postScriptName: String
    let filename: String
    let importedAt: Date
}

enum CustomFontStorage {
    static let recordsKey = "customFonts.records.v1"

    static func loadRecords() -> [ImportedFontRecord] {
        guard let data = UserDefaults.standard.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([ImportedFontRecord].self, from: data) else {
            return []
        }
        return records
    }

    static func record(withID id: String?) -> ImportedFontRecord? {
        guard let id else { return nil }
        return loadRecords().first { $0.id == id }
    }

    static func postScriptName(for id: String?) -> String? {
        record(withID: id)?.postScriptName
    }
}

enum CustomFontImportError: LocalizedError {
    case unsupportedFile
    case unreadableFont
    case copyFailed
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return String(localized: "仅支持 TTF、OTF 和 TTC 字体文件")
        case .unreadableFont:
            return String(localized: "无法读取该字体文件")
        case .copyFailed:
            return String(localized: "字体文件保存失败")
        case .registrationFailed:
            return String(localized: "字体注册失败")
        }
    }
}

/// 用户字体统一仓库。字体文件持久化到 Documents/CustomFonts，并在每次启动时按进程重新注册。
@MainActor
final class CustomFontManager: ObservableObject {
    static let shared = CustomFontManager()

    @Published private(set) var fonts: [ImportedFontRecord]

    static var supportedContentTypes: [UTType] {
        var types: [UTType] = [.font]
        for type in ["ttf", "otf", "ttc"].compactMap({ UTType(filenameExtension: $0) })
        where !types.contains(type) {
            types.append(type)
        }
        return types
    }

    private let fileManager = FileManager.default

    private var storageDirectory: URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("CustomFonts", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private init() {
        fonts = CustomFontStorage.loadRecords()
        registerStoredFonts()
        removeMissingRecords()
        refreshImportedDisplayNames()
    }

    func registerStoredFonts() {
        var registeredFiles = Set<String>()
        for record in fonts where registeredFiles.insert(record.filename).inserted {
            let url = storageDirectory.appendingPathComponent(record.filename)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    @discardableResult
    func importFonts(from sourceURLs: [URL]) throws -> [ImportedFontRecord] {
        var imported: [ImportedFontRecord] = []

        for sourceURL in sourceURLs {
            let ext = sourceURL.pathExtension.lowercased()
            guard ["ttf", "otf", "ttc"].contains(ext) else {
                throw CustomFontImportError.unsupportedFile
            }

            let scoped = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let fileID = UUID().uuidString
            let filename = "\(fileID).\(ext)"
            let destinationURL = storageDirectory.appendingPathComponent(filename)

            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                throw CustomFontImportError.copyFailed
            }

            guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(destinationURL as CFURL)
                as? [CTFontDescriptor],
                  !descriptors.isEmpty else {
                try? fileManager.removeItem(at: destinationURL)
                throw CustomFontImportError.unreadableFont
            }

            let registered = CTFontManagerRegisterFontsForURL(destinationURL as CFURL, .process, nil)
            let discoveredRecords = descriptors.compactMap { descriptor -> ImportedFontRecord? in
                guard let postScriptName = CTFontDescriptorCopyAttribute(
                    descriptor,
                    kCTFontNameAttribute
                ) as? String,
                      !postScriptName.isEmpty else {
                    return nil
                }

                let familyName = (CTFontDescriptorCopyAttribute(
                    descriptor,
                    kCTFontFamilyNameAttribute
                ) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

                let resolvedFamily = familyName?.isEmpty == false ? familyName! : postScriptName

                if let existing = fonts.first(where: { $0.postScriptName == postScriptName }) {
                    return existing
                }

                return ImportedFontRecord(
                    id: UUID().uuidString,
                    displayName: Self.shortName(for: descriptor) ?? resolvedFamily,
                    familyName: resolvedFamily,
                    postScriptName: postScriptName,
                    filename: filename,
                    importedAt: Date()
                )
            }

            guard registered || discoveredRecords.allSatisfy({
                UIFont(name: $0.postScriptName, size: 16) != nil
            }) else {
                try? fileManager.removeItem(at: destinationURL)
                throw CustomFontImportError.registrationFailed
            }

            let newRecords = discoveredRecords.filter { candidate in
                !fonts.contains(where: { $0.id == candidate.id })
            }

            if newRecords.isEmpty {
                try? fileManager.removeItem(at: destinationURL)
            } else {
                fonts.append(contentsOf: newRecords)
                imported.append(contentsOf: newRecords)
            }
        }

        fonts.sort {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        persist()
        return imported
    }

    func delete(_ record: ImportedFontRecord) {
        fonts.removeAll { $0.id == record.id }

        if !fonts.contains(where: { $0.filename == record.filename }) {
            let url = storageDirectory.appendingPathComponent(record.filename)
            CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
            try? fileManager.removeItem(at: url)
        }

        clearSelectionIfNeeded(recordID: record.id)
        persist()
    }

    func record(withID id: String?) -> ImportedFontRecord? {
        guard let id else { return nil }
        return fonts.first { $0.id == id }
    }

    /// 短名解析：优先取字体内置的本地化家族名（如「思源黑体」），
    /// 再剥掉字重/版本等尾缀，让导入字体与内置字体一样只显示简短名字。
    private static func shortName(for descriptor: CTFontDescriptor) -> String? {
        let font = CTFontCreateWithFontDescriptor(descriptor, 0, nil)
        let localizedFamily = CTFontCopyLocalizedName(
            font,
            kCTFontFamilyNameKey,
            nil
        ) as String?
        let family = localizedFamily
            ?? (CTFontDescriptorCopyAttribute(
                descriptor,
                kCTFontFamilyNameAttribute
            ) as? String)

        guard let family else { return nil }
        let cleaned = cleanedFontName(family)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func cleanedFontName(_ raw: String) -> String {
        let styleWords: Set<String> = [
            "regular", "italic", "oblique", "bold", "semibold", "demibold",
            "medium", "light", "extralight", "ultralight", "thin", "heavy",
            "black", "extrabold", "ultrabold", "book", "normal", "roman",
            "subset", "webfont", "variable", "vf"
        ]

        var tokens = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: " -_"))
            .filter { !$0.isEmpty }

        while let last = tokens.last, tokens.count > 1 {
            let lower = last.lowercased()
            let isVersionLike = last.contains(where: \.isNumber)
                && last.allSatisfy { $0.isNumber || $0 == "." || $0 == "v" || $0 == "V" || $0 == "w" || $0 == "W" }
            if styleWords.contains(lower) || isVersionLike {
                tokens.removeLast()
            } else {
                break
            }
        }
        return tokens.joined(separator: " ")
    }

    /// 旧版本导入的记录存的是冗长的 DisplayName，启动时统一刷新为短名。
    private func refreshImportedDisplayNames() {
        var changed = false

        for index in fonts.indices {
            let url = storageDirectory.appendingPathComponent(fonts[index].filename)
            var resolved: String?

            if fileManager.fileExists(atPath: url.path),
               let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
               as? [CTFontDescriptor] {
                let descriptor = descriptors.first {
                    (CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String)
                        == fonts[index].postScriptName
                } ?? descriptors.first
                resolved = descriptor.flatMap { Self.shortName(for: $0) }
            }

            let fallback = Self.cleanedFontName(fonts[index].displayName)
            let short = resolved ?? (fallback.isEmpty ? fonts[index].displayName : fallback)

            if fonts[index].displayName != short {
                fonts[index].displayName = short
                changed = true
            }
        }

        if changed {
            fonts.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            persist()
        }
    }

    private func removeMissingRecords() {
        let existing = fonts.filter {
            fileManager.fileExists(
                atPath: storageDirectory.appendingPathComponent($0.filename).path
            )
        }
        guard existing != fonts else { return }
        let existingIDs = Set(existing.map(\.id))
        for missing in fonts where !existingIDs.contains(missing.id) {
            clearSelectionIfNeeded(recordID: missing.id)
        }
        fonts = existing
        persist()
    }

    private func clearSelectionIfNeeded(recordID: String) {
        let defaults = UserDefaults.standard
        let selectionPairs = [
            ("ariaLyricFont", "ariaCustomLyricFontID"),
            ("playerDisplayFont", "playerCustomFontID")
        ]

        for (selectionKey, idKey) in selectionPairs
        where defaults.string(forKey: idKey) == recordID {
            defaults.removeObject(forKey: idKey)
            defaults.set(
                selectionKey == "playerDisplayFont"
                    ? "theme"
                    : AriaLyricFontChoice.system.rawValue,
                forKey: selectionKey
            )
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(fonts) {
            UserDefaults.standard.set(data, forKey: CustomFontStorage.recordsKey)
        }
        objectWillChange.send()
    }
}

enum MonologuePlayerFont {
    static let followThemeRawValue = "theme"

    static func activeFont(
        size: CGFloat,
        weight: Font.Weight,
        fallback: Font
    ) -> Font {
        let defaults = UserDefaults.standard
        let storedScale = defaults.object(forKey: "playerFontScale") == nil
            ? 1
            : defaults.double(forKey: "playerFontScale")
        return font(
            selectionRaw: defaults.string(forKey: "playerDisplayFont")
                ?? followThemeRawValue,
            customFontID: defaults.string(forKey: "playerCustomFontID"),
            size: size * CGFloat(storedScale),
            weight: weight,
            fallback: fallback
        )
    }

    static func font(
        selectionRaw: String,
        customFontID: String?,
        size: CGFloat,
        weight: Font.Weight,
        fallback: Font
    ) -> Font {
        guard selectionRaw != followThemeRawValue else { return fallback }

        if selectionRaw == AriaLyricFontChoice.custom.rawValue,
           let name = CustomFontStorage.postScriptName(for: customFontID) {
            return .custom(name, size: size)
        }

        return (AriaLyricFontChoice(rawValue: selectionRaw) ?? .system)
            .font(size: size, weight: weight)
    }
}

private struct MonologuePlayerDisplayFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let fallback: Font

    @AppStorage("playerDisplayFont") private var selectionRaw = MonologuePlayerFont.followThemeRawValue
    @AppStorage("playerCustomFontID") private var customFontID = ""
    @AppStorage("playerFontScale") private var fontScale = 1.0

    func body(content: Content) -> some View {
        content.font(
            MonologuePlayerFont.font(
                selectionRaw: selectionRaw,
                customFontID: customFontID,
                size: size * CGFloat(fontScale),
                weight: weight,
                fallback: fallback
            )
        )
    }
}

extension View {
    func monologuePlayerDisplayFont(
        size: CGFloat,
        weight: Font.Weight = .semibold,
        fallback: Font
    ) -> some View {
        modifier(
            MonologuePlayerDisplayFontModifier(
                size: size,
                weight: weight,
                fallback: fallback
            )
        )
    }
}

extension String {
    /// 仅转换 ASCII 英文字母，中文、日文、韩文及其他文字保持原样。
    func monologueUppercasingEnglish() -> String {
        var result = ""
        result.reserveCapacity(utf8.count)

        for scalar in unicodeScalars {
            if scalar.value >= 0x61, scalar.value <= 0x7A,
               let uppercase = UnicodeScalar(scalar.value - 0x20) {
                result.unicodeScalars.append(uppercase)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }

        return result
    }

    var monologueLyricDisplayText: String {
        UserDefaults.standard.bool(forKey: "lyricsForceUppercaseEnglish")
            ? monologueUppercasingEnglish()
            : self
    }
}
