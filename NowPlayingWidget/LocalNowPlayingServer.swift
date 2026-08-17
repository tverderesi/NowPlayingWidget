import Foundation
import Network

final class LocalNowPlayingServer {
    private let queue = DispatchQueue(label: "NowPlayingWidget.LocalServer")
    private var listener: NWListener?
    private let lock = NSLock()
    private var snapshot: NowPlayingSnapshot = .empty

    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let port = NWEndpoint.Port(rawValue: NowPlayingBridge.port)!
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
            listener = try NWListener(using: parameters, on: port)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener?.stateUpdateHandler = { state in
                if case let .failed(error) = state {
                    NSLog("NowPlayingWidget: local bridge failed: \(error)")
                }
            }
            listener?.start(queue: queue)
        } catch {
            NSLog("NowPlayingWidget: couldn't start local bridge: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func update(_ snapshot: NowPlayingSnapshot) {
        lock.lock()
        self.snapshot = snapshot
        lock.unlock()
    }

    private func currentSnapshot() -> NowPlayingSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] _, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            let body = (try? JSONEncoder().encode(self.currentSnapshot())) ?? Data("{}".utf8)
            let headers = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            var response = Data(headers.utf8)
            response.append(body)

            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
