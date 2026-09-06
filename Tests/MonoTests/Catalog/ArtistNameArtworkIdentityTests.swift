import XCTest
@testable import Mono

final class ArtistNameArtworkIdentityTests: XCTestCase {
    func testExactNameExcludesTributeActsAndPartialMatches() {
        let identity = ArtistNameArtworkIdentity(name: "Taylor Swift", aliases: [], qqMid: nil)
        XCTAssertEqual(identity.matchingMIDs(in: [
            ("Taylor Swift Tribute Band", "tribute"),
            ("Taylor Swifte", "different"),
            (" TAYLOR  SWIFT ", "taylor")
        ]), ["taylor"])
    }

    func testKnownAliasResolvesAnotherPlatformName() {
        let identity = ArtistNameArtworkIdentity(name: "泰勒·斯威夫特", aliases: ["Taylor Swift"], qqMid: nil)
        XCTAssertEqual(identity.matchingMIDs(in: [("Taylor Swift", "taylor")]), ["taylor"])
    }

    func testDuplicateResultsDoNotHideAmbiguousArtists() {
        let identity = ArtistNameArtworkIdentity(name: "同名歌手", aliases: [], qqMid: nil)
        XCTAssertEqual(identity.matchingMIDs(in: [("同名歌手", "first"), ("同名歌手", "first")]), ["first"])
        XCTAssertEqual(identity.matchingMIDs(in: [("同名歌手", "first"), ("同名歌手", "second")]).count, 2)
    }

    func testEmptyNamesAndMissingIdentifiersDoNotMatch() {
        let empty = ArtistNameArtworkIdentity(name: " ", aliases: [""], qqMid: nil)
        XCTAssertTrue(empty.matchingMIDs(in: [(" ", "mid")]).isEmpty)
        let named = ArtistNameArtworkIdentity(name: "Singer", aliases: [], qqMid: nil)
        XCTAssertTrue(named.matchingMIDs(in: [("Singer", "")]).isEmpty)
    }
}
