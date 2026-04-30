//
//  MesmerizeService.swift
//  MesmerizeCompanion
//

import Foundation

/// Networking layer for the Mesmerize HTTP service.
actor MesmerizeService {
    nonisolated let baseURL: URL

    init(host: String, port: Int) {
        baseURL = URL(string: "http://\(host):\(port)")!
    }

    // MARK: - Health

    func healthCheck() async throws -> String {
        let url = baseURL.appendingPathComponent("health")
        let (data, _) = try await URLSession.shared.data(from: url)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Firefox

    enum FirefoxMode: String, CaseIterable, Identifiable {
        case newTab = "--new-tab"
        case newWindow = "--new-window"
        case privateWindow = "--private-window"
        case kiosk = "--kiosk"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .newTab:        return "New Tab"
            case .newWindow:     return "New Window"
            case .privateWindow: return "Private Window"
            case .kiosk:         return "Kiosk"
            }
        }

        var icon: String {
            switch self {
            case .newTab:        return "plus.square"
            case .newWindow:     return "macwindow.badge.plus"
            case .privateWindow: return "eye.slash"
            case .kiosk:         return "arrow.up.left.and.arrow.down.right"
            }
        }
    }

    func openFirefox(mode: FirefoxMode, url: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("firefox")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["args": [mode.rawValue, url]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Media

    enum MediaAction: String, CaseIterable, Identifiable {
        case playPause = "play-pause"
        case play
        case pause
        case next
        case previous
        case stop

        var id: String { rawValue }

        var label: String {
            switch self {
            case .playPause: return "Play / Pause"
            case .play:      return "Play"
            case .pause:     return "Pause"
            case .next:      return "Next"
            case .previous:  return "Previous"
            case .stop:      return "Stop"
            }
        }

        var icon: String {
            switch self {
            case .playPause: return "playpause.fill"
            case .play:      return "play.fill"
            case .pause:     return "pause.fill"
            case .next:      return "forward.fill"
            case .previous:  return "backward.fill"
            case .stop:      return "stop.fill"
            }
        }
    }

    func sendMediaAction(_ action: MediaAction) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("media")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["action": action.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(decoding: data, as: UTF8.self)
    }

    func skipToPosition(_ seconds: Double) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("media")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "skip", "position": seconds]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(decoding: data, as: UTF8.self)
    }

    func seek(offset seconds: Double) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("media")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "seek", "offset": seconds]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(decoding: data, as: UTF8.self)
    }

    func setVolume(level: Double) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("media")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "volume", "level": level]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(decoding: data, as: UTF8.self)
    }
}
