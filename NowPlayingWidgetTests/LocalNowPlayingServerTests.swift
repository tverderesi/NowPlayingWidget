import Foundation
import XCTest

final class LocalNowPlayingServerTests: XCTestCase {
    private let port: UInt16 = 47392

    func testServerReturnsLatestSnapshotWithoutCaching() throws {
        let server = LocalNowPlayingServer(port: port)
        let ready = expectation(description: "listener ready")
        server.start { ready.fulfill() }
        wait(for: [ready], timeout: 2)
        defer { server.stop() }

        var expected = NowPlayingSnapshot.empty
        expected.title = "Lilian"
        expected.artist = "Depeche Mode"
        expected.artworkData = Data([4, 5, 6])
        server.update(expected)

        let response = try fetch()
        XCTAssertEqual(response.snapshot, expected)
        XCTAssertEqual(response.http.statusCode, 200)
        XCTAssertEqual(response.http.value(forHTTPHeaderField: "Cache-Control"), "no-store")
    }

    private func fetch() throws -> (snapshot: NowPlayingSnapshot, http: HTTPURLResponse) {
        let completed = expectation(description: "request completed")
        var result: Result<(NowPlayingSnapshot, HTTPURLResponse), Error>!
        URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:\(port)/now-playing")!) { data, response, error in
            result = Result {
                if let error { throw error }
                guard let data, let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                return (try JSONDecoder().decode(NowPlayingSnapshot.self, from: data), http)
            }
            completed.fulfill()
        }.resume()
        wait(for: [completed], timeout: 2)
        return try result.get()
    }
}
