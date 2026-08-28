import Foundation

extension KCMMusicService {
    func fetchSongURL(song: Song, quality: SoundQuality = .exhigh) async throws -> KCMPlaybackURLResult {
        guard song.kugouHash?.isEmpty == false else { throw KCMMusicError.unavailable }
        let membershipLevel = isAuthenticated
            ? await resolvedCurrentMembershipLevel()
            : KCMMembershipLevel.none
        let preferredUserID = membershipLevel != KCMMembershipLevel.none ? currentUserID : nil
        let excludedUserID = isAuthenticated && membershipLevel == KCMMembershipLevel.none
            ? currentUserID
            : nil

        var seenCodes = Set<String>()
        let qualityCodes = SoundQuality.fallbackCandidates(from: quality).compactMap { candidate in
            let code = Self.kcmQualityCode(for: candidate)
            return seenCodes.insert(code).inserted ? code : nil
        }
        if let result = try await APIService.shared.fetchKCMAccountPoolSongURL(
            song: song,
            qualityCodes: qualityCodes,
            excludeUserID: excludedUserID,
            preferredUserID: preferredUserID
        ) {
            return KCMPlaybackURLResult(
                url: result.url,
                quality: Self.soundQuality(forKCMCode: result.qualityCode) ?? quality
            )
        }
        throw KCMMusicError.unavailable
    }

    func fetchSongURLUsingCurrentAccount(
        song: Song,
        quality: SoundQuality
    ) async throws -> KCMPlaybackURLResult {
        guard isAuthenticated else { throw KCMMusicError.authenticationRequired }
        guard let hash = song.kugouHash, !hash.isEmpty else { throw KCMMusicError.unavailable }
        var seenCodes = Set<String>()
        let candidates = SoundQuality.fallbackCandidates(from: quality).filter {
            seenCodes.insert(Self.kcmQualityCode(for: $0)).inserted
        }
        var lastError: Error = KCMMusicError.unavailable
        for candidate in candidates {
            do {
                let json = try await request(
                    path: "/song/url",
                    query: [
                        URLQueryItem(name: "hash", value: hash),
                        URLQueryItem(name: "album_id", value: String(song.kugouAlbumID ?? 0)),
                        URLQueryItem(name: "album_audio_id", value: String(song.kugouAlbumAudioID ?? 0)),
                        URLQueryItem(name: "quality", value: Self.kcmQualityCode(for: candidate)),
                    ]
                )
                if let value = Self.firstURLString(in: json),
                   let url = URL(string: Self.secureURL(value)) {
                    return KCMPlaybackURLResult(url: url, quality: candidate)
                }
            } catch KCMMusicError.authenticationRequired {
                throw KCMMusicError.authenticationRequired
            } catch KCMMusicError.sessionExpired {
                throw KCMMusicError.sessionExpired
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func resolvedCurrentMembershipLevel() async -> KCMMembershipLevel {
        if let currentMembershipLevel { return currentMembershipLevel }
        return (try? await fetchAccountProfile())?.membershipLevel ?? KCMMembershipLevel.none
    }

    func cacheMembershipLevel(_ level: KCMMembershipLevel, userID: Int) {
        UserDefaults.standard.set(level.rawValue, forKey: membershipLevelKey)
        UserDefaults.standard.set(userID, forKey: membershipUserIDKey)
    }

    func clearMembershipCache() {
        UserDefaults.standard.removeObject(forKey: membershipLevelKey)
        UserDefaults.standard.removeObject(forKey: membershipUserIDKey)
    }

    func fetchSongPlatformDetail(song: Song) async throws -> PlatformSongDetail {
        var payloads: [[String: Any]] = []
        var lastError: Error?

        if let audioID = song.kugouAlbumAudioID, audioID > 0 {
            do {
                payloads.append(
                    try await request(
                        path: "/krm/audio",
                        query: [
                            URLQueryItem(name: "album_audio_id", value: String(audioID)),
                            URLQueryItem(
                                name: "fields",
                                value: "album_info,base,authors.base,extra,tags,tagmap"
                            ),
                        ]
                    )
                )
            } catch {
                lastError = error
            }
        }

        if let albumID = song.kugouAlbumID, albumID > 0 {
            do {
                payloads.append(
                    try await request(
                        path: "/album",
                        query: [
                            URLQueryItem(name: "album_id", value: String(albumID)),
                            URLQueryItem(
                                name: "fields",
                                value: "intro,publish_company,language,category,publish_date,authors,author_name"
                            ),
                        ]
                    )
                )
            } catch {
                lastError = error
            }
        }

        guard !payloads.isEmpty else {
            if song.kugouAlbumAudioID == nil, song.kugouAlbumID == nil {
                return .empty
            }
            throw lastError ?? KCMMusicError.unavailable
        }

        let introductions = payloads.flatMap {
            Self.readablePlatformTexts(
                in: $0,
                keys: ["intro", "introduction", "description", "desc", "full_intro", "mix_intro"],
                maximumLength: 12_000
            )
        }
        let introduction = introductions
            .filter { $0.count >= 12 }
            .max { lhs, rhs in lhs.count < rhs.count }
        let releaseDate = payloads.compactMap {
            Self.readablePlatformTexts(
                in: $0,
                keys: ["publish_date", "release_date", "publish_time"],
                maximumLength: 80
            ).first
        }.first
        let authorNames = payloads.flatMap {
            Self.readablePlatformTexts(
                in: $0,
                keys: ["author_name", "authors", "singername", "singer_name"],
                maximumLength: 120
            )
        }
        .reduce(into: [String]()) { result, value in
            if !result.contains(value), value != song.artistName { result.append(value) }
        }
        let tags = payloads.flatMap {
            Self.readablePlatformTexts(
                in: $0,
                keys: ["tags", "tag_name", "tagmap", "category"],
                maximumLength: 60
            )
        }
        .reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }

        var sections: [PlatformSongSection] = []
        if let introduction {
            sections.append(
                PlatformSongSection(
                    id: "kcm-introduction",
                    title: String(localized: "song_detail_introduction"),
                    body: introduction
                )
            )
        }
        if !authorNames.isEmpty {
            sections.append(
                PlatformSongSection(
                    id: "kcm-credits",
                    title: String(localized: "song_detail_credits"),
                    body: authorNames.joined(separator: "、")
                )
            )
        }
        if !tags.isEmpty {
            sections.append(
                PlatformSongSection(
                    id: "kcm-tags",
                    title: String(localized: "song_detail_tags"),
                    body: tags.joined(separator: " · ")
                )
            )
        }
        return PlatformSongDetail(
            releaseDate: releaseDate,
            attributes: [],
            sections: sections
        )
    }

    static func readablePlatformTexts(
        in value: Any,
        keys: Set<String>,
        maximumLength: Int
    ) -> [String] {
        var result: [String] = []

        func collect(_ value: Any, acceptsScalar: Bool) {
            if let text = value as? String {
                guard acceptsScalar,
                      let normalized = normalizedPlatformText(text),
                      normalized.count <= maximumLength else { return }
                result.append(normalized)
                return
            }
            if let dictionary = value as? [String: Any] {
                for (key, child) in dictionary {
                    collect(child, acceptsScalar: acceptsScalar || keys.contains(key.lowercased()))
                }
                return
            }
            if let array = value as? [Any] {
                array.forEach { collect($0, acceptsScalar: acceptsScalar) }
            }
        }

        collect(value, acceptsScalar: false)
        return result
    }

    static func normalizedPlatformText(_ value: String) -> String? {
        var text = value
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
        text = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !text.isEmpty,
              text.range(of: #"^https?://"#, options: .regularExpression) == nil,
              text.range(of: #"^\d+$"#, options: .regularExpression) == nil else {
            return nil
        }
        return text
    }

}
