import Foundation

enum PlaybackMetrics {
    static func elapsedTime(for snapshot: NowPlayingSnapshot, at date: Date) -> Double {
        guard let elapsed = snapshot.elapsedTime else { return 0 }
        guard snapshot.isPlaying else { return max(0, elapsed) }
        return min(
            snapshot.duration ?? .greatestFiniteMagnitude,
            max(0, elapsed + date.timeIntervalSince(snapshot.updatedAt))
        )
    }

    static func progress(for snapshot: NowPlayingSnapshot, at date: Date) -> Double {
        guard let duration = snapshot.duration, duration > 0 else { return 0 }
        return min(max(elapsedTime(for: snapshot, at: date) / duration, 0), 1)
    }

    static func playbackInterval(for snapshot: NowPlayingSnapshot) -> ClosedRange<Date>? {
        guard snapshot.isPlaying,
              let duration = snapshot.duration, duration > 0,
              let elapsed = snapshot.elapsedTime else { return nil }
        let start = snapshot.updatedAt.addingTimeInterval(-elapsed)
        return start...start.addingTimeInterval(duration)
    }

    static func formattedDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
