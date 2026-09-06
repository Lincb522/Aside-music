import XCTest
@testable import Mono

@MainActor
final class DownloadIdentityTests: XCTestCase {
    func testDownloadKeysKeepEveryPlatformSeparate() throws {
        let songs = try MusicSource.allCases.map { source in
            try JSONDecoder().decode(Song.self, from: Data("""
            {"id":42,"name":"Fixture","source":"\(source.rawValue)"}
            """.utf8))
        }
        let keys = songs.map { DownloadManager.makeKey(for: $0) }
        XCTAssertEqual(Set(keys).count, songs.count)
        XCTAssertEqual(keys.first, "ncm_42")
        XCTAssertTrue(keys.contains("qq_42"))
        XCTAssertTrue(keys.contains("qishui_42"))
    }
}
