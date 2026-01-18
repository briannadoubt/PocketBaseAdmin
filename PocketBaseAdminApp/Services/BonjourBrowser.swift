//
//  BonjourBrowser.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import Network

/// Browses for PocketBase instances on the local network using Bonjour/mDNS
@Observable @MainActor
final class BonjourBrowser {
    /// Service type for PocketBase instances
    static let serviceType = "_pocketbase._tcp"

    /// Discovered instances on the network
    private(set) var discoveredInstances: [DiscoveredInstance] = []

    /// Whether the browser is actively scanning
    private(set) var isSearching: Bool = false

    /// The network browser
    private var browser: NWBrowser?

    /// Queue for browser operations
    private let queue = DispatchQueue(label: "com.briannadoubt.PocketBaseAdmin.bonjour")

    /// Optional iCloud account hash for filtering
    var iCloudAccountHash: String?

    // MARK: - Types

    /// A discovered PocketBase instance on the network
    struct DiscoveredInstance: Identifiable, Equatable, Sendable {
        let id: UUID
        let name: String
        let host: String
        let port: Int
        let txtRecord: [String: String]

        /// iCloud account hash from TXT record (for filtering)
        var accountHash: String? {
            txtRecord["account"]
        }

        /// Whether this instance belongs to the same iCloud account
        func matchesAccount(_ hash: String?) -> Bool {
            guard let hash, let accountHash else { return true }
            return hash == accountHash
        }
    }

    // MARK: - Lifecycle

    init() {}

    // MARK: - Browsing

    /// Start browsing for PocketBase instances on the network
    func startBrowsing() {
        guard browser == nil else { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleStateUpdate(state)
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleResultsChanged(results: results, changes: changes)
            }
        }

        self.browser = browser
        browser.start(queue: queue)
        isSearching = true
    }

    /// Stop browsing for PocketBase instances
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isSearching = false
        discoveredInstances.removeAll()
    }

    // MARK: - State Handling

    private func handleStateUpdate(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            isSearching = true
        case .failed(let error):
            print("Bonjour browser failed: \(error)")
            isSearching = false
        case .cancelled:
            isSearching = false
        default:
            break
        }
    }

    private func handleResultsChanged(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        // Process changes
        for change in changes {
            switch change {
            case .added(let result):
                resolveEndpoint(result)
            case .removed(let result):
                removeInstance(for: result)
            case .changed(old: let old, new: let new, flags: _):
                removeInstance(for: old)
                resolveEndpoint(new)
            case .identical:
                break
            @unknown default:
                break
            }
        }
    }

    private func resolveEndpoint(_ result: NWBrowser.Result) {
        // Extract name from the result
        let serviceName: String
        switch result.endpoint {
        case .service(let name, _, _, _):
            serviceName = name
        default:
            return
        }

        // Create a connection to resolve the endpoint
        let connection = NWConnection(to: result.endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self, serviceName] state in
            if case .ready = state {
                // Get the resolved address
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {

                    let hostString: String
                    switch host {
                    case .ipv4(let addr):
                        hostString = "\(addr)"
                    case .ipv6(let addr):
                        // Get the string representation and strip scope ID (e.g., %en0)
                        // Scope IDs are local and not valid in URLs
                        var ipv6String = "\(addr)"
                        if let scopeIndex = ipv6String.firstIndex(of: "%") {
                            ipv6String = String(ipv6String[..<scopeIndex])
                        }
                        hostString = ipv6String
                    case .name(let hostname, _):
                        hostString = hostname
                    @unknown default:
                        hostString = "unknown"
                    }

                    // Parse TXT record from metadata if available
                    let txtRecord = Self.extractTXTRecord(from: result.metadata)

                    let instance = DiscoveredInstance(
                        id: UUID(),
                        name: serviceName,
                        host: hostString,
                        port: Int(port.rawValue),
                        txtRecord: txtRecord
                    )

                    Task { @MainActor [weak self] in
                        self?.addOrUpdateInstance(instance)
                    }
                }
                connection.cancel()
            }
        }

        connection.start(queue: queue)

        // Cancel after timeout
        queue.asyncAfter(deadline: .now() + 5) {
            connection.cancel()
        }
    }

    private func addOrUpdateInstance(_ instance: DiscoveredInstance) {
        // Filter by iCloud account if available
        guard instance.matchesAccount(iCloudAccountHash) else { return }

        // Check if we already have this instance (by host and port)
        if let index = discoveredInstances.firstIndex(where: { $0.host == instance.host && $0.port == instance.port }) {
            discoveredInstances[index] = instance
        } else {
            discoveredInstances.append(instance)
        }
    }

    private func removeInstance(for result: NWBrowser.Result) {
        switch result.endpoint {
        case .service(let name, _, _, _):
            discoveredInstances.removeAll { $0.name == name }
        default:
            break
        }
    }

    // MARK: - TXT Record Parsing

    private nonisolated static func extractTXTRecord(from metadata: NWBrowser.Result.Metadata?) -> [String: String] {
        guard let metadata else { return [:] }

        var result: [String: String] = [:]

        switch metadata {
        case .bonjour(let txtRecord):
            // Parse the TXT record - NWTXTRecord.dictionary is [String: String]
            for (key, value) in txtRecord.dictionary {
                result[key] = value
            }
        default:
            break
        }

        return result
    }
}
