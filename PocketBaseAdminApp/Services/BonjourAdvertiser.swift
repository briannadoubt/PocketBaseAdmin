//
//  BonjourAdvertiser.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import Network

/// Advertises a local PocketBase instance on the network using Bonjour/mDNS
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
@Observable @MainActor
final class BonjourAdvertiser {
    /// Whether the advertiser is currently active
    private(set) var isAdvertising: Bool = false

    /// Current advertised name
    private(set) var advertisedName: String?

    /// Current advertised port
    private(set) var advertisedPort: Int?

    /// The network listener for advertising
    private var listener: NWListener?

    /// Queue for listener operations
    private let queue = DispatchQueue(label: "com.briannadoubt.PocketBaseAdmin.advertiser")

    // MARK: - Lifecycle

    init() {}

    // MARK: - Advertising

    /// Start advertising a PocketBase instance
    /// - Parameters:
    ///   - name: Display name for the instance
    ///   - port: Port the instance is running on
    ///   - iCloudAccountHash: Optional iCloud account hash for filtering discovery
    func advertise(name: String, port: Int, iCloudAccountHash: String? = nil) throws {
        // Stop any existing advertisement
        stopAdvertising()

        // Create TXT record with metadata
        var txtDict: [String: String] = ["version": "1"]
        if let accountHash = iCloudAccountHash {
            txtDict["account"] = accountHash
        }
        let txtRecord = NWTXTRecord(txtDict)

        // Create listener parameters
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        // Create the listener
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw BonjourAdvertiserError.invalidPort
        }

        let listener = try NWListener(using: parameters, on: nwPort)

        // Set up the service
        listener.service = NWListener.Service(
            name: name,
            type: BonjourBrowser.serviceType,
            txtRecord: txtRecord
        )

        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleStateUpdate(state)
            }
        }

        listener.serviceRegistrationUpdateHandler = { [weak self] change in
            Task { @MainActor in
                self?.handleServiceRegistration(change)
            }
        }

        // We don't actually accept connections - just advertise
        listener.newConnectionHandler = { connection in
            connection.cancel()
        }

        self.listener = listener
        self.advertisedName = name
        self.advertisedPort = port

        listener.start(queue: queue)
    }

    /// Stop advertising
    func stopAdvertising() {
        listener?.cancel()
        listener = nil
        isAdvertising = false
        advertisedName = nil
        advertisedPort = nil
    }

    // MARK: - State Handling

    private func handleStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            isAdvertising = true
        case .failed(let error):
            print("Bonjour advertiser failed: \(error)")
            isAdvertising = false
        case .cancelled:
            isAdvertising = false
        default:
            break
        }
    }

    private func handleServiceRegistration(_ change: NWListener.ServiceRegistrationChange) {
        switch change {
        case .add(let endpoint):
            if case .service(let name, _, _, _) = endpoint {
                advertisedName = name
            }
        case .remove:
            // Service was removed
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Errors

enum BonjourAdvertiserError: LocalizedError {
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .invalidPort:
            return "Invalid port number"
        }
    }
}
