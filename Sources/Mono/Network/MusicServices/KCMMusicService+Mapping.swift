import Foundation

extension KCMMusicService {
    static func validate(json: [String: Any], statusCode: Int) throws {
        let code = int(json["error_code"]) ?? int(json["errcode"]) ?? int(json["code"])
        if code == 152 { throw KCMMusicError.authenticationRequired }
        if code == 20028 { throw KCMMusicError.verificationRequired }
        if let code, code != 0 && code != 1 && code != 200 {
            let message = string(json["error_msg"]) ?? string(json["error"]) ?? string(json["errmsg"]) ?? string(json["message"]) ?? ""
            throw KCMMusicError.server(code, message)
        }
        guard (200..<300).contains(statusCode) else {
            let message = string(json["error_msg"]) ?? string(json["error"]) ?? string(json["message"]) ?? ""
            throw KCMMusicError.server(statusCode, message)
        }
    }

    static func songDictionaries(in json: [String: Any]) -> [[String: Any]] {
        let data = json["data"] as? [String: Any] ?? json
        for key in ["info", "songs", "lists", "items"] {
            if let items = data[key] as? [[String: Any]] { return items }
        }
        return []
    }

    static func catalogItems(in json: [String: Any]) -> [[String: Any]] {
        let data = json["data"] as? [String: Any] ?? json
        return firstDictionaryArray(in: data, keys: ["lists", "list", "items", "info"])
    }

    static func catalogTotal(in json: [String: Any]) -> Int? {
        let data = json["data"] as? [String: Any] ?? json
        return firstInt(in: data, keys: ["total", "count", "total_count"])
    }

    static func catalogHasMore(
        in json: [String: Any],
        page: Int,
        pageSize: Int,
        itemCount: Int,
        total: Int
    ) -> Bool {
        let data = json["data"] as? [String: Any] ?? json
        if let explicit = firstInt(in: data, keys: ["has_more", "hasMore", "more"]) {
            return explicit != 0
        }
        return itemCount >= pageSize && page * pageSize < total
    }

    static func artist(from item: [String: Any]) -> ArtistInfo? {
        guard let id = firstInt(in: item, keys: ["AuthorId", "author_id", "singerid", "id"]),
              let name = firstString(in: item, keys: ["AuthorName", "author_name", "singername", "name"]),
              !name.isEmpty else { return nil }
        let avatar = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: [
                    "FirstFrameImage", "Avatar", "first_frame_image", "avatar",
                    "imgurl", "img", "cover", "image_url", "image", "pic",
                ]
            )
        )
        return ArtistInfo(
            id: id,
            name: name,
            picUrl: avatar,
            img1v1Url: avatar,
            cover: avatar,
            avatar: avatar,
            musicSize: firstInt(in: item, keys: ["AudioCount", "audio_count", "songcount"]),
            albumSize: firstInt(in: item, keys: ["AlbumCount", "album_count"]),
            mvSize: firstInt(in: item, keys: ["VideoCount", "video_count", "mv_count"]),
            briefDesc: nil,
            alias: nil,
            followed: nil,
            accountId: nil,
            source: .kugou,
            kugouID: String(id)
        )
    }

    static func searchPlaylist(from item: [String: Any]) -> Playlist? {
        guard let platformID = string(item["gid"])
                ?? string(item["global_collection_id"])
                ?? string(item["specialid"])
                ?? string(item["id"]),
              let name = firstString(in: item, keys: ["specialname", "name", "title"]),
              !name.isEmpty else { return nil }
        let cover = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: ["img", "flexible_cover", "cover", "imgurl", "image_url", "image", "pic"]
            )
        )
        let creatorName = firstString(in: item, keys: ["nickname", "user_name", "creator"])
        let creator = creatorName.map {
            PlaylistCreator(
                userId: stableID(firstString(in: item, keys: ["suid", "user_id"]) ?? $0),
                nickname: $0,
                avatarUrl: nil
            )
        }
        return Playlist(
            id: stableID("playlist:\(platformID)"),
            name: name,
            coverImgUrl: cover,
            picUrl: nil,
            trackCount: firstInt(in: item, keys: ["song_count", "songcount", "track_count"]),
            playCount: firstInt(in: item, keys: ["total_play_count", "play_count", "playcount"]),
            subscribedCount: firstInt(in: item, keys: ["collect_count", "collectcount"]),
            shareCount: nil,
            commentCount: nil,
            creator: creator,
            description: firstString(in: item, keys: ["intro", "description"]),
            tags: nil,
            source: .kugou,
            kugouID: platformID
        )
    }

    static func searchAlbum(from item: [String: Any]) -> SearchAlbum? {
        guard let platformID = firstString(in: item, keys: ["albumid", "album_id", "id"]),
              let name = firstString(in: item, keys: ["albumname", "album_name", "name"]),
              !name.isEmpty else { return nil }
        let singerItems = item["singers"] as? [[String: Any]] ?? []
        let artists = singerItems.compactMap { singer -> Artist? in
            guard let name = firstString(in: singer, keys: ["name", "singername"]), !name.isEmpty else { return nil }
            return Artist(id: firstInt(in: singer, keys: ["id", "singerid"]) ?? stableID(name), name: name)
        }
        let fallbackSinger = firstString(in: item, keys: ["singer", "singername", "author_name"])
        let resolvedArtists = artists.isEmpty
            ? fallbackSinger.map { [Artist(id: stableID($0), name: $0)] }
            : artists
        let cover = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: ["img", "sizable_cover", "cover", "album_cover", "imgurl", "image_url", "image", "pic"]
            )
        )
        return SearchAlbum(
            id: stableID("album:\(platformID)"),
            name: name,
            picUrl: cover,
            artist: resolvedArtists?.first,
            artists: resolvedArtists,
            size: firstInt(in: item, keys: ["songcount", "song_count", "size"]),
            publishTime: dateTimestamp(firstString(in: item, keys: ["publish_time", "publish_date"])),
            source: .kugou,
            qqMid: nil,
            appleMusicID: nil,
            kugouID: platformID
        )
    }

    static func albumInfo(from item: [String: Any]) -> AlbumInfo? {
        guard let album = searchAlbum(from: item) else { return nil }
        return AlbumInfo(
            id: album.id,
            name: album.name,
            picUrl: album.picUrl,
            publishTime: album.publishTime,
            size: album.size,
            artist: album.artist.map {
                ArtistInfo(
                    id: $0.id,
                    name: $0.name,
                    picUrl: nil,
                    img1v1Url: nil,
                    cover: nil,
                    avatar: nil,
                    musicSize: nil,
                    albumSize: nil,
                    mvSize: nil,
                    briefDesc: nil,
                    alias: nil,
                    followed: nil,
                    accountId: nil,
                    source: .kugou,
                    kugouID: String($0.id)
                )
            },
            artists: album.artists,
            description: firstString(in: item, keys: ["intro", "description", "short_intro"]),
            company: firstString(in: item, keys: ["company", "publish_company"]),
            subType: nil,
            qqAlbumMid: nil,
            source: .kugou,
            appleMusicID: nil,
            kugouID: album.kugouID
        )
    }

    static func mv(from item: [String: Any]) -> KCMMV? {
        guard let hash = firstString(in: item, keys: ["MvHash", "mvhash", "mv_hash", "hash"]),
              !hash.isEmpty else { return nil }
        let pic = firstArtworkString(
            in: item,
            keys: ["Pic", "pic", "cover", "img", "image_url", "image", "ThumbGif", "thumb_gif"]
        )
        let cover: String? = pic.map { raw in
            if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
                return kugouArtworkURL(raw) ?? secureURL(raw)
            }
            return "https://imge.kugou.com/mvhdpic/1000/\(raw)"
        }
        return KCMMV(
            hash: hash,
            videoID: firstInt(in: item, keys: ["MvID", "mvid", "mv_id", "video_id"]),
            name: firstString(in: item, keys: ["MvName", "mvname", "name", "FileName"])
                ?? String(localized: "mv_unknown_name"),
            artistName: firstString(in: item, keys: ["SingerName", "singername", "author_name"]),
            artistID: firstInt(in: item, keys: ["SingerID", "singerid", "author_id"]),
            coverURL: cover,
            duration: firstInt(in: item, keys: ["Duration", "duration"]),
            playCount: firstInt(in: item, keys: ["HistoryHeat", "MvHot", "play_count"]),
            publishDate: firstString(in: item, keys: ["PublishDate", "publish_date"]),
            description: firstString(in: item, keys: ["Description", "description", "Remark"])
        )
    }

    static func dateTimestamp(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return Int(date.timeIntervalSince1970 * 1_000)
            }
        }
        return nil
    }

    static func song(from item: [String: Any]) -> Song? {
        let deprecated = item["deprecated"] as? [String: Any]
        let base = item["base"] as? [String: Any]
        let audioInfo = item["audio_info"] as? [String: Any]
        let albumInfo = (item["albuminfo"] as? [String: Any]) ?? (item["album_info"] as? [String: Any])
        let transParam = item["trans_param"] as? [String: Any]
        let hash = string(item["hash"])
            ?? string(item["FileHash"])
            ?? string(item["filehash"])
            ?? string(deprecated?["hash"])
            ?? string(audioInfo?["hash_128"])
        guard let hash, !hash.isEmpty else { return nil }
        let rawName = string(item["name"])
            ?? string(item["SongName"])
            ?? string(item["songname"])
            ?? string(item["audio_name"])
            ?? string(base?["audio_name"])
            ?? ""
        let singerInfo = (item["singerinfo"] as? [[String: Any]])
            ?? (item["authors"] as? [[String: Any]])
            ?? []
        let artists: [Artist] = singerInfo.compactMap { singer in
            guard let name = string(singer["name"])
                    ?? string(singer["author_name"]),
                  !name.isEmpty else { return nil }
            return Artist(
                id: int(singer["id"])
                    ?? int(singer["author_id"])
                    ?? stableID(name),
                name: name
            )
        }
        let singerName = string(item["SingerName"])
            ?? string(item["singername"])
            ?? string(base?["author_name"])
        let fallbackArtists: [Artist] = singerName?.split(separator: "、").map {
            let value = String($0)
            return Artist(id: stableID(value), name: value)
        } ?? []
        let resolvedArtists: [Artist] = artists.isEmpty ? fallbackArtists : artists
        let titleWithoutArtist: String = {
            guard let separator = rawName.range(of: " - ") else { return rawName }
            let prefix = String(rawName[..<separator.lowerBound])
            let shouldStripPrefix = resolvedArtists.isEmpty || resolvedArtists.contains {
                prefix.localizedCaseInsensitiveContains($0.name)
            }
            return shouldStripPrefix ? String(rawName[separator.upperBound...]) : rawName
        }()
        let title = cleanedAudioTitle(titleWithoutArtist)

        let albumID = int(item["album_id"])
            ?? int(item["AlbumID"])
            ?? int(base?["album_id"])
            ?? int(albumInfo?["id"])
            ?? int(albumInfo?["album_id"])
        let albumName = string(item["AlbumName"])
            ?? string(item["album_name"])
            ?? string(base?["album_name"])
            ?? string(albumInfo?["name"])
            ?? string(albumInfo?["album_name"])
            ?? ""
        let rawCover = firstArtworkString(
            in: item,
            keys: [
                "cover", "Image", "image", "sizable_cover", "album_cover",
                "union_cover", "imgurl", "image_url", "pic",
            ]
        )
            ?? string(albumInfo?["sizable_cover"])
            ?? string(albumInfo?["cover"])
            ?? string(transParam?["union_cover"])
        let cover = kugouArtworkURL(rawCover)
        let duration = int(item["timelen"])
            ?? int(item["Duration"])
            ?? int(item["duration"])
            ?? int(audioInfo?["duration"])
        let durationMS = duration.map { $0 < 10_000 ? $0 * 1_000 : $0 }
        let audioID = int(item["mixsongid"])
            ?? int(item["MixSongID"])
            ?? int(item["album_audio_id"])
            ?? int(item["audio_id"])
            ?? int(base?["album_audio_id"])
            ?? int(base?["audio_id"])

        let standard = songQuality(
            hash: string(audioInfo?["hash_128"]) ?? hash,
            bitrate: int(audioInfo?["bitrate_128"]) ?? 128_000,
            size: int(audioInfo?["filesize_128"]) ?? int(item["FileSize"])
        )
        let high = songQuality(
            hash: string(item["HQFileHash"]) ?? string(audioInfo?["hash_320"]),
            bitrate: int(audioInfo?["bitrate_320"]) ?? 320_000,
            size: int(item["HQFileSize"]) ?? int(audioInfo?["filesize_320"])
        )
        let lossless = songQuality(
            hash: string(item["SQFileHash"]) ?? string(audioInfo?["hash_flac"]),
            bitrate: int(audioInfo?["bitrate_flac"]) ?? 900_000,
            size: int(item["SQFileSize"]) ?? int(audioInfo?["filesize_flac"])
        )
        let hires = songQuality(
            hash: string(item["ResFileHash"])
                ?? string(audioInfo?["hash_high"])
                ?? string(audioInfo?["hash_hires"]),
            bitrate: int(audioInfo?["bitrate_high"]) ?? int(audioInfo?["bitrate_hires"]) ?? 1_800_000,
            size: int(item["ResFileSize"])
                ?? int(audioInfo?["filesize_high"])
                ?? int(audioInfo?["filesize_hires"])
        )

        return Song(
            id: stableID(hash),
            name: title,
            ar: resolvedArtists.isEmpty ? nil : resolvedArtists,
            al: Album(id: albumID ?? 0, name: albumName, picUrl: cover),
            dt: durationMS,
            fee: nil,
            mv: nil,
            h: high, m: nil, l: standard, sq: lossless, hr: hires,
            alia: nil,
            source: .kugou,
            kugouHash: hash,
            kugouAlbumID: albumID,
            kugouAlbumAudioID: audioID
        )
    }

    static func playlist(from item: [String: Any]) -> Playlist? {
        guard let globalID = string(item["global_collection_id"]), !globalID.isEmpty else { return nil }
        let name = string(item["specialname"]) ?? string(item["name"]) ?? ""
        let cover = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: ["flexible_cover", "imgurl", "img", "cover", "image_url", "image", "pic"]
            )
        )
        let tagItems = item["tags"] as? [[String: Any]] ?? []
        let tags = tagItems.compactMap { string($0["tag_name"]) }
        let nickname = string(item["nickname"]) ?? string(item["singername"])
        let creator = nickname.map { PlaylistCreator(userId: int(item["suid"]) ?? stableID($0), nickname: $0, avatarUrl: secureOptionalURL(string(item["pic"]))) }
        return Playlist(
            id: stableID(globalID),
            name: name,
            coverImgUrl: cover,
            picUrl: nil,
            trackCount: int(item["song_count"]) ?? int(item["count"]),
            playCount: int(item["play_count"]),
            subscribedCount: int(item["collectcount"]),
            shareCount: nil,
            commentCount: nil,
            creator: creator,
            description: string(item["intro"]),
            tags: tags.isEmpty ? nil : tags,
            source: .kugou,
            kugouID: globalID
        )
    }

    static func cleanedAudioTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathExtension = (trimmed as NSString).pathExtension.lowercased()
        let audioExtensions: Set<String> = ["mp3", "flac", "m4a", "aac", "wav", "ogg", "ape", "wma"]
        guard audioExtensions.contains(pathExtension) else { return trimmed }
        return (trimmed as NSString).deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func userPlaylist(from item: [String: Any]) -> Playlist? {
        guard let listID = string(item["listid"])
            ?? string(item["list_id"])
            ?? string(item["id"]), !listID.isEmpty else { return nil }
        let name = string(item["listname"])
            ?? string(item["specialname"])
            ?? string(item["name"])
            ?? ""
        let cover = kugouArtworkURL(
            firstArtworkString(
                in: item,
                keys: ["list_pic", "imgurl", "img", "cover", "image_url", "image", "pic"]
            )
        )
        return Playlist(
            id: stableID("user:\(listID)"),
            name: name,
            coverImgUrl: cover,
            picUrl: nil,
            trackCount: int(item["songcount"]) ?? int(item["song_count"]) ?? int(item["count"]),
            playCount: int(item["play_count"]),
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: nil,
            description: string(item["intro"]),
            tags: nil,
            source: .kugou,
            kugouID: "user:\(listID)"
        )
    }

}
