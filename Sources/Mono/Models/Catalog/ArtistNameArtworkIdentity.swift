import Foundation

struct ArtistNameArtworkIdentity: Hashable {
    let name: String
    let aliases: [String]
    let qqMid: String?

    func matchingMIDs(in candidates: [(name: String, mid: String)]) -> Set<String> {
        let names = Set(([name] + aliases).map(Self.normalized).filter { !$0.isEmpty })
        return Set(candidates.filter {
            !$0.mid.isEmpty && names.contains(Self.normalized($0.name))
        }.map(\.mid))
    }

    static func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
