//
//  PocketBaseServerManager.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import Foundation
import SwiftUI
import Darwin

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

        var displayName: String {
            switch self {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case .running: return "Running"
            case .stopping: return "Stopping..."
            case .downloading: return "Downloading..."
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    /// Current state of the server
    private(set) var state: ServerState = .stopped {
        didSet {
            print("[ServerManager] State changed: \(oldValue.displayName) -> \(state.displayName)")
        }
    }

    /// Console output logs
    private(set) var logs: [LogEntry] = []

    /// The port PocketBase runs on
    let port: Int = 8090

    /// Task running the server process
    private var serverTask: Task<Void, Never>?

    /// Time when server was last started (for detecting immediate crashes)
    private var serverStartTime: Date?

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

    /// Path to version file tracking installed version
    private var versionFilePath: URL {
        binDirectory.appendingPathComponent(".version")
    }

    /// Check if PocketBase is installed with correct version
    private var isPocketBaseInstalled: Bool {
        // Check if binary exists
        guard FileManager.default.fileExists(atPath: executablePath.path) else {
            return false
        }
        // Check if version matches
        guard let installedVersion = try? String(contentsOf: versionFilePath, encoding: .utf8),
              installedVersion.trimmingCharacters(in: .whitespacesAndNewlines) == pocketbaseVersion else {
            return false
        }
        return true
    }

    /// Save the installed version to a file
    private func saveInstalledVersion() {
        try? pocketbaseVersion.write(to: versionFilePath, atomically: true, encoding: .utf8)
    }

    /// Download PocketBase if not installed or outdated
    private func ensurePocketBaseInstalled() async throws {
        if isPocketBaseInstalled {
            appendLog("PocketBase v\(pocketbaseVersion) already installed")
            return
        }

        // Check if we just need to update vs fresh install
        let isUpdate = FileManager.default.fileExists(atPath: executablePath.path)

        state = .downloading
        appendLog(isUpdate ? "Updating to PocketBase v\(pocketbaseVersion)..." : "Downloading PocketBase v\(pocketbaseVersion)...")

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

        let dittoProcess = Process()
        dittoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        dittoProcess.arguments = ["-xk", tempZipURL.path, binDirectory.path]

        try dittoProcess.run()
        dittoProcess.waitUntilExit()

        guard dittoProcess.terminationStatus == 0 else {
            throw ServerError.extractionFailed("Failed to extract PocketBase")
        }

        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executablePath.path
        )

        // Remove quarantine attribute (macOS Gatekeeper)
        appendLog("Removing quarantine attribute...")
        let quarantineResult = unsafe removexattr(
            executablePath.path,
            "com.apple.quarantine",
            0
        )
        if quarantineResult == 0 {
            appendLog("Quarantine attribute removed")
        } else {
            appendLog("Note: Could not remove quarantine (errno: \(errno)) - may need manual approval")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempZipURL)

        // Save installed version
        saveInstalledVersion()

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

    /// The running process
    private var process: Process?

    /// Pipes for process I/O (must be retained while process runs)
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    /// Check if the port is already in use
    private func isPortInUse() -> Bool {
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        checkProcess.arguments = ["-i", ":\(port)", "-sTCP:LISTEN"]

        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        checkProcess.standardError = FileHandle.nullDevice

        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return !data.isEmpty
        } catch {
            return false
        }
    }

    /// Kill any existing process on our port
    private func killExistingProcess() {
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killProcess.arguments = ["-f", "pocketbase.*:\(port)"]
        killProcess.standardOutput = FileHandle.nullDevice
        killProcess.standardError = FileHandle.nullDevice

        try? killProcess.run()
        killProcess.waitUntilExit()

        // Give it a moment to release the port
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Run the server process and stream output using Foundation's Process
    private func runServer() async {
        // Check if port is already in use and kill existing process
        if isPortInUse() {
            appendLog("Port \(port) is already in use, killing existing process...")
            killExistingProcess()

            // Check again
            if isPortInUse() {
                state = .error("Port \(port) is still in use after attempting to kill existing process")
                appendLog("Failed to free port \(port)", isError: true)
                return
            }
            appendLog("Port \(port) is now free")
        }

        // Log paths for debugging
        appendLog("Executable: \(executablePath.path)")
        appendLog("Data dir: \(dataDirectory.path)")
        appendLog("Exists: \(FileManager.default.fileExists(atPath: executablePath.path))")

        let process = Process()
        let execURL = URL(fileURLWithPath: executablePath.path)
        process.executableURL = execURL
        process.currentDirectoryURL = binDirectory
        process.arguments = [
            "serve",
            "--dir", dataDirectory.path,
            "--http", "127.0.0.1:\(port)"
        ]

        appendLog("Using executable URL: \(execURL.path)")
        appendLog("File exists at URL: \(FileManager.default.fileExists(atPath: execURL.path))")

        // Set up pipes for stdout and stderr (stored as instance vars to prevent deallocation)
        let stdout = Pipe()
        let stderr = Pipe()
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        process.standardOutput = stdout
        process.standardError = stderr

        // Set stdin to null device to prevent EOF-related exits
        process.standardInput = FileHandle.nullDevice

        // Store process reference for stopping
        self.process = process

        do {
            try process.run()

            // Track start time for crash detection
            serverStartTime = Date()

            // Update state
            state = .running
            appendLog("Server is running at http://127.0.0.1:\(port)")
            appendLog("Admin UI: http://127.0.0.1:\(port)/_/")

            // Stream output in background tasks
            let stdoutHandle = stdout.fileHandleForReading
            let stderrHandle = stderr.fileHandleForReading

            // Read stdout in background
            Task { @MainActor [weak self] in
                do {
                    for try await line in stdoutHandle.bytes.lines {
                        self?.appendLog(line)
                    }
                } catch {
                    // Stream closed
                }
            }

            // Read stderr in background
            Task { @MainActor [weak self] in
                do {
                    for try await line in stderrHandle.bytes.lines {
                        self?.appendLog(line, isError: true)
                    }
                } catch {
                    // Stream closed
                }
            }

            // Handle process termination asynchronously
            process.terminationHandler = { [weak self] terminatedProcess in
                Task { @MainActor in
                    guard let self else { return }
                    self.process = nil
                    self.stdoutPipe = nil
                    self.stderrPipe = nil

                    let exitCode = terminatedProcess.terminationStatus
                    let terminationReason = terminatedProcess.terminationReason
                    let wasRunning = self.state == .running
                    let wasStopping = self.state == .stopping

                    // Check if this was an immediate crash (within 5 seconds of starting)
                    let timeSinceStart = self.serverStartTime.map { Date().timeIntervalSince($0) } ?? 0
                    let crashedImmediately = wasRunning && timeSinceStart < 5.0 && exitCode != 0

                    print("[ServerManager] Process terminated - exitCode: \(exitCode), reason: \(terminationReason.rawValue), timeSinceStart: \(timeSinceStart)s, wasRunning: \(wasRunning), wasStopping: \(wasStopping)")

                    if crashedImmediately {
                        self.state = .error("Server crashed immediately (exit code: \(exitCode)). Check console for details.")
                        self.appendLog("Server crashed immediately after starting (exit code: \(exitCode))", isError: true)
                    } else if wasRunning || wasStopping {
                        self.state = .stopped
                        self.appendLog("Server stopped (exit code: \(exitCode), reason: \(terminationReason == .exit ? "normal" : "signal"))")
                    }

                    self.serverStartTime = nil
                }
            }

        } catch {
            self.process = nil
            state = .error(error.localizedDescription)
            appendLog("Failed to start server: \(error.localizedDescription)", isError: true)
            appendLog("Error type: \(type(of: error))", isError: true)
        }
    }

    /// Stop the PocketBase server
    func stop() async {
        print("[ServerManager] stop() called - current state: \(state.displayName)")

        guard state.canStop else {
            appendLog("Cannot stop server in current state", isError: true)
            return
        }

        state = .stopping
        appendLog("Stopping PocketBase server...")

        // Clear start time to prevent false crash detection
        serverStartTime = nil

        // Terminate the process
        if let process = process, process.isRunning {
            process.terminate()
        }

        // Cancel the server task
        serverTask?.cancel()
        serverTask = nil

        // Give it a moment to stop gracefully
        try? await Task.sleep(for: .milliseconds(500))

        if state == .stopping {
            state = .stopped
            process = nil
            stdoutPipe = nil
            stderrPipe = nil
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
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
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
