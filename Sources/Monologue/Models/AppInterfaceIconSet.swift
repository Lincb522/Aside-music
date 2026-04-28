import Foundation

enum AppInterfaceIconSet: String, CaseIterable, Identifiable {
    case hicon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hicon:
            return "Hicon"
        }
    }

    static var selectedFromDefaults: AppInterfaceIconSet {
        let rawValue = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.interfaceIconSet)
        return AppInterfaceIconSet(rawValue: rawValue ?? "") ?? .hicon
    }
}
