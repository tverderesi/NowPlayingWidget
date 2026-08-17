import XCTest

final class NowPlayingSnapshotTests: XCTestCase {
    func testCodableRoundTripPreservesArtworkAndMetadata() throws {
        let snapshot = NowPlayingSnapshot(
            title: "Precious",
            artist: "Depeche Mode",
            album: "Playing the Angel",
            bundleIdentifier: "com.example.player",
            isPlaying: true,
            duration: 250,
            elapsedTime: 42,
            updatedAt: Date(timeIntervalSinceReferenceDate: 1234),
            artworkData: Data([0, 1, 2, 3])
        )

        let decoded = try JSONDecoder().decode(
            NowPlayingSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        XCTAssertEqual(decoded, snapshot)
    }

    func testEstimatedElapsedTimeAdvancesAndClamps() {
        var snapshot = NowPlayingSnapshot.empty
        snapshot.isPlaying = true
        snapshot.duration = 10
        snapshot.elapsedTime = 9
        snapshot.updatedAt = Date().addingTimeInterval(-5)
        XCTAssertEqual(snapshot.estimatedElapsedTime, 10)
    }

    func testPausedEstimatedElapsedTimeDoesNotAdvance() {
        var snapshot = NowPlayingSnapshot.empty
        snapshot.elapsedTime = 9
        snapshot.updatedAt = Date().addingTimeInterval(-5)
        XCTAssertEqual(snapshot.estimatedElapsedTime, 9)
    }

    func testEmptySnapshotDefaults() {
        XCTAssertEqual(NowPlayingSnapshot.empty.title, "Nothing Playing")
        XCTAssertFalse(NowPlayingSnapshot.empty.isPlaying)
        XCTAssertNil(NowPlayingSnapshot.empty.artworkData)
    }
}
