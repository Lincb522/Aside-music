import Foundation

enum AppleMusicEditorialVideoParser {
    private static let preferredSquareVariants = [
        "motionDetailSquare",
        "motionSquareVideo1x1",
        "motionSquareVideo",
    ]

    static func videoURL(from data: Data) -> URL? {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return videoURL(fromJSONObject: root)
    }

    /// 只输出结构信息，不输出可能包含签名参数的视频地址或响应正文。
    static func diagnosticSummary(from data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            return "json=invalid bytes=\(data.count)"
        }

        let rootKeys = (root as? [String: Any])?.keys.sorted() ?? []
        let editorialVideos = editorialVideoObjects(in: root)
        let videos = videoContainers(in: root)
        let variantKeys = Set(videos.flatMap { video -> [String] in
            guard let container = video as? [String: Any] else { return [] }
            let dictionary = container["dictionary"] as? [String: Any] ?? container
            return Array(dictionary.keys)
        }).sorted()
        let squareKeys = variantKeys.filter {
            $0.localizedCaseInsensitiveContains("square")
        }

        return [
            "rootKeys=\(rootKeys.isEmpty ? "none" : rootKeys.joined(separator: ","))",
            "editorialVideoCount=\(editorialVideos.count)",
            "videoContainerCount=\(videos.count)",
            "variantKeys=\(variantKeys.isEmpty ? "none" : variantKeys.joined(separator: ","))",
            "squareKeys=\(squareKeys.isEmpty ? "none" : squareKeys.joined(separator: ","))",
            "bytes=\(data.count)",
        ].joined(separator: " ")
    }

    static func videoURL(fromJSONObject root: Any) -> URL? {
        for videoContainer in videoContainers(in: root) {
            guard let container = videoContainer as? [String: Any] else { continue }
            let variants = container["dictionary"] as? [String: Any] ?? container

            for key in preferredSquareVariants {
                if let variant = variants[key], let url = videoURL(in: variant) {
                    return url
                }
            }

            for key in variants.keys.sorted()
            where key.localizedCaseInsensitiveContains("square") {
                if let variant = variants[key], let url = videoURL(in: variant) {
                    return url
                }
            }
        }
        return nil
    }

    static func videoURL(fromAppleMusicWebPage data: Data) -> URL? {
        guard let html = String(data: data, encoding: .utf8),
              let markerRange = html.range(of: "id=\"serialized-server-data\""),
              let openingTagEnd = html[markerRange.upperBound...].firstIndex(of: ">"),
              let closingTag = html.range(
                  of: "</script>",
                  range: openingTagEnd..<html.endIndex
              ) else {
            return nil
        }

        let jsonStart = html.index(after: openingTagEnd)
        return videoURL(from: Data(html[jsonStart..<closingTag.lowerBound].utf8))
    }

    private static func videoContainers(in value: Any) -> [Any] {
        if let dictionary = value as? [String: Any] {
            var matches: [Any] = []
            if let editorialVideo = dictionary["editorialVideo"] {
                matches.append(editorialVideo)
            }
            if let videoArtwork = dictionary["videoArtwork"] {
                matches.append(videoArtwork)
            }
            for child in dictionary.values {
                matches.append(contentsOf: videoContainers(in: child))
            }
            return matches
        }
        if let array = value as? [Any] {
            return array.flatMap(videoContainers(in:))
        }
        return []
    }

    private static func editorialVideoObjects(in value: Any) -> [Any] {
        if let dictionary = value as? [String: Any] {
            var matches: [Any] = []
            if let editorialVideo = dictionary["editorialVideo"] {
                matches.append(editorialVideo)
            }
            for child in dictionary.values {
                matches.append(contentsOf: editorialVideoObjects(in: child))
            }
            return matches
        }
        if let array = value as? [Any] {
            return array.flatMap(editorialVideoObjects(in:))
        }
        return []
    }

    private static func videoURL(in variant: Any) -> URL? {
        guard let dictionary = variant as? [String: Any] else {
            return validRemoteURL(variant)
        }

        if let direct = validRemoteURL(dictionary["video"]) {
            return direct
        }

        let candidates = assetCandidates(in: dictionary["videoFile"])
        return preferredAsset(from: candidates)?.url
    }

    private static func assetCandidates(in value: Any?) -> [VideoAssetCandidate] {
        guard let value else { return [] }

        if let array = value as? [Any] {
            return array.flatMap { assetCandidates(in: $0) }
        }

        guard let dictionary = value as? [String: Any] else {
            return validRemoteURL(value).map {
                [VideoAssetCandidate(url: $0, width: nil, height: nil)]
            } ?? []
        }

        var candidates: [VideoAssetCandidate] = []
        if let url = validRemoteURL(
            dictionary["assetUrl"] ?? dictionary["assetURL"] ?? dictionary["url"]
        ) {
            candidates.append(
                VideoAssetCandidate(
                    url: url,
                    width: integerValue(dictionary["width"]),
                    height: integerValue(dictionary["height"])
                )
            )
        }

        for (key, child) in dictionary
        where key != "previewFrame" && key != "artwork" {
            candidates.append(contentsOf: assetCandidates(in: child))
        }
        return candidates
    }

    private static func preferredAsset(
        from candidates: [VideoAssetCandidate]
    ) -> VideoAssetCandidate? {
        candidates.min { lhs, rhs in
            assetScore(lhs) < assetScore(rhs)
        }
    }

    private static func assetScore(_ candidate: VideoAssetCandidate) -> Double {
        let width = candidate.width ?? 0
        let height = candidate.height ?? 0
        let ratioPenalty: Double
        if width > 0, height > 0 {
            ratioPenalty = abs(Double(width) / Double(height) - 1) * 10_000
        } else {
            ratioPenalty = 2_000
        }

        if width >= 720 {
            return ratioPenalty + Double(width - 720)
        }
        return ratioPenalty + 10_000 + Double(720 - width)
    }

    private static func validRemoteURL(_ value: Any?) -> URL? {
        let string: String?
        if let value = value as? String {
            string = value
        } else if let dictionary = value as? [String: Any] {
            string = dictionary["url"] as? String
                ?? dictionary["assetUrl"] as? String
                ?? dictionary["assetURL"] as? String
        } else {
            string = nil
        }

        guard let string,
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil else {
            return nil
        }
        return url
    }

    private static func integerValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

private struct VideoAssetCandidate {
    let url: URL
    let width: Int?
    let height: Int?
}
