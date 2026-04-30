//
//  BonjourBrowser.swift
//  MesmerizeCompanion
//

import Foundation
import Network

/// Discovers Mesmerize services advertised via mDNS (_http._tcp).
@Observable
final class BonjourBrowser {
    struct Service: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let host: String
        let port: Int
    }

    private(set) var services: [Service] = []
    private(set) var isSearching = false

    private var browser: NWBrowser?
    private var connections: [NWConnection] = []

    func startBrowsing() {
        guard browser == nil else { return }
        isSearching = true
        services = []

        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_mesmerize._tcp", domain: nil), using: params)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            for result in results {
                self.resolve(result: result)
            }
        }

        browser.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.stopBrowsing()
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        connections.removeAll()
        isSearching = false
    }

    private func resolve(result: NWBrowser.Result) {
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state {
                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                   case let .hostPort(host, port) = innerEndpoint {
                    var hostString: String
                    switch host {
                    case .ipv4(let addr):
                        hostString = "\(addr)"
                    case .ipv6(let addr):
                        hostString = "\(addr)"
                    case .name(let name, _):
                        hostString = name
                    @unknown default:
                        hostString = "\(host)"
                    }
                    // Strip IPv6 zone ID (e.g. "%en0") — not valid in URLs
                    if let percentIndex = hostString.firstIndex(of: "%") {
                        hostString = String(hostString[..<percentIndex])
                    }
                    let portInt = Int(port.rawValue)
                    let name: String
                    if case let .service(svcName, _, _, _) = result.endpoint {
                        name = svcName
                    } else {
                        name = "Mesmerize"
                    }
                    // Avoid duplicates
                    if !self.services.contains(where: { $0.host == hostString && $0.port == portInt }) {
                        self.services.append(Service(name: name, host: hostString, port: portInt))
                    }
                }
                connection.cancel()
            }
        }

        connection.start(queue: .main)
    }
}
