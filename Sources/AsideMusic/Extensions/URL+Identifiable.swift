import Foundation

// MARK: - URL Extensions

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
