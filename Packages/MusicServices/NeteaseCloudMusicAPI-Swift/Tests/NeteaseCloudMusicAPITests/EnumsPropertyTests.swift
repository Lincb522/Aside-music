// EnumsPropertyTests.swift
// 枚举属性测试
// 使用 SwiftCheck 验证所有 Swift 枚举 case 的 rawValue 与 TypeScript/API 定义完全匹配
// **Validates: Requirements 4.4**

import XCTest
import SwiftCheck
@testable import NeteaseCloudMusicAPI

final class EnumsPropertyTests: XCTestCase {

    /// 减少属性测试迭代次数以加快测试速度
    private let quickArgs = CheckerArguments(maxAllowableSuccessfulTests: 5)

    // MARK: - Property 11: 枚举 RawValue 匹配

    /// 属性测试 11：枚举 RawValue 匹配
    /// 对于所有定义的 Swift 枚举类型，每个枚举 case 的 rawValue
    /// 应该与 TypeScript interface.d.ts 中定义的原始 API 值完全匹配。
    /// 由于枚举是固定集合，使用 SwiftCheck 的 forAll 配合自定义生成器
    /// 遍历所有 CaseIterable 枚举的 case 进行验证。
    // **Validates: Requirements 4.4**

    // MARK: - SearchType rawValue 验证

    /// 验证 SearchType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_SearchType_RawValues() {
        // TypeScript 定义的期望映射：single=1, album=10, artist=100, playlist=1000,
        // user=1002, mv=1004, lyric=1006, dj=1009, video=1014, complex=1018
        let expectedMapping: [SearchType: Int] = [
            .single: 1,
            .album: 10,
            .artist: 100,
            .playlist: 1000,
            .user: 1002,
            .mv: 1004,
            .lyric: 1006,
            .dj: 1009,
            .video: 1014,
            .complex: 1018,
        ]

        // 验证枚举 case 数量与期望映射一致
        XCTAssertEqual(SearchType.allCases.count, expectedMapping.count,
                       "SearchType 的 case 数量应与 TypeScript 定义一致")

        // 使用 SwiftCheck 验证每个 case 的 rawValue
        property("SearchType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: SearchType.allCases)) { (searchType: SearchType) in
            guard let expected = expectedMapping[searchType] else {
                return false
            }
            return searchType.rawValue == expected
        }
    }

    // MARK: - CommentType rawValue 验证

    /// 验证 CommentType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_CommentType_RawValues() {
        // API resource types, including podcast comments.
        let expectedMapping: [CommentType: Int] = [
            .song: 0,
            .mv: 1,
            .playlist: 2,
            .album: 3,
            .dj: 4,
            .video: 5,
            .event: 6,
            .podcast: 7,
        ]

        XCTAssertEqual(CommentType.allCases.count, expectedMapping.count,
                       "CommentType 的 case 数量应与 TypeScript 定义一致")

        property("CommentType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: CommentType.allCases)) { (commentType: CommentType) in
            guard let expected = expectedMapping[commentType] else {
                return false
            }
            return commentType.rawValue == expected
        }
    }

    // MARK: - SubAction rawValue 验证

    /// 验证 SubAction 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_SubAction_RawValues() {
        // TypeScript 定义：unsub=0, sub=1
        let expectedMapping: [SubAction: Int] = [
            .unsub: 0,
            .sub: 1,
        ]

        XCTAssertEqual(SubAction.allCases.count, expectedMapping.count,
                       "SubAction 的 case 数量应与 TypeScript 定义一致")

        property("SubAction 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: SubAction.allCases)) { (action: SubAction) in
            guard let expected = expectedMapping[action] else {
                return false
            }
            return action.rawValue == expected
        }
    }

    // MARK: - CommentAction rawValue 验证

    /// 验证 CommentAction 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_CommentAction_RawValues() {
        // TypeScript 定义：delete=0, add=1, reply=2
        let expectedMapping: [CommentAction: Int] = [
            .delete: 0,
            .add: 1,
            .reply: 2,
        ]

        XCTAssertEqual(CommentAction.allCases.count, expectedMapping.count,
                       "CommentAction 的 case 数量应与 TypeScript 定义一致")

        property("CommentAction 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: CommentAction.allCases)) { (action: CommentAction) in
            guard let expected = expectedMapping[action] else {
                return false
            }
            return action.rawValue == expected
        }
    }

    // MARK: - BannerType rawValue 验证

    /// 验证 BannerType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_BannerType_RawValues() {
        // TypeScript 定义：pc=0, android=1, iphone=2, ipad=3
        let expectedMapping: [BannerType: Int] = [
            .pc: 0,
            .android: 1,
            .iphone: 2,
            .ipad: 3,
        ]

        XCTAssertEqual(BannerType.allCases.count, expectedMapping.count,
                       "BannerType 的 case 数量应与 TypeScript 定义一致")

        property("BannerType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: BannerType.allCases)) { (bannerType: BannerType) in
            guard let expected = expectedMapping[bannerType] else {
                return false
            }
            return bannerType.rawValue == expected
        }
    }

    // MARK: - ArtistArea rawValue 验证

    /// 验证 ArtistArea 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_ArtistArea_RawValues() {
        // TypeScript 定义：all="-1", zh="7", ea="96", ja="8", kr="16", other="0"
        let expectedMapping: [ArtistArea: String] = [
            .all: "-1",
            .zh: "7",
            .ea: "96",
            .ja: "8",
            .kr: "16",
            .other: "0",
        ]

        XCTAssertEqual(ArtistArea.allCases.count, expectedMapping.count,
                       "ArtistArea 的 case 数量应与 TypeScript 定义一致")

        property("ArtistArea 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: ArtistArea.allCases)) { (area: ArtistArea) in
            guard let expected = expectedMapping[area] else {
                return false
            }
            return area.rawValue == expected
        }
    }

    // MARK: - ArtistType rawValue 验证

    /// 验证 ArtistType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_ArtistType_RawValues() {
        // TypeScript 定义：male="1", female="2", band="3"
        let expectedMapping: [ArtistType: String] = [
            .male: "1",
            .female: "2",
            .band: "3",
        ]

        XCTAssertEqual(ArtistType.allCases.count, expectedMapping.count,
                       "ArtistType 的 case 数量应与 TypeScript 定义一致")

        property("ArtistType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: ArtistType.allCases)) { (artistType: ArtistType) in
            guard let expected = expectedMapping[artistType] else {
                return false
            }
            return artistType.rawValue == expected
        }
    }

    // MARK: - AlbumListArea rawValue 验证

    /// 验证 AlbumListArea 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_AlbumListArea_RawValues() {
        // TypeScript 定义：all="ALL", zh="ZH", ea="EA", kr="KR", jp="JP"
        let expectedMapping: [AlbumListArea: String] = [
            .all: "ALL",
            .zh: "ZH",
            .ea: "EA",
            .kr: "KR",
            .jp: "JP",
        ]

        XCTAssertEqual(AlbumListArea.allCases.count, expectedMapping.count,
                       "AlbumListArea 的 case 数量应与 TypeScript 定义一致")

        property("AlbumListArea 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: AlbumListArea.allCases)) { (area: AlbumListArea) in
            guard let expected = expectedMapping[area] else {
                return false
            }
            return area.rawValue == expected
        }
    }

    // MARK: - ListOrder rawValue 验证

    /// 验证 ListOrder 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_ListOrder_RawValues() {
        // TypeScript 定义：hot="hot", new="new"
        let expectedMapping: [ListOrder: String] = [
            .hot: "hot",
            .new: "new",
        ]

        XCTAssertEqual(ListOrder.allCases.count, expectedMapping.count,
                       "ListOrder 的 case 数量应与 TypeScript 定义一致")

        property("ListOrder 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: ListOrder.allCases)) { (order: ListOrder) in
            guard let expected = expectedMapping[order] else {
                return false
            }
            return order.rawValue == expected
        }
    }

    // MARK: - AlbumListStyleArea rawValue 验证

    /// 验证 AlbumListStyleArea 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_AlbumListStyleArea_RawValues() {
        // TypeScript 定义：zh="Z_H", ea="E_A", kr="KR", jp="JP"
        let expectedMapping: [AlbumListStyleArea: String] = [
            .zh: "Z_H",
            .ea: "E_A",
            .kr: "KR",
            .jp: "JP",
        ]

        XCTAssertEqual(AlbumListStyleArea.allCases.count, expectedMapping.count,
                       "AlbumListStyleArea 的 case 数量应与 TypeScript 定义一致")

        property("AlbumListStyleArea 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: AlbumListStyleArea.allCases)) { (area: AlbumListStyleArea) in
            guard let expected = expectedMapping[area] else {
                return false
            }
            return area.rawValue == expected
        }
    }

    // MARK: - AlbumSongsaleboardType rawValue 验证

    /// 验证 AlbumSongsaleboardType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_AlbumSongsaleboardType_RawValues() {
        // TypeScript 定义：daily="daily", week="week", year="year", total="total"
        let expectedMapping: [AlbumSongsaleboardType: String] = [
            .daily: "daily",
            .week: "week",
            .year: "year",
            .total: "total",
        ]

        XCTAssertEqual(AlbumSongsaleboardType.allCases.count, expectedMapping.count,
                       "AlbumSongsaleboardType 的 case 数量应与 TypeScript 定义一致")

        property("AlbumSongsaleboardType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: AlbumSongsaleboardType.allCases)) { (boardType: AlbumSongsaleboardType) in
            guard let expected = expectedMapping[boardType] else {
                return false
            }
            return boardType.rawValue == expected
        }
    }

    // MARK: - AlbumSongsaleboardAlbumType rawValue 验证

    /// 验证 AlbumSongsaleboardAlbumType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_AlbumSongsaleboardAlbumType_RawValues() {
        // TypeScript 定义：album=0, single=1
        let expectedMapping: [AlbumSongsaleboardAlbumType: Int] = [
            .album: 0,
            .single: 1,
        ]

        XCTAssertEqual(AlbumSongsaleboardAlbumType.allCases.count, expectedMapping.count,
                       "AlbumSongsaleboardAlbumType 的 case 数量应与 TypeScript 定义一致")

        property("AlbumSongsaleboardAlbumType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: AlbumSongsaleboardAlbumType.allCases)) { (albumType: AlbumSongsaleboardAlbumType) in
            guard let expected = expectedMapping[albumType] else {
                return false
            }
            return albumType.rawValue == expected
        }
    }

    // MARK: - ArtistListArea rawValue 验证

    /// 验证 ArtistListArea 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_ArtistListArea_RawValues() {
        // TypeScript 定义：zh="Z_H", ea="E_A", kr="KR", jp="JP"
        let expectedMapping: [ArtistListArea: String] = [
            .zh: "Z_H",
            .ea: "E_A",
            .kr: "KR",
            .jp: "JP",
        ]

        XCTAssertEqual(ArtistListArea.allCases.count, expectedMapping.count,
                       "ArtistListArea 的 case 数量应与 TypeScript 定义一致")

        property("ArtistListArea 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: ArtistListArea.allCases)) { (area: ArtistListArea) in
            guard let expected = expectedMapping[area] else {
                return false
            }
            return area.rawValue == expected
        }
    }

    // MARK: - ArtistSongsOrder rawValue 验证

    /// 验证 ArtistSongsOrder 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_ArtistSongsOrder_RawValues() {
        // TypeScript 定义：hot="hot", time="time"
        let expectedMapping: [ArtistSongsOrder: String] = [
            .hot: "hot",
            .time: "time",
        ]

        XCTAssertEqual(ArtistSongsOrder.allCases.count, expectedMapping.count,
                       "ArtistSongsOrder 的 case 数量应与 TypeScript 定义一致")

        property("ArtistSongsOrder 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: ArtistSongsOrder.allCases)) { (order: ArtistSongsOrder) in
            guard let expected = expectedMapping[order] else {
                return false
            }
            return order.rawValue == expected
        }
    }

    // MARK: - DailySigninType rawValue 验证

    /// 验证 DailySigninType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_DailySigninType_RawValues() {
        // TypeScript 定义：android=0, pc=1
        let expectedMapping: [DailySigninType: Int] = [
            .android: 0,
            .pc: 1,
        ]

        XCTAssertEqual(DailySigninType.allCases.count, expectedMapping.count,
                       "DailySigninType 的 case 数量应与 TypeScript 定义一致")

        property("DailySigninType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: DailySigninType.allCases)) { (signinType: DailySigninType) in
            guard let expected = expectedMapping[signinType] else {
                return false
            }
            return signinType.rawValue == expected
        }
    }

    // MARK: - MvArea rawValue 验证

    /// 验证 MvArea 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_MvArea_RawValues() {
        // TypeScript 定义：all="全部", zh="内地", hk="港台", ea="欧美", kr="韩国", jp="日本"
        let expectedMapping: [MvArea: String] = [
            .all: "全部",
            .zh: "内地",
            .hk: "港台",
            .ea: "欧美",
            .kr: "韩国",
            .jp: "日本",
        ]

        XCTAssertEqual(MvArea.allCases.count, expectedMapping.count,
                       "MvArea 的 case 数量应与 TypeScript 定义一致")

        property("MvArea 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: MvArea.allCases)) { (area: MvArea) in
            guard let expected = expectedMapping[area] else {
                return false
            }
            return area.rawValue == expected
        }
    }

    // MARK: - MvType rawValue 验证

    /// 验证 MvType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_MvType_RawValues() {
        // TypeScript 定义：all="全部", offical="官方版", raw="原生", live="现场版", netease="网易出品"
        let expectedMapping: [MvType: String] = [
            .all: "全部",
            .offical: "官方版",
            .raw: "原生",
            .live: "现场版",
            .netease: "网易出品",
        ]

        XCTAssertEqual(MvType.allCases.count, expectedMapping.count,
                       "MvType 的 case 数量应与 TypeScript 定义一致")

        property("MvType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: MvType.allCases)) { (mvType: MvType) in
            guard let expected = expectedMapping[mvType] else {
                return false
            }
            return mvType.rawValue == expected
        }
    }

    // MARK: - MvOrder rawValue 验证

    /// 验证 MvOrder 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_MvOrder_RawValues() {
        // TypeScript 定义：trend="上升最快", hot="最热", new="最新"
        let expectedMapping: [MvOrder: String] = [
            .trend: "上升最快",
            .hot: "最热",
            .new: "最新",
        ]

        XCTAssertEqual(MvOrder.allCases.count, expectedMapping.count,
                       "MvOrder 的 case 数量应与 TypeScript 定义一致")

        property("MvOrder 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: MvOrder.allCases)) { (order: MvOrder) in
            guard let expected = expectedMapping[order] else {
                return false
            }
            return order.rawValue == expected
        }
    }

    // MARK: - ResourceType rawValue 验证

    /// 验证 ResourceType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_ResourceType_RawValues() {
        // TypeScript 定义：mv=1, dj=4, video=5, event=6
        let expectedMapping: [ResourceType: Int] = [
            .mv: 1,
            .dj: 4,
            .video: 5,
            .event: 6,
        ]

        XCTAssertEqual(ResourceType.allCases.count, expectedMapping.count,
                       "ResourceType 的 case 数量应与 TypeScript 定义一致")

        property("ResourceType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: ResourceType.allCases)) { (resourceType: ResourceType) in
            guard let expected = expectedMapping[resourceType] else {
                return false
            }
            return resourceType.rawValue == expected
        }
    }

    // MARK: - SearchSuggestType rawValue 验证

    /// 验证 SearchSuggestType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_SearchSuggestType_RawValues() {
        // TypeScript 定义：mobile="mobile", web="web"
        let expectedMapping: [SearchSuggestType: String] = [
            .mobile: "mobile",
            .web: "web",
        ]

        XCTAssertEqual(SearchSuggestType.allCases.count, expectedMapping.count,
                       "SearchSuggestType 的 case 数量应与 TypeScript 定义一致")

        property("SearchSuggestType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: SearchSuggestType.allCases)) { (suggestType: SearchSuggestType) in
            guard let expected = expectedMapping[suggestType] else {
                return false
            }
            return suggestType.rawValue == expected
        }
    }

    // MARK: - ShareResourceType rawValue 验证

    /// 验证 ShareResourceType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_ShareResourceType_RawValues() {
        // TypeScript 定义：song="song", playlist="playlist", mv="mv", djprogram="djprogram", djradio="djradio"
        let expectedMapping: [ShareResourceType: String] = [
            .song: "song",
            .playlist: "playlist",
            .mv: "mv",
            .djprogram: "djprogram",
            .djradio: "djradio",
        ]

        XCTAssertEqual(ShareResourceType.allCases.count, expectedMapping.count,
                       "ShareResourceType 的 case 数量应与 TypeScript 定义一致")

        property("ShareResourceType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: ShareResourceType.allCases)) { (shareType: ShareResourceType) in
            guard let expected = expectedMapping[shareType] else {
                return false
            }
            return shareType.rawValue == expected
        }
    }

    // MARK: - SoundQualityType rawValue 验证

    /// 验证 SoundQualityType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_SoundQualityType_RawValues() {
        // Supported API quality levels, including higher and vivid.
        let expectedMapping: [SoundQualityType: String] = [
            .standard: "standard",
            .higher: "higher",
            .exhigh: "exhigh",
            .lossless: "lossless",
            .hires: "hires",
            .jyeffect: "jyeffect",
            .jymaster: "jymaster",
            .sky: "sky",
            .vivid: "vivid",
        ]

        XCTAssertEqual(SoundQualityType.allCases.count, expectedMapping.count,
                       "SoundQualityType 的 case 数量应与 TypeScript 定义一致")

        property("SoundQualityType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: SoundQualityType.allCases)) { (quality: SoundQualityType) in
            guard let expected = expectedMapping[quality] else {
                return false
            }
            return quality.rawValue == expected
        }
    }

    // MARK: - TopSongType rawValue 验证

    /// 验证 TopSongType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_TopSongType_RawValues() {
        // TypeScript 定义：all=0, zh=7, ea=96, kr=16, ja=8
        let expectedMapping: [TopSongType: Int] = [
            .all: 0,
            .zh: 7,
            .ea: 96,
            .kr: 16,
            .ja: 8,
        ]

        XCTAssertEqual(TopSongType.allCases.count, expectedMapping.count,
                       "TopSongType 的 case 数量应与 TypeScript 定义一致")

        property("TopSongType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: TopSongType.allCases)) { (songType: TopSongType) in
            guard let expected = expectedMapping[songType] else {
                return false
            }
            return songType.rawValue == expected
        }
    }

    // MARK: - ToplistArtistType rawValue 验证

    /// 验证 ToplistArtistType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_ToplistArtistType_RawValues() {
        // TypeScript 定义：zh=1, ea=2, kr=3, ja=4
        let expectedMapping: [ToplistArtistType: Int] = [
            .zh: 1,
            .ea: 2,
            .kr: 3,
            .ja: 4,
        ]

        XCTAssertEqual(ToplistArtistType.allCases.count, expectedMapping.count,
                       "ToplistArtistType 的 case 数量应与 TypeScript 定义一致")

        property("ToplistArtistType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: ToplistArtistType.allCases)) { (artistType: ToplistArtistType) in
            guard let expected = expectedMapping[artistType] else {
                return false
            }
            return artistType.rawValue == expected
        }
    }

    // MARK: - UserRecordType rawValue 验证

    /// 验证 UserRecordType 所有 case 的 rawValue 与 TypeScript 定义匹配
    func testProperty11_UserRecordType_RawValues() {
        // TypeScript 定义：all=0, weekly=1
        let expectedMapping: [UserRecordType: Int] = [
            .all: 0,
            .weekly: 1,
        ]

        XCTAssertEqual(UserRecordType.allCases.count, expectedMapping.count,
                       "UserRecordType 的 case 数量应与 TypeScript 定义一致")

        property("UserRecordType 所有 case 的 rawValue 与 TypeScript API 值匹配", arguments: quickArgs) <- forAllNoShrink(Gen.fromElements(of: UserRecordType.allCases)) { (recordType: UserRecordType) in
            guard let expected = expectedMapping[recordType] else {
                return false
            }
            return recordType.rawValue == expected
        }
    }

    // MARK: - 综合验证：所有枚举 CaseIterable 完整性

    /// 综合验证所有枚举的 case 数量，确保没有遗漏或多余的 case
    func testProperty11_AllEnums_CaseCount() {
        // 验证所有 Int 类型枚举的 case 数量
        XCTAssertEqual(SearchType.allCases.count, 10, "SearchType 应有 10 个 case")
        XCTAssertEqual(CommentType.allCases.count, 8, "CommentType 应有 8 个 case")
        XCTAssertEqual(SubAction.allCases.count, 2, "SubAction 应有 2 个 case")
        XCTAssertEqual(CommentAction.allCases.count, 3, "CommentAction 应有 3 个 case")
        XCTAssertEqual(BannerType.allCases.count, 4, "BannerType 应有 4 个 case")
        XCTAssertEqual(ResourceType.allCases.count, 4, "ResourceType 应有 4 个 case")
        XCTAssertEqual(DailySigninType.allCases.count, 2, "DailySigninType 应有 2 个 case")
        XCTAssertEqual(TopSongType.allCases.count, 5, "TopSongType 应有 5 个 case")
        XCTAssertEqual(ToplistArtistType.allCases.count, 4, "ToplistArtistType 应有 4 个 case")
        XCTAssertEqual(UserRecordType.allCases.count, 2, "UserRecordType 应有 2 个 case")
        XCTAssertEqual(AlbumSongsaleboardAlbumType.allCases.count, 2, "AlbumSongsaleboardAlbumType 应有 2 个 case")

        // 验证所有 String 类型枚举的 case 数量
        XCTAssertEqual(ArtistArea.allCases.count, 6, "ArtistArea 应有 6 个 case")
        XCTAssertEqual(ArtistType.allCases.count, 3, "ArtistType 应有 3 个 case")
        XCTAssertEqual(AlbumListArea.allCases.count, 5, "AlbumListArea 应有 5 个 case")
        XCTAssertEqual(ListOrder.allCases.count, 2, "ListOrder 应有 2 个 case")
        XCTAssertEqual(AlbumListStyleArea.allCases.count, 4, "AlbumListStyleArea 应有 4 个 case")
        XCTAssertEqual(AlbumSongsaleboardType.allCases.count, 4, "AlbumSongsaleboardType 应有 4 个 case")
        XCTAssertEqual(ArtistListArea.allCases.count, 4, "ArtistListArea 应有 4 个 case")
        XCTAssertEqual(ArtistSongsOrder.allCases.count, 2, "ArtistSongsOrder 应有 2 个 case")
        XCTAssertEqual(MvArea.allCases.count, 6, "MvArea 应有 6 个 case")
        XCTAssertEqual(MvType.allCases.count, 5, "MvType 应有 5 个 case")
        XCTAssertEqual(MvOrder.allCases.count, 3, "MvOrder 应有 3 个 case")
        XCTAssertEqual(SearchSuggestType.allCases.count, 2, "SearchSuggestType 应有 2 个 case")
        XCTAssertEqual(ShareResourceType.allCases.count, 5, "ShareResourceType 应有 5 个 case")
        XCTAssertEqual(SoundQualityType.allCases.count, 9, "SoundQualityType 应有 9 个 case")
    }

    // MARK: - Codable 往返验证

    /// 验证所有枚举的 Codable 编解码 round-trip 正确性
    /// 确保 JSON 编码后再解码能还原为相同的枚举值
    func testProperty11_AllEnums_CodableRoundTrip() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // 辅助函数：验证单个 CaseIterable & Codable 枚举的 round-trip
        func verifyCodableRoundTrip<T: CaseIterable & Codable & Equatable>(_ type: T.Type, name: String) {
            for enumCase in T.allCases {
                do {
                    let encoded = try encoder.encode(enumCase)
                    let decoded = try decoder.decode(T.self, from: encoded)
                    XCTAssertEqual(enumCase, decoded,
                                   "\(name) 的 Codable round-trip 失败：\(enumCase)")
                } catch {
                    XCTFail("\(name) 的 Codable 编解码出错：\(error)")
                }
            }
        }

        // 验证所有枚举类型
        verifyCodableRoundTrip(SearchType.self, name: "SearchType")
        verifyCodableRoundTrip(CommentType.self, name: "CommentType")
        verifyCodableRoundTrip(SubAction.self, name: "SubAction")
        verifyCodableRoundTrip(CommentAction.self, name: "CommentAction")
        verifyCodableRoundTrip(BannerType.self, name: "BannerType")
        verifyCodableRoundTrip(ArtistArea.self, name: "ArtistArea")
        verifyCodableRoundTrip(ArtistType.self, name: "ArtistType")
        verifyCodableRoundTrip(AlbumListArea.self, name: "AlbumListArea")
        verifyCodableRoundTrip(ListOrder.self, name: "ListOrder")
        verifyCodableRoundTrip(AlbumListStyleArea.self, name: "AlbumListStyleArea")
        verifyCodableRoundTrip(AlbumSongsaleboardType.self, name: "AlbumSongsaleboardType")
        verifyCodableRoundTrip(AlbumSongsaleboardAlbumType.self, name: "AlbumSongsaleboardAlbumType")
        verifyCodableRoundTrip(ArtistListArea.self, name: "ArtistListArea")
        verifyCodableRoundTrip(ArtistSongsOrder.self, name: "ArtistSongsOrder")
        verifyCodableRoundTrip(DailySigninType.self, name: "DailySigninType")
        verifyCodableRoundTrip(MvArea.self, name: "MvArea")
        verifyCodableRoundTrip(MvType.self, name: "MvType")
        verifyCodableRoundTrip(MvOrder.self, name: "MvOrder")
        verifyCodableRoundTrip(ResourceType.self, name: "ResourceType")
        verifyCodableRoundTrip(SearchSuggestType.self, name: "SearchSuggestType")
        verifyCodableRoundTrip(ShareResourceType.self, name: "ShareResourceType")
        verifyCodableRoundTrip(SoundQualityType.self, name: "SoundQualityType")
        verifyCodableRoundTrip(TopSongType.self, name: "TopSongType")
        verifyCodableRoundTrip(ToplistArtistType.self, name: "ToplistArtistType")
        verifyCodableRoundTrip(UserRecordType.self, name: "UserRecordType")
    }
}
