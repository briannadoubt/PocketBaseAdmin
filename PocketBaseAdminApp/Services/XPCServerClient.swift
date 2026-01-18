//
//  XPCServerClient.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import Foundation

/// Mach service name for XPC connection
private let kPocketBaseServerMachServiceName = "com.briannadoubt.PocketBaseAdmin.ServerHelper"

/// Protocol for XPC communication between the main app and the server helper
@objc protocol PocketBaseServerProtocol {
    func startServer(dataDirectory: String, port: Int, reply: @escaping (Bool, String?) -> Void)
    func stopServer(reply: @escaping (Bool) -> Void)
    func getServerStatus(reply: @escaping (Bool, Int) -> Void)
    func streamLogs(handler: @escaping (String, Bool) -> Void)
    func installPocketBase(version: String, reply: @escaping (Bool, String?) -> Void)
    func checkInstallation(reply: @escaping (Bool, String?) -> Void)
}

/// Client for communicating with the PocketBase server helper XPC service
@available(macOS 15.0, *)
@Observable @MainActor
final class XPCServerClient {
    /// Connection status
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    /// Server status from the helper
    enum ServerStatus: Equatable {
        case unknown
        case stopped
        case running(pid: Int)
        case starting
        case stopping
    }

    /// Current XPC connection status
    private(set) var connectionStatus: ConnectionStatus = .disconnected

    /// Current server status
    private(set) var serverStatus: ServerStatus = .unknown

    /// Whether PocketBase is installed
    private(set) var isInstalled: Bool = false

    /// Installed PocketBase version
    private(set) var installedVersion: String?

    /// Console logs
    private(set) var logs: [LogEntry] = []

    /// XPC connection
    private var connection: NSXPCConnection?

    /// Remote proxy object
    private var serverProxy: PocketBaseServerProtocol?

    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let isError: Bool
    }

    // MARK: - Lifecycle

    init() {}

    nonisolated func cleanup() {
        // Connection cleanup is safe from any context
        // The actual disconnection is handled by ARC
    }

    // MARK: - Connection Management

    /// Connect to the XPC service
    func connect() {
        // Allow connection if disconnected or in any error state (to enable retry after failures)
        switch connectionStatus {
        case .disconnected, .error:
            break
        case .connecting, .connected:
            return
        }

        connectionStatus = .connecting

        let connection = NSXPCConnection(serviceName: kPocketBaseServerMachServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: PocketBaseServerProtocol.self)

        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.handleInvalidation()
            }
        }

        connection.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.handleInterruption()
            }
        }

        connection.resume()
        self.connection = connection

        // Get the proxy
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self] error in
            Task { @MainActor in
                self?.connectionStatus = .error(error.localizedDescription)
            }
        }) as? PocketBaseServerProtocol else {
            connectionStatus = .error("Failed to get remote proxy")
            return
        }

        self.serverProxy = proxy
        connectionStatus = .connected

        // Check installation status
        checkInstallation()

        // Start receiving logs
        startLogStreaming()
    }

    /// Disconnect from the XPC service
    func disconnect() {
        connection?.invalidate()
        connection = nil
        serverProxy = nil
        connectionStatus = .disconnected
    }

    // MARK: - Server Operations

    /// Start the PocketBase server
    func startServer(dataDirectory: String, port: Int) async throws {
        guard let proxy = serverProxy else {
            throw XPCError.notConnected
        }

        serverStatus = .starting

        return try await withCheckedThrowingContinuation { continuation in
            proxy.startServer(dataDirectory: dataDirectory, port: port) { [weak self] success, error in
                Task { @MainActor in
                    if success {
                        self?.serverStatus = .running(pid: 0)
                        self?.refreshStatus()
                        continuation.resume()
                    } else {
                        self?.serverStatus = .stopped
                        continuation.resume(throwing: XPCError.operationFailed(error ?? "Unknown error"))
                    }
                }
            }
        }
    }

    /// Stop the PocketBase server
    func stopServer() async throws {
        guard let proxy = serverProxy else {
            throw XPCError.notConnected
        }

        serverStatus = .stopping

        return try await withCheckedThrowingContinuation { continuation in
            proxy.stopServer { [weak self] success in
                Task { @MainActor in
                    if success {
                        self?.serverStatus = .stopped
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: XPCError.operationFailed("Failed to stop server"))
                    }
                }
            }
        }
    }

    /// Refresh server status
    func refreshStatus() {
        guard let proxy = serverProxy else { return }

        proxy.getServerStatus { [weak self] isRunning, pid in
            Task { @MainActor in
                if isRunning {
                    self?.serverStatus = .running(pid: pid)
                } else {
                    self?.serverStatus = .stopped
                }
            }
        }
    }

    /// Install PocketBase
    func installPocketBase(version: String) async throws {
        guard let proxy = serverProxy else {
            throw XPCError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            proxy.installPocketBase(version: version) { [weak self] success, error in
                Task { @MainActor in
                    if success {
                        self?.isInstalled = true
                        self?.installedVersion = version
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: XPCError.operationFailed(error ?? "Installation failed"))
                    }
                }
            }
        }
    }

    /// Check if PocketBase is installed
    func checkInstallation() {
        guard let proxy = serverProxy else { return }

        proxy.checkInstallation { [weak self] installed, version in
            Task { @MainActor in
                self?.isInstalled = installed
                self?.installedVersion = version
            }
        }
    }

    // MARK: - Log Streaming

    private func startLogStreaming() {
        guard let proxy = serverProxy else { return }

        proxy.streamLogs { [weak self] message, isError in
            Task { @MainActor in
                self?.appendLog(message, isError: isError)
            }
        }
    }

    private func appendLog(_ message: String, isError: Bool) {
        let entry = LogEntry(timestamp: Date(), message: message, isError: isError)
        logs.append(entry)

        // Keep log buffer reasonable
        if logs.count > 10000 {
            logs.removeFirst(1000)
        }
    }

    /// Clear all logs
    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Error Handling

    private func handleInvalidation() {
        connectionStatus = .disconnected
        serverProxy = nil
    }

    private func handleInterruption() {
        connectionStatus = .error("Connection interrupted")
        serverProxy = nil
    }
}

// MARK: - Errors

enum XPCError: LocalizedError {
    case notConnected
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server helper"
        case .operationFailed(let message):
            return message
        }
    }
}
#endif
