//
//  PocketBaseServerManager.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import Foundation
import SwiftUI
import Subprocess

/// Manages the lifecycle of a local PocketBase server instance
@available(macOS 15.0, *)
@Observable @MainActor
final class PocketBaseServerManager {

    enum ServerState: Equatable {
        case stopped
        case starting
        case running
        case stopping
        case downloading
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

    /// The port PocketBase runs on
    let port: Int = 8090

    /// Task running the server process
    private var serverTask: Task<Void, Never>?

    /// Data directory for persistence
    var dataDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PocketBaseAdmin/pb_data", isDirectory: true)
    }

    /// Directory where PocketBase binary is stored
    private var binDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PocketBaseAdmin/bin", isDirectory: true)
    }

    /// Path to the PocketBase executable
    private var executablePath: URL {
        binDirectory.appendingPathComponent("pocketbase")
    }

    /// PocketBase version to download
    private let pocketbaseVersion = "0.25.9"

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
        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)
    }

    /// Check if PocketBase is installed
    private var isPocketBaseInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: executablePath.path)
    }

    /// Download PocketBase if not installed
    private func ensurePocketBaseInstalled() async throws {
        if isPocketBaseInstalled {
            appendLog("PocketBase binary found")
            return
        }

        state = .downloading
        appendLog("Downloading PocketBase v\(pocketbaseVersion)...")

        // Determine architecture
        let arch = ProcessInfo.processInfo.machineArchitecture
        let archSuffix = arch == "arm64" ? "darwin_arm64" : "darwin_amd64"

        let downloadURL = URL(string: "https://github.com/pocketbase/pocketbase/releases/download/v\(pocketbaseVersion)/pocketbase_\(pocketbaseVersion)_\(archSuffix).zip")!

        // Download the zip file
        let (zipData, response) = try await URLSession.shared.data(from: downloadURL)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServerError.downloadFailed("Failed to download PocketBase")
        }

        appendLog("Downloaded \(ByteCountFormatter.string(fromByteCount: Int64(zipData.count), countStyle: .file))")

        // Save zip to temp file
        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("pocketbase.zip")
        try zipData.write(to: tempZipURL)

        // Unzip using ditto (macOS built-in)
        appendLog("Extracting PocketBase...")

        let unzipResult = try await Subprocess.run(
            .path("/usr/bin/ditto"),
            arguments: ["-xk", tempZipURL.path, binDirectory.path]
        )

        guard unzipResult.terminationStatus.isSuccess else {
            throw ServerError.extractionFailed("Failed to extract PocketBase")
        }

        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executablePath.path
        )

        // Cleanup
        try? FileManager.default.removeItem(at: tempZipURL)

        appendLog("PocketBase v\(pocketbaseVersion) installed successfully")
    }

    /// Start the PocketBase server
    func start() async {
        guard state.canStart else {
            appendLog("Cannot start server in current state", isError: true)
            return
        }

        state = .starting
        appendLog("Initializing PocketBase server...")

        do {
            // Ensure PocketBase is installed
            try await ensurePocketBaseInstalled()

            state = .starting
            appendLog("Starting PocketBase on port \(port)...")

            // Start the server in a background task
            serverTask = Task.detached { [weak self] in
                await self?.runServer()
            }

        } catch {
            state = .error(error.localizedDescription)
            appendLog("Failed to start server: \(error.localizedDescription)", isError: true)
        }
    }

    /// Run the server process and stream output
    private func runServer() async {
        do {
            try await Subprocess.run(
                .path(executablePath.path),
                arguments: [
                    "serve",
                    "--dir", dataDirectory.path,
                    "--http", "127.0.0.1:\(port)"
                ],
                output: .redirectToSequence,
                error: .redirectToSequence
            ) { execution, standardOutput, standardError in

                // Update state when process starts
                await MainActor.run { [weak self] in
                    self?.state = .running
                    self?.appendLog("Server is running at http://127.0.0.1:\(self?.port ?? 8090)")
                    self?.appendLog("Admin UI: http://127.0.0.1:\(self?.port ?? 8090)/_/")
                }

                // Stream stdout
                async let stdoutTask: Void = {
                    for try await line in standardOutput.lines {
                        await MainActor.run { [weak self] in
                            self?.appendLog(line)
                        }
                    }
                }()

                // Stream stderr
                async let stderrTask: Void = {
                    for try await line in standardError.lines {
                        await MainActor.run { [weak self] in
                            self?.appendLog(line, isError: true)
                        }
                    }
                }()

                // Wait for both to complete
                _ = try await (stdoutTask, stderrTask)
            }

            // Process ended normally
            await MainActor.run { [weak self] in
                self?.state = .stopped
                self?.appendLog("Server stopped")
            }

        } catch is CancellationError {
            await MainActor.run { [weak self] in
                self?.state = .stopped
                self?.appendLog("Server stopped")
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.state = .error(error.localizedDescription)
                self?.appendLog("Server error: \(error.localizedDescription)", isError: true)
            }
        }
    }

    /// Stop the PocketBase server
    func stop() async {
        guard state.canStop else {
            appendLog("Cannot stop server in current state", isError: true)
            return
        }

        state = .stopping
        appendLog("Stopping PocketBase server...")

        // Cancel the server task
        serverTask?.cancel()
        serverTask = nil

        // Give it a moment to stop gracefully
        try? await Task.sleep(for: .milliseconds(500))

        if state == .stopping {
            state = .stopped
        }
    }

    /// Clear all logs
    func clearLogs() {
        logs.removeAll()
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

    enum ServerError: LocalizedError {
        case downloadFailed(String)
        case extractionFailed(String)
        case startFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let msg): return msg
            case .extractionFailed(let msg): return msg
            case .startFailed(let msg): return msg
            }
        }
    }
}

// MARK: - ProcessInfo Extension

extension ProcessInfo {
    var machineArchitecture: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }
}

// MARK: - Environment Key

@available(macOS 15.0, *)
private struct PocketBaseServerManagerKey: EnvironmentKey {
    static let defaultValue: PocketBaseServerManager? = nil
}

@available(macOS 15.0, *)
extension EnvironmentValues {
    var serverManager: PocketBaseServerManager? {
        get { self[PocketBaseServerManagerKey.self] }
        set { self[PocketBaseServerManagerKey.self] = newValue }
    }
}
#endif
