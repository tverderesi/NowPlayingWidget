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
                .frame(width: 136, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .center, spacing: 5) {
                Text(snapshot.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let artist = snapshot.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }

                if let album = snapshot.album, !album.isEmpty {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }

                Spacer()

                if snapshot.duration != nil, snapshot.elapsedTime != nil {
                    PlaybackProgressView(snapshot: snapshot)
                }

                HStack {
                    Image(systemName: snapshot.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    Text(snapshot.isPlaying ? "Playing" : "Paused")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
    }

}

private struct PlaybackProgressView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        if snapshot.isPlaying {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(at: context.date)
            }
        } else {
            content(at: snapshot.updatedAt)
        }
    }

    private func content(at date: Date) -> some View {
        let elapsed = elapsedTime(at: date)

        return VStack(spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: geometry.size.width * progress(elapsed: elapsed))
                }
            }
            .frame(height: 5)

            Text(Self.formattedDuration(elapsed))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func elapsedTime(at date: Date) -> Double {
        guard let elapsed = snapshot.elapsedTime else { return 0 }
        guard snapshot.isPlaying else { return elapsed }
        return min(snapshot.duration ?? .greatestFiniteMagnitude,
                   elapsed + max(0, date.timeIntervalSince(snapshot.updatedAt)))
    }

    private func progress(elapsed: Double) -> Double {
        guard let duration = snapshot.duration, duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    private static func formattedDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct SmallNowPlayingView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                ArtworkView(data: snapshot.artworkData)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.15),
                        .init(color: .black.opacity(0.58), location: 0.55),
                        .init(color: .black.opacity(0.96), location: 1)
                    ],
                    startPoint: .top,
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
                .padding(10)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(10)
                .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(ContainerRelativeShape())
            .compositingGroup()
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
                    .widgetAccentedRenderingMode(.fullColor)
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
