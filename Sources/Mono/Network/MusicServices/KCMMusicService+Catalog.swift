import Foundation

extension KCMMusicService {
    func fetchPlaylistCategories() async throws -> [KCMPlaylistCategory] {
        let json = try await request(path: "/playlist/tags")
        guard let groups = json["data"] as? [[String: Any]] else { return [] }
        var result = [KCMPlaylistCategory(id: 0, name: "推荐", groupName: nil)]
        for group in groups {
            let groupName = Self.string(group["tag_name"])
            let children = group["son"] as? [[String: Any]] ?? []
            result.append(contentsOf: children.compactMap { item in
                guard let id = Self.int(item["tag_id"]),
                      let name = Self.string(item["tag_name"]), !name.isEmpty else { return nil }
                return KCMPlaylistCategory(id: id, name: name, groupName: groupName)
            })
        }
        return result
    }

    func fetchPlaylists(categoryID: Int, page: Int, pageSize: Int) async throws -> KCMPlaylistPage {
        let json = try await request(
            path: "/top/playlist",
            query: [
                URLQueryItem(name: "category_id", value: String(categoryID)),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(pageSize)),
                URLQueryItem(name: "withsong", value: "0"),
                URLQueryItem(name: "withtag", value: "1"),
            ]
        )
        let data = json["data"] as? [String: Any] ?? [:]
        let items = data["special_list"] as? [[String: Any]] ?? []
        let playlists = items.compactMap(Self.playlist(from:))
        let explicit = Self.bool(data["has_next"])
        return KCMPlaylistPage(playlists: playlists, hasMore: explicit ?? (playlists.count >= pageSize))
    }

    func fetchUserPlaylists() async throws -> [Playlist] {
        guard isAuthenticated else { throw KCMMusicError.authenticationRequired }
        let json = try await request(path: "/user/playlist")
        let data = json["data"] as? [String: Any] ?? json
        let items = Self.firstDictionaryArray(in: data, keys: ["info", "list", "lists", "playlist", "playlists"])
        return items.compactMap(Self.userPlaylist(from:))
    }

    func fetchRecommendedPlaylists(limit: Int = 12) async throws -> [Playlist] {
        let page = try await fetchPlaylists(categoryID: 0, page: 1, pageSize: max(1, limit))
        return Array(page.playlists.prefix(max(1, limit)))
    }

    func fetchTopLists() async throws -> [TopList] {
        let json = try await request(path: "/rank/list")
        let data = json["data"] as? [String: Any] ?? json
        let items = Self.firstDictionaryArray(in: data, keys: ["info", "list", "rank_list", "items"])
        return items.compactMap { item in
            guard let rankID = Self.int(item["rankid"]),
                  let name = Self.string(item["rankname"]), !name.isEmpty else { return nil }
            let rankCID = Self.int(item["rank_cid"]) ?? 0
            let cover = (Self.string(item["imgurl"]) ?? Self.string(item["banner7url"]))
                .map { Self.secureURL($0.replacingOccurrences(of: "{size}", with: "800")) }
            return TopList(
                id: Self.stableID("rank:\(rankID):\(rankCID)"),
                name: name,
                coverImgUrl: cover,
                updateFrequency: Self.string(item["update_frequency"]) ?? "",
                source: .kugou,
                kugouID: "rank:\(rankID):\(rankCID)"
            )
        }
    }

    func fetchPlaylistSongs(globalID: String, page: Int, pageSize: Int) async throws -> [Song] {
        if globalID.hasPrefix("user:") {
            let listID = String(globalID.dropFirst("user:".count))
            let json = try await request(
                path: "/playlist/track/all/new",
                query: [
                    URLQueryItem(name: "listid", value: listID),
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "pagesize", value: String(pageSize)),
                ]
            )
            return Self.firstDictionaryArray(in: json, keys: ["songlist", "songs", "info", "list"])
                .compactMap(Self.song(from:))
        }
        if globalID.hasPrefix("rank:") {
            let components = globalID.split(separator: ":")
            guard components.count >= 2 else { throw KCMMusicError.invalidResponse }
            let json = try await request(
                path: "/rank/audio",
                query: [
                    URLQueryItem(name: "rankid", value: String(components[1])),
                    URLQueryItem(name: "rank_cid", value: components.count > 2 ? String(components[2]) : nil),
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "pagesize", value: String(pageSize)),
                ]
            )
            return Self.firstDictionaryArray(in: json, keys: ["songlist", "songs", "info", "list"])
                .compactMap(Self.song(from:))
        }
        let json = try await request(
            path: "/playlist/track/all",
            query: [
                URLQueryItem(name: "id", value: globalID),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "pagesize", value: String(pageSize)),
            ]
        )
        let data = json["data"] as? [String: Any] ?? [:]
        let items = data["songs"] as? [[String: Any]] ?? []
        return items.compactMap(Self.song(from:))
    }

}
