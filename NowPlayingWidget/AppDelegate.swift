import AppKit
import ImageIO
import MediaRemoteAdapter
import WidgetKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mediaController = MediaController()
    private let localServer = LocalNowPlayingServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        localServer.start()
        localServer.update(.empty)

        mediaController.onTrackInfoReceived = { [weak self] trackInfo in
            self?.handle(trackInfo)
        }
        mediaController.onListenerTerminated = {
            NSLog("NowPlayingWidget: MediaRemote listener terminated")
        }
        mediaController.startListening()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaController.stopListening()
        localServer.stop()
    }

    private func handle(_ trackInfo: TrackInfo?) {
        guard let payload = trackInfo?.payload else {
            localServer.update(.empty)
            WidgetCenter.shared.reloadTimelines(ofKind: NowPlayingWidgetKind.identifier)
            return
        }

        let snapshot = NowPlayingSnapshot(
            title: payload.title ?? "Unknown Title",
            artist: payload.artist,
            album: payload.album,
            bundleIdentifier: payload.bundleIdentifier,
            isPlaying: payload.isPlaying ?? false,
            duration: payload.durationMicros.map { $0 / 1_000_000 },
            elapsedTime: payload.currentElapsedTime,
            updatedAt: .now,
            artworkData: jpegData(from: payload.artwork)
        )

        localServer.update(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: NowPlayingWidgetKind.identifier)
    }

    private func jpegData(from image: NSImage?) -> Data? {
        guard
            let image,
            let tiff = image.tiffRepresentation,
            let source = CGImageSourceCreateWithData(tiff as CFData, nil),
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 320
                ] as CFDictionary
            )
        else { return nil }

        return NSBitmapImageRep(cgImage: thumbnail)
            .representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}
