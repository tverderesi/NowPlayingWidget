import ImageIO
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

            // Track changes trigger explicit reloads from the helper. The periodic refresh
            // recovers from any update the system may have coalesced while the helper slept.
            let nextRefresh = Date().addingTimeInterval(15 * 60)
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
        .description("Shows what macOS is currently playing.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct MediumNowPlayingView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(data: snapshot.artworkData)
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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

                Spacer()

                HStack {
                    Image(systemName: snapshot.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    Text(snapshot.isPlaying ? "Playing" : "Paused")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }
}

private struct SmallNowPlayingView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        GeometryReader { geometry in
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
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(ContainerRelativeShape())
        }
    }
}

private struct ArtworkView: View {
    let data: Data?

    var body: some View {
        Group {
            if let image = image {
                Image(decorative: image, scale: 1)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var image: CGImage? {
        guard let data else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
