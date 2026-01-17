//
//  PocketBaseServerProtocol.swift
//  PocketBaseServerHelper
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation

/// Protocol for XPC communication between the main app and the server helper
@objc public protocol PocketBaseServerProtocol {
    /// Start a PocketBase server with the specified configuration
    /// - Parameters:
    ///   - dataDirectory: Path to the pb_data directory
    ///   - port: Port to run the server on
    ///   - reply: Callback with success status and optional error message
    func startServer(
        dataDirectory: String,
        port: Int,
        reply: @escaping (Bool, String?) -> Void
    )

    /// Stop the currently running PocketBase server
    /// - Parameter reply: Callback with success status
    func stopServer(reply: @escaping (Bool) -> Void)

    /// Get the current server status
    /// - Parameter reply: Callback with running status and optional PID
    func getServerStatus(reply: @escaping (Bool, Int) -> Void)

    /// Stream server logs to the main app
    /// - Parameter handler: Callback for each log line with message and isError flag
    func streamLogs(handler: @escaping (String, Bool) -> Void)

    /// Download and install PocketBase if not present
    /// - Parameters:
    ///   - version: PocketBase version to install
    ///   - reply: Callback with success status and optional error message
    func installPocketBase(
        version: String,
        reply: @escaping (Bool, String?) -> Void
    )

    /// Check if PocketBase is installed
    /// - Parameter reply: Callback with installation status and version if installed
    func checkInstallation(reply: @escaping (Bool, String?) -> Void)
}

/// Error types for the server helper
public enum PocketBaseServerError: Int, Error {
    case alreadyRunning = 1
    case notRunning = 2
    case installationFailed = 3
    case startFailed = 4
    case stopFailed = 5
    case invalidConfiguration = 6

    public var localizedDescription: String {
        switch self {
        case .alreadyRunning:
            return "Server is already running"
        case .notRunning:
            return "Server is not running"
        case .installationFailed:
            return "Failed to install PocketBase"
        case .startFailed:
            return "Failed to start server"
        case .stopFailed:
            return "Failed to stop server"
        case .invalidConfiguration:
            return "Invalid server configuration"
        }
    }
}

/// Mach service name for XPC connection
public let kPocketBaseServerMachServiceName = "com.briannadoubt.PocketBaseAdmin.ServerHelper"
