import AppKit
import SwiftUI
import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot
}

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(
            date: .now,
            snapshot: NowPlayingSnapshot(
                title: "Blue Monday",
                artist: "New Order",
                album: "Power, Corruption & Lies",
                bundleIdentifier: nil,
                isPlaying: true,
                duration: 447,
                elapsedTime: 118,
                updatedAt: .now,
                artworkData: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        NowPlayingBridge.fetch { snapshot in
            completion(NowPlayingEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        NowPlayingBridge.fetch { snapshot in
            let entry = NowPlayingEntry(date: .now, snapshot: snapshot)

            // Track changes trigger explicit reloads from the helper. This periodic refresh
            // mainly keeps the displayed progress approximately current while playing.
            let nextRefresh = Date().addingTimeInterval(snapshot.isPlaying ? 60 : 15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

struct NowPlayingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NowPlayingEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallNowPlayingView(snapshot: entry.snapshot)
        default:
            MediumNowPlayingView(snapshot: entry.snapshot)
        }
    }
}

struct NowPlayingWidget: Widget {
    let kind = NowPlayingWidgetKind.identifier

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("Shows whatever macOS is currently playing, including Doppler.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct MediumNowPlayingView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(data: snapshot.artworkData)
                .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.title)
                    .font(.headline)
                    .lineLimit(2)

                if let artist = snapshot.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let album = snapshot.album, !album.isEmpty {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 3)
                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                HStack {
                    Image(systemName: snapshot.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    Text(snapshot.isPlaying ? "Playing" : "Paused")
                    Spacer()
                    if let elapsed = snapshot.estimatedElapsedTime,
                       let duration = snapshot.duration {
                        Text("\(format(elapsed)) / \(format(duration))")
                            .monospacedDigit()
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private var progress: Double {
        guard let duration = snapshot.duration, duration > 0,
              let elapsed = snapshot.estimatedElapsedTime else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    private func format(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct SmallNowPlayingView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(data: snapshot.artworkData)

            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let artist = snapshot.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
    }
}

private struct ArtworkView: View {
    let data: Data?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var image: NSImage? {
        guard let data else { return nil }
        return NSImage(data: data)
    }
}
