import XCTest
@testable import Mono

final class ListeningPlaybackPolicyTests: XCTestCase {
    func testEffectivePlaybackThresholds() {
        XCTAssertEqual(
            ListeningPlaybackPolicy.effectivePlaybackThreshold(trackDuration: 8),
            6.4,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ListeningPlaybackPolicy.effectivePlaybackThreshold(trackDuration: 20),
            10,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ListeningPlaybackPolicy.effectivePlaybackThreshold(trackDuration: 60),
            30,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ListeningPlaybackPolicy.effectivePlaybackThreshold(trackDuration: 300),
            30,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ListeningPlaybackPolicy.effectivePlaybackThreshold(trackDuration: 0),
            30,
            accuracy: 0.001
        )
    }

    func testCompletionRequiresActualAudibleDuration() {
        XCTAssertFalse(
            ListeningPlaybackPolicy.isCompleted(
                actualPlayback: 60,
                trackDuration: 200
            )
        )
        XCTAssertTrue(
            ListeningPlaybackPolicy.isCompleted(
                actualPlayback: 180,
                trackDuration: 200
            )
        )
    }

    func testEffectiveAndCompletedAreIndependent() {
        XCTAssertTrue(
            ListeningPlaybackPolicy.isEffective(
                actualPlayback: 30,
                trackDuration: 240
            )
        )
        XCTAssertFalse(
            ListeningPlaybackPolicy.isCompleted(
                actualPlayback: 30,
                trackDuration: 240
            )
        )
    }

    func testLegacyHistoryRemainsVisibleAfterPolicyUpgrade() {
        let legacy = PlayHistory(
            songId: 1,
            songName: "Legacy",
            artistName: "Artist",
            playDuration: 1,
            completed: false,
            trackDuration: 0,
            effectivePlay: false,
            qualificationVersion: 0
        )

        XCTAssertTrue(ListeningPlaybackPolicy.isEffective(legacy))
    }

    func testCurrentHistoryUsesPersistedQualificationResult() {
        let current = PlayHistory(
            songId: 2,
            songName: "Current",
            artistName: "Artist",
            playDuration: 20,
            completed: false,
            trackDuration: 240,
            effectivePlay: false,
            qualificationVersion: ListeningPlaybackPolicy.qualificationVersion
        )

        XCTAssertFalse(ListeningPlaybackPolicy.isEffective(current))
        current.effectivePlay = true
        XCTAssertTrue(ListeningPlaybackPolicy.isEffective(current))
    }
}
