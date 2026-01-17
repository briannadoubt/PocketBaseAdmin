//
//  Connection.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation

/// Represents a PocketBase server connection configuration
struct Connection: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier for this connection
    let id: UUID

    /// User-friendly name for this connection
    var name: String

    /// Hostname or IP address
    var host: String

    /// Port number
    var port: Int

    /// Whether to use TLS (https)
    var useTLS: Bool

    /// Whether this is a local instance managed by the app
    var isLocal: Bool

    /// Whether this connection was discovered via Bonjour
    var discoveredViaBonjour: Bool

    /// Last successful connection timestamp
    var lastConnected: Date?

    /// CloudKit record ID for sync
    var cloudKitRecordID: String?

    /// Computed URL for this connection
    var url: URL {
        let scheme = useTLS ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(port)")!
    }

    /// Admin dashboard URL
    var adminURL: URL {
        url.appendingPathComponent("_/")
    }

    /// Initialize a new connection
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 8090,
        useTLS: Bool = false,
        isLocal: Bool = false,
        discoveredViaBonjour: Bool = false,
        lastConnected: Date? = nil,
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.isLocal = isLocal
        self.discoveredViaBonjour = discoveredViaBonjour
        self.lastConnected = lastConnected
        self.cloudKitRecordID = cloudKitRecordID
    }
}

// MARK: - Convenience Initializers

extension Connection {
    /// Create a localhost connection
    static func localhost(port: Int = 8090) -> Connection {
        Connection(
            name: "Local Server",
            host: "127.0.0.1",
            port: port,
            useTLS: false,
            isLocal: true
        )
    }

    /// Create a connection from a URL
    static func from(url: URL, name: String? = nil) -> Connection? {
        guard let host = url.host else { return nil }
        let port = url.port ?? (url.scheme == "https" ? 443 : 80)
        let useTLS = url.scheme == "https"

        return Connection(
            name: name ?? host,
            host: host,
            port: port,
            useTLS: useTLS
        )
    }
}

// MARK: - Display Helpers

extension Connection {
    /// Display string for the connection URL
    var displayURL: String {
        let scheme = useTLS ? "https" : "http"
        let defaultPort = useTLS ? 443 : 80
        if port == defaultPort {
            return "\(scheme)://\(host)"
        }
        return "\(scheme)://\(host):\(port)"
    }

    /// Status icon based on connection type
    var statusIcon: String {
        if isLocal {
            return "externaldrive.fill"
        } else if discoveredViaBonjour {
            return "bonjour"
        } else {
            return "globe"
        }
    }
}
