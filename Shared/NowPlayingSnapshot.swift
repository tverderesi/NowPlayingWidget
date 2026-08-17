import Foundation

struct NowPlayingSnapshot: Codable, Equatable {
    var title: String
    var artist: String?
    var album: String?
    var bundleIdentifier: String?
    var isPlaying: Bool
    var duration: Double?
    var elapsedTime: Double?
    var updatedAt: Date
    var artworkData: Data?

    static let empty = NowPlayingSnapshot(
        title: "Nothing Playing",
        artist: nil,
        album: nil,
        bundleIdentifier: nil,
        isPlaying: false,
        duration: nil,
        elapsedTime: nil,
        updatedAt: .now,
        artworkData: nil
    )

    var estimatedElapsedTime: Double? {
        guard let elapsedTime else { return nil }
        guard isPlaying else { return elapsedTime }
        return min(duration ?? .greatestFiniteMagnitude, elapsedTime + Date().timeIntervalSince(updatedAt))
    }
}

enum NowPlayingBridge {
    static let port: UInt16 = 47391
    static let url = URL(string: "http://127.0.0.1:\(port)/now-playing")!

    static func fetch(completion: @escaping (NowPlayingSnapshot) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let snapshot = data.flatMap { try? JSONDecoder().decode(NowPlayingSnapshot.self, from: $0) } ?? .empty
            DispatchQueue.main.async {
                completion(snapshot)
            }
        }.resume()
    }
}
