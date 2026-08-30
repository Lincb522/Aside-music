import Foundation

extension KCMMusicService {
    static func firstDictionaryArray(
        in value: Any,
        keys: Set<String>,
        allowDirectArray: Bool = true
    ) -> [[String: Any]] {
        if allowDirectArray, let dictionaries = value as? [[String: Any]], !dictionaries.isEmpty {
            return dictionaries
        }
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary where keys.contains(key) {
                if let result = child as? [[String: Any]] { return result }
            }
            for child in dictionary.values {
                let result = firstDictionaryArray(in: child, keys: keys, allowDirectArray: allowDirectArray)
                if !result.isEmpty { return result }
            }
        } else if let array = value as? [Any] {
            for child in array {
                let result = firstDictionaryArray(in: child, keys: keys, allowDirectArray: allowDirectArray)
                if !result.isEmpty { return result }
            }
        }
        return []
    }

    static func allDictionaryItems(in value: Any, matchingKey key: String) -> [[String: Any]] {
        var result: [[String: Any]] = []
        if let dictionary = value as? [String: Any] {
            for (childKey, child) in dictionary {
                if childKey == key, let items = child as? [[String: Any]] {
                    result.append(contentsOf: items)
                } else {
                    result.append(contentsOf: allDictionaryItems(in: child, matchingKey: key))
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: allDictionaryItems(in: child, matchingKey: key))
            }
        }
        return result
    }

    struct MembershipSummary {
        let level: KCMMembershipLevel
        let expiration: Date?
        let productType: String?
    }

    static func membershipSummary(
        detail: [String: Any],
        vip: [String: Any]
    ) -> MembershipSummary {
        let merged: [Any] = [vip, detail]
        let activeFlags = merged.flatMap {
            allInts(in: $0, keys: ["is_vip", "vip_status", "vip_level"])
        }
        let expiration = merged.flatMap {
            allTimestamps(
                in: $0,
                keys: ["vip_end_time", "end_time", "endtime", "expire_time", "expireTime", "paid_vip_expire_time"]
            )
        }.max()
        let isActive = activeFlags.contains(where: { $0 > 0 }) || expiration.map { $0 > Date() } == true
        guard isActive else {
            return MembershipSummary(level: .none, expiration: expiration, productType: nil)
        }

        let paidFlags = merged.flatMap {
            allInts(in: $0, keys: ["is_paid_vip", "purchased_type", "purchased_ios_type"])
        }
        let vipData = vip["data"] as? [String: Any] ?? vip
        let mainVIPType = int(vipData["vip_type"]) ?? int(vipData["m_type"]) ?? 0
        let level: KCMMembershipLevel = paidFlags.contains(where: { $0 > 0 }) || mainVIPType > 0
            ? .full
            : .trial

        let productTypes = merged.flatMap {
            allStrings(in: $0, keys: ["product_type"])
        }.map { $0.lowercased() }
        let productType = productTypes.contains("svip")
            ? "svip"
            : productTypes.first
        return MembershipSummary(level: level, expiration: expiration, productType: productType)
    }

    static func allTimestamps(in value: Any, keys: Set<String>) -> [Date] {
        var result: [Date] = []
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary where keys.contains(key) {
                if let date = timestamp(child) { result.append(date) }
            }
            for child in dictionary.values {
                result.append(contentsOf: allTimestamps(in: child, keys: keys))
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: allTimestamps(in: child, keys: keys))
            }
        }
        return result
    }

    static func timestamp(_ value: Any) -> Date? {
        if let number = value as? NSNumber {
            var seconds = number.doubleValue
            if seconds > 10_000_000_000 { seconds /= 1_000 }
            return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
        }
        guard let raw = string(value), !raw.isEmpty else { return nil }
        if var seconds = Double(raw) {
            if seconds > 10_000_000_000 { seconds /= 1_000 }
            return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
        }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: raw) { return date }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: raw)
    }

    static func songQuality(hash: String?, bitrate: Int, size: Int?) -> SongQuality? {
        guard let hash, !hash.isEmpty else { return nil }
        return SongQuality(br: bitrate, fid: nil, size: size, vd: nil, sr: nil)
    }

    static func soundQuality(forKCMCode code: String) -> SoundQuality? {
        switch code.lowercased() {
        case "multitrack", "multi_track": return .multitrack
        case "128", "standard", "low": return .standard
        case "320", "exhigh", "hq": return .exhigh
        case "flac", "lossless", "sq": return .lossless
        case "high", "hires", "res": return .hires
        case "viper_clear", "jyeffect": return .jyeffect
        case "viper_atmos", "sky": return .sky
        case "vivid": return .vivid
        case "viper_tape", "jymaster", "master": return .jymaster
        default: return nil
        }
    }

    static func kcmQualityCode(for quality: SoundQuality) -> String {
        switch quality {
        case .multitrack: return "multitrack"
        case .standard, .higher, .none: return "128"
        case .exhigh: return "320"
        case .lossless: return "flac"
        case .hires: return "high"
        case .jyeffect: return "viper_clear"
        case .sky: return "viper_atmos"
        case .vivid: return "vivid"
        case .jymaster: return "viper_tape"
        }
    }


    static func qualitiesReported(by song: Song) -> [KCMSongQualityInfo] {
        let values: [(SoundQuality, String, SongQuality?)] = [
            (.hires, "high", song.hr),
            (.lossless, "flac", song.sq),
            (.exhigh, "320", song.h),
            (.standard, "128", song.l),
        ]
        return values.compactMap { quality, code, info in
            guard let info else { return nil }
            return KCMSongQualityInfo(
                quality: quality,
                code: code,
                bitrate: info.br,
                size: info.size ?? 0,
                isAvailable: true
            )
        }
    }

    static func firstInt(in value: Any, keys: Set<String>) -> Int? {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if keys.contains(key), let number = int(child) { return number }
            }
            for child in dictionary.values {
                if let found = firstInt(in: child, keys: keys) { return found }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let found = firstInt(in: child, keys: keys) { return found }
            }
        }
        return nil
    }

    static func allInts(in value: Any, keys: Set<String>) -> [Int] {
        var result: [Int] = []
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if keys.contains(key), let number = int(child) {
                    result.append(number)
                }
                result.append(contentsOf: allInts(in: child, keys: keys))
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: allInts(in: child, keys: keys))
            }
        }
        return result
    }

    static func allStrings(in value: Any, keys: Set<String>) -> [String] {
        var result: [String] = []
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if keys.contains(key), let text = string(child), !text.isEmpty {
                    result.append(text)
                }
                result.append(contentsOf: allStrings(in: child, keys: keys))
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: allStrings(in: child, keys: keys))
            }
        }
        return result
    }

    static var requestTimestamp: String {
        String(Int(Date().timeIntervalSince1970 * 1_000))
    }

    static func firstString(in value: Any, keys: Set<String>) -> String? {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if keys.contains(key), let result = string(child), !result.isEmpty { return result }
            }
            for child in dictionary.values {
                if let result = firstString(in: child, keys: keys) { return result }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let result = firstString(in: child, keys: keys) { return result }
            }
        }
        return nil
    }

    static func firstURLString(in value: Any) -> String? {
        if let dictionary = value as? [String: Any] {
            for key in ["url", "play_url", "playUrl", "downurl", "backupdownurl", "backup_url", "backupUrl"] {
                if let candidate = string(dictionary[key]), candidate.hasPrefix("http") { return candidate }
                if let candidates = dictionary[key] as? [String], let candidate = candidates.first(where: { $0.hasPrefix("http") }) { return candidate }
            }
            for child in dictionary.values {
                if let candidate = firstURLString(in: child) { return candidate }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let candidate = firstURLString(in: child) { return candidate }
            }
        }
        return nil
    }

    static func isSuccess(_ json: [String: Any]) -> Bool {
        let code = int(json["error_code"]) ?? int(json["errcode"]) ?? int(json["code"]) ?? int(json["status"])
        return code == nil || code == 0 || code == 1 || code == 200
    }

    static func stableID(_ value: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return -Int(hash % UInt64(Int.max - 1)) - 1
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let value as String: return value
        case let value as NSNumber: return value.stringValue
        default: return nil
        }
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let value as Int: return value
        case let value as NSNumber: return value.intValue
        case let value as String: return Int(value)
        default: return nil
        }
    }

    static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool: return value
        case let value as NSNumber: return value.boolValue
        case let value as String: return ["1", "true", "yes"].contains(value.lowercased())
        default: return nil
        }
    }

    static func cookieValues(in header: String) -> [String: String] {
        var values: [String: String] = [:]
        for component in header.split(separator: ";") {
            let pair = component.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }
        return values
    }

    static func decodeBase64Image(_ value: String) -> Data? {
        let encoded = value.components(separatedBy: ",").last ?? value
        return Data(base64Encoded: encoded)
    }

    static func secureURL(_ value: String) -> String {
        if value.hasPrefix("//") { return "https:\(value)" }
        if value.hasPrefix("http://") { return "https://\(value.dropFirst(7))" }
        return value
    }

    static func firstArtworkString(
        in value: [String: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let candidate = string(value[key]), !candidate.isEmpty {
                return candidate
            }
        }
        for key in keys {
            if let candidate = firstString(in: value, keys: [key]), !candidate.isEmpty {
                return candidate
            }
        }
        return nil
    }

    static func kugouArtworkURL(_ rawValue: String?, preferredSize: Int = 1000) -> String? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }

        let size = min(max(preferredSize, 400), 1000)
        value = value
            .replacingOccurrences(of: "{size}", with: String(size))
            .replacingOccurrences(of: "{width}", with: String(size))
            .replacingOccurrences(of: "{height}", with: String(size))
        value = secureURL(value)

        guard let url = URL(string: value),
              url.host?.lowercased().hasSuffix(".kugou.com") == true,
              let range = value.range(
                of: #"/(?:100|120|150|160|180|240|300|400|480|500|640|800|1000)/"#,
                options: .regularExpression
              ) else {
            return value
        }
        return value.replacingCharacters(in: range, with: "/\(size)/")
    }

    static func secureOptionalURL(_ value: String?) -> String? {
        value.map(secureURL)
    }
}
