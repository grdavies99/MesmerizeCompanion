//
//  MediaStateObserver.swift
//  MesmerizeCompanion
//

import Foundation

/// Consumes the SSE stream at GET /media/stream and publishes live media state.
@Observable
final class MediaStateObserver: @unchecked Sendable {
    struct State {
        var position: Double = 0
        var volume: Double = 0
    }

    private(set) var state = State()
    private(set) var isConnected = false

    private var streamTask: Task<Void, Never>?

    func connect(to baseURL: URL) {
        disconnect()
        let url = baseURL.appendingPathComponent("media/stream")

        streamTask = Task { [weak self] in
            guard let self else { return }

            var request = URLRequest(url: url)
            request.timeoutInterval = .infinity

            // Use a dedicated session with a long timeout for SSE
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = .infinity
            config.timeoutIntervalForResource = .infinity
            let session = URLSession(configuration: config)

            do {
                let (bytes, response) = try await session.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    return
                }

                await MainActor.run { self.isConnected = true }

                for try await line in bytes.lines {
                    if Task.isCancelled { break }

                    // SSE format: "data: {...}\n"
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))
                    guard let data = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        continue
                    }

                    let position = json["position"] as? Double ?? 0
                    let volume = json["volume"] as? Double ?? 0

                    await MainActor.run {
                        self.state.position = position
                        self.state.volume = volume
                    }
                }
            } catch {
                // Stream ended or failed — expected on disconnect
            }

            await MainActor.run {
                self.isConnected = false
            }
            session.invalidateAndCancel()
        }
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        isConnected = false
    }
}
