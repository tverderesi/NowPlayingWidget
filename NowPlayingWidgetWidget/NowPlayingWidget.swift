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

            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let artist = snapshot.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                }

                if let album = snapshot.album, !album.isEmpty {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                }

                if snapshot.duration != nil, snapshot.elapsedTime != nil {
                    PlaybackProgressView(snapshot: snapshot)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }

}

private struct PlaybackProgressView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let playbackInterval = PlaybackMetrics.playbackInterval(for: snapshot) {
                ProgressView(timerInterval: playbackInterval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
            } else {
                ProgressView(value: PlaybackMetrics.progress(for: snapshot, at: snapshot.updatedAt))
                    .progressViewStyle(.linear)
            }

            HStack {
                Image(systemName: snapshot.isPlaying ? "play.fill" : "pause.fill")
                Spacer()
                elapsedTimeLabel
            }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var elapsedTimeLabel: some View {
        if snapshot.isPlaying, let playbackStart {
            Text(playbackStart, style: .timer)
        } else {
            Text(PlaybackMetrics.formattedDuration(snapshot.elapsedTime ?? 0))
        }
    }

    private var playbackStart: Date? {
        guard let elapsed = snapshot.elapsedTime else { return nil }
        return snapshot.updatedAt.addingTimeInterval(-elapsed)
    }

}

private struct SmallNowPlayingView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                ArtworkView(data: snapshot.artworkData, addsBottomGradient: true)

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
                .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
                .widgetAccentable(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(ContainerRelativeShape())
            .compositingGroup()
        }
    }
}

private struct ArtworkView: View {
    let data: Data?
    var addsBottomGradient = false

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
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return addsBottomGradient ? image.addingBottomGradient() : image
    }
}

private extension CGImage {
    func addingBottomGradient() -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return self }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        let colors = [
            CGColor(gray: 0, alpha: 0.96),
            CGColor(gray: 0, alpha: 0.62),
            CGColor(gray: 0, alpha: 0)
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceGray(),
            colors: colors,
            locations: [0, 0.48, 1]
        ) else { return self }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: CGFloat(height) * 0.72),
            options: []
        )
        return context.makeImage() ?? self
    }
}
