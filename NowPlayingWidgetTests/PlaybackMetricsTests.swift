import XCTest

final class PlaybackMetricsTests: XCTestCase {
    private let updatedAt = Date(timeIntervalSinceReferenceDate: 1_000)

    func testPlayingElapsedTimeAdvances() {
        let snapshot = makeSnapshot(isPlaying: true, duration: 300, elapsed: 40)
        XCTAssertEqual(PlaybackMetrics.elapsedTime(for: snapshot, at: updatedAt.addingTimeInterval(12)), 52)
    }

    func testPausedElapsedTimeStaysFrozen() {
        let snapshot = makeSnapshot(isPlaying: false, duration: 300, elapsed: 40)
        XCTAssertEqual(PlaybackMetrics.elapsedTime(for: snapshot, at: updatedAt.addingTimeInterval(12)), 40)
        XCTAssertEqual(PlaybackMetrics.progress(for: snapshot, at: updatedAt.addingTimeInterval(12)), 40.0 / 300.0, accuracy: 0.0001)
    }

    func testProgressClampsAtDuration() {
        let snapshot = makeSnapshot(isPlaying: true, duration: 60, elapsed: 59)
        XCTAssertEqual(PlaybackMetrics.elapsedTime(for: snapshot, at: updatedAt.addingTimeInterval(10)), 60)
        XCTAssertEqual(PlaybackMetrics.progress(for: snapshot, at: updatedAt.addingTimeInterval(10)), 1)
    }

    func testInvalidDurationHasNoProgressOrInterval() {
        let snapshot = makeSnapshot(isPlaying: true, duration: 0, elapsed: 10)
        XCTAssertEqual(PlaybackMetrics.progress(for: snapshot, at: updatedAt), 0)
        XCTAssertNil(PlaybackMetrics.playbackInterval(for: snapshot))
    }

    func testDurationFormatting() {
        XCTAssertEqual(PlaybackMetrics.formattedDuration(0), "0:00")
        XCTAssertEqual(PlaybackMetrics.formattedDuration(99.9), "1:39")
        XCTAssertEqual(PlaybackMetrics.formattedDuration(-3), "0:00")
    }

    private func makeSnapshot(isPlaying: Bool, duration: Double, elapsed: Double) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: "Test",
            artist: nil,
            album: nil,
            bundleIdentifier: nil,
            isPlaying: isPlaying,
            duration: duration,
            elapsedTime: elapsed,
            updatedAt: updatedAt,
            artworkData: nil
        )
    }
}
