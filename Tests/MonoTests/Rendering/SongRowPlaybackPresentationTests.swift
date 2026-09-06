import XCTest
@testable import Mono

@MainActor
final class SongRowPlaybackPresentationTests: XCTestCase {
    func testUnrelatedRowsKeepTheSamePresentationAcrossPlaybackChanges() throws {
        let first = try song(id: 1)
        let next = try song(id: 2)
        for id in 3...200 {
            let row = try song(id: id)
            let before = presentation(row, current: first, playing: true)
            let after = presentation(row, current: next, pending: next, playing: false, loading: true)
            XCTAssertEqual(before, after)
        }
    }

    func testCurrentAndPendingRowsKeepTheirDistinctIndicators() throws {
        let current = try song(id: 1)
        let pending = try song(id: 2)
        let currentState = presentation(current, current: current, pending: pending, playing: true, loading: true)
        let pendingState = presentation(pending, current: current, pending: pending, playing: true, loading: true)
        XCTAssertTrue(currentState.isCurrent)
        XCTAssertTrue(currentState.isPlaying)
        XCTAssertFalse(currentState.isLoading)
        XCTAssertFalse(pendingState.isCurrent)
        XCTAssertFalse(pendingState.isPlaying)
        XCTAssertTrue(pendingState.isLoading)

        let paused = presentation(current, current: current, playing: false)
        XCTAssertTrue(paused.isCurrent)
        XCTAssertFalse(paused.isPlaying)
    }

    func testPlatformAndQQMidRemainPartOfTheRowIdentity() throws {
        let ncm = try song(id: 42)
        let qq = try song(id: 42, source: .qqmusic, mid: "first")
        let otherQQ = try song(id: 42, source: .qqmusic, mid: "second")
        XCTAssertFalse(presentation(qq, current: ncm, playing: true).isCurrent)
        XCTAssertFalse(presentation(otherQQ, current: qq, playing: true).isCurrent)
        XCTAssertNotEqual(
            presentation(qq, current: nil).playbackIdentity,
            presentation(otherQQ, current: nil).playbackIdentity
        )
    }

    func testFirstTrackLoadingKeepsItsLoadingIndicator() throws {
        let current = try song(id: 1)
        XCTAssertTrue(presentation(current, current: current, playing: false, loading: true).isLoading)
        XCTAssertFalse(presentation(current, current: current, playing: true, loading: true).isLoading)
    }

    private func presentation(
        _ song: Song,
        current: Song?,
        pending: Song? = nil,
        playing: Bool = false,
        loading: Bool = false
    ) -> SongRowPlaybackModel.Presentation {
        SongRowPlaybackModel.presentation(for: song, currentSong: current, pendingSong: pending, isPlaying: playing, isLoading: loading)
    }

    private func song(id: Int, source: MusicSource = .netease, mid: String? = nil) throws -> Song {
        var fields: [String: Any] = ["id": id, "name": "Fixture", "source": source.rawValue]
        if let mid { fields["qqMid"] = mid }
        return try JSONDecoder().decode(Song.self, from: JSONSerialization.data(withJSONObject: fields))
    }
}
