import Foundation

/// Centralized access to user-facing localized copy.
///
/// Keep keys stable and semantic. Runtime values belong in a format string,
/// never inside the localization key itself.
enum L10n {
    static func text(_ key: String.LocalizationValue) -> String {
        String(localized: key)
    }

    static func format(
        _ key: String.LocalizationValue,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: String(localized: key),
            locale: Locale.current,
            arguments: arguments
        )
    }

    /// Use only when a closed enum constructs a known family of resource keys.
    static func dynamic(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func compactCount(_ count: Int) -> String {
        let value = Double(count)
        let languageCode = Locale.current.language.languageCode?.identifier

        if languageCode == "zh" {
            if count >= 100_000_000 {
                return format("count_hundred_million", value / 100_000_000)
            }
            if count >= 10_000 {
                return format("count_ten_thousand", value / 10_000)
            }
            return "\(count)"
        }

        switch count {
        case 1_000_000_000...:
            return String(format: "%.1fB", locale: Locale.current, value / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", locale: Locale.current, value / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", locale: Locale.current, value / 1_000)
        default:
            return "\(count)"
        }
    }
}
