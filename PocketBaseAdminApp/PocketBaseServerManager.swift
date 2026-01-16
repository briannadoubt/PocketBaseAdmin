//
//  PocketBaseServerManager.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import Foundation
import SwiftUI

/// Manages the lifecycle of a local PocketBase server instance
@Observable @MainActor
final class PocketBaseServerManager {

    enum ServerState: Equatable {
        case stopped
        case starting
        case running
        case stopping
        case error(String)

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }

        var canStart: Bool {
            switch self {
            case .stopped, .error: return true
            default: return false
            }
        }

        var canStop: Bool {
            switch self {
            case .running, .starting: return true
            default: return false
            }
        }
    }

    /// Current state of the server
    private(set) var state: ServerState = .stopped

    /// Console output logs
    private(set) var logs: [LogEntry] = []

    /// The running process
    private var process: Process?

    /// Output pipe for stdout
    private var stdoutPipe: Pipe?

    /// Output pipe for stderr
    private var stderrPipe: Pipe?

    /// Data directory for the PocketBase instance
    var dataDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PocketBaseAdmin/pb_data", isDirectory: true)
    }

    /// The port to run PocketBase on
    var port: Int = 8090

    /// Path to the PocketBase executable
    var executablePath: URL? {
        // First, check if bundled with the app
        if let bundledPath = Bundle.main.url(forResource: "container", withExtension: nil) {
            return bundledPath
        }

        // Check in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appSupportPath = appSupport.appendingPathComponent("PocketBaseAdmin/container")
        if FileManager.default.fileExists(atPath: appSupportPath.path) {
            return appSupportPath
        }

        // Check common locations
        let commonPaths = [
            "/usr/local/bin/pocketbase",
            "/opt/homebrew/bin/pocketbase",
            "~/.pocketbase/pocketbase"
        ]

        for path in commonPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return URL(fileURLWithPath: expandedPath)
            }
        }

        return nil
    }

    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let isError: Bool

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }

    init() {
        ensureDataDirectoryExists()
    }

    private func ensureDataDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: dataDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Start the PocketBase server
    func start() async {
        guard state.canStart else {
            appendLog("Cannot start server in current state", isError: true)
            return
        }

        guard let executable = executablePath else {
            state = .error("PocketBase executable not found")
            appendLog("Error: PocketBase executable not found. Please install PocketBase or place it in the app bundle.", isError: true)
            return
        }

        state = .starting
        appendLog("Starting PocketBase server...")

        let process = Process()
        self.process = process

        process.executableURL = executable
        process.arguments = [
            "serve",
            "--dir", dataDirectory.path,
            "--http", "127.0.0.1:\(port)"
        ]

        // Set up pipes for output capture
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Handle stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.processOutput(output, isError: false)
                }
            }
        }

        // Handle stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.processOutput(output, isError: true)
                }
            }
        }

        // Handle process termination
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleTermination(exitCode: process.terminationStatus)
            }
        }

        do {
            try process.run()

            // Wait a moment to check if the server started successfully
            try? await Task.sleep(for: .milliseconds(500))

            if process.isRunning {
                state = .running
                appendLog("Server is running on http://127.0.0.1:\(port)")
            }
        } catch {
            state = .error(error.localizedDescription)
            appendLog("Failed to start server: \(error.localizedDescription)", isError: true)
        }
    }

    /// Stop the PocketBase server
    func stop() {
        guard state.canStop else {
            appendLog("Cannot stop server in current state", isError: true)
            return
        }

        state = .stopping
        appendLog("Stopping PocketBase server...")

        // Send SIGTERM for graceful shutdown
        process?.terminate()

        // Give it a few seconds to shutdown gracefully
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            if self.process?.isRunning == true {
                self.appendLog("Force killing server...", isError: true)
                self.process?.interrupt()
            }
        }
    }

    /// Clear all logs
    func clearLogs() {
        logs.removeAll()
    }

    private func processOutput(_ output: String, isError: Bool) {
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        for line in lines {
            appendLog(line, isError: isError)
        }
    }

    private func appendLog(_ message: String, isError: Bool = false) {
        let entry = LogEntry(
            timestamp: Date(),
            message: message,
            isError: isError
        )
        logs.append(entry)

        // Keep log buffer reasonable
        if logs.count > 10000 {
            logs.removeFirst(1000)
        }
    }

    private func handleTermination(exitCode: Int32) {
        // Clean up pipes
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil

        if exitCode == 0 {
            state = .stopped
            appendLog("Server stopped")
        } else if case .stopping = state {
            state = .stopped
            appendLog("Server stopped (exit code: \(exitCode))")
        } else {
            state = .error("Server exited unexpectedly")
            appendLog("Server exited unexpectedly with code: \(exitCode)", isError: true)
        }
    }

}

// MARK: - Environment Key

private struct PocketBaseServerManagerKey: EnvironmentKey {
    static let defaultValue: PocketBaseServerManager? = nil
}

extension EnvironmentValues {
    var serverManager: PocketBaseServerManager? {
        get { self[PocketBaseServerManagerKey.self] }
        set { self[PocketBaseServerManagerKey.self] = newValue }
    }
}
#endif
