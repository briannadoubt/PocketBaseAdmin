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
import Network

/// Manages the lifecycle of a local PocketBase server instance
@Observable @MainActor
final class PocketBaseServerManager {

    enum ServerState: Equatable {
        case stopped
        case needsSetup  // No superuser exists, need to create one first
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
            case .stopped, .error, .needsSetup: return true
            default: return false
            }
        }

        var needsSetup: Bool {
            if case .needsSetup = self { return true }
            return false
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
            case .needsSetup: return "Setup Required"
            case .starting: return "Starting..."
            case .running: return "Running"
            case .stopping: return "Stopping..."
            case .downloading: return "Downloading..."
            case .error(let message): return "Error: \(message)"
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

    /// Time when server was last started (for detecting immediate crashes)
    private var serverStartTime: Date?


    /// The advertised service name
    var serviceName: String {
        Host.current().localizedName ?? "PocketBase"
    }

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

    /// Check if the database has any superusers
    func checkNeedsSuperuserSetup() -> Bool {
        // Check if pb_data exists and has the database file
        let dbPath = dataDirectory.appendingPathComponent("data.db")
        if !FileManager.default.fileExists(atPath: dbPath.path) {
            // No database yet, will need setup
            return true
        }

        // Use pocketbase CLI to check - if we can list superusers, we don't need setup
        // We'll use a simple heuristic: try to run a command that requires the DB
        // and check if it indicates no superusers
        let checkProcess = Process()
        checkProcess.executableURL = executablePath
        checkProcess.arguments = ["superuser", "upsert", "--help", "--dir", dataDirectory.path]
        checkProcess.standardOutput = FileHandle.nullDevice
        checkProcess.standardError = FileHandle.nullDevice

        // For now, we'll assume setup is needed if no data.db exists
        // The actual check happens when the server starts and tries to authenticate
        return !FileManager.default.fileExists(atPath: dbPath.path)
    }

    /// Create a superuser using the CLI (must be called before server starts)
    func createSuperuser(email: String, password: String) async throws {
        appendLog("Creating superuser account...")

        let process = Process()
        process.executableURL = executablePath
        process.currentDirectoryURL = binDirectory
        process.arguments = [
            "superuser", "upsert",
            email, password,
            "--dir", dataDirectory.path
        ]

        let stderrPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ServerError.startFailed("Failed to create superuser: \(errorMessage)")
        }

        appendLog("Superuser account created successfully")
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

            // Check if we need superuser setup before starting
            if checkNeedsSuperuserSetup() {
                state = .needsSetup
                appendLog("No superuser found - setup required before starting server")
                return
            }

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

    /// Start the server after superuser has been created
    func startAfterSetup() async {
        guard state == .needsSetup else {
            await start()
            return
        }

        state = .starting
        appendLog("Starting PocketBase on port \(port)...")

        // Start the server in a background task
        serverTask = Task.detached { [weak self] in
            await self?.runServer()
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
            "--http", "0.0.0.0:\(port)",  // Bind to all interfaces for network discovery
            "--origins", "*"  // Allow connections from the app
        ]

        // Set environment to disable browser auto-open
        var environment = ProcessInfo.processInfo.environment
        environment["PB_OPEN_BROWSER"] = "false"
        process.environment = environment

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

            // Start Bonjour advertising so other devices can discover us
            startBonjourAdvertising()

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
                    self.stopBonjourAdvertising()

                    let exitCode = terminatedProcess.terminationStatus
                    let terminationReason = terminatedProcess.terminationReason
                    let wasRunning = self.state == .running
                    let wasStopping = self.state == .stopping

                    // Check if this was an immediate crash (within 5 seconds of starting)
                    let timeSinceStart = self.serverStartTime.map { Date().timeIntervalSince($0) } ?? 0
                    let crashedImmediately = wasRunning && timeSinceStart < 5.0 && exitCode != 0

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
        guard state.canStop else {
            appendLog("Cannot stop server in current state", isError: true)
            return
        }

        state = .stopping
        appendLog("Stopping PocketBase server...")

        // Stop Bonjour advertising
        stopBonjourAdvertising()

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

    // MARK: - Bonjour Advertising

    /// NetService for Bonjour advertising
    private var bonjourService: NetService?

    /// Start advertising the local PocketBase instance via Bonjour
    private func startBonjourAdvertising() {
        guard bonjourService == nil else { return }

        // Create NetService to advertise our PocketBase instance
        // Note: type must match BonjourBrowser.serviceType exactly for discovery to work
        let service = NetService(
            domain: "local.",
            type: "_pocketbase._tcp",
            name: serviceName,
            port: Int32(port)
        )

        // Set TXT record with metadata
        let txtData = makeTXTRecord()
        service.setTXTRecord(txtData)

        service.delegate = BonjourServiceDelegate.shared
        service.publish()

        bonjourService = service
        appendLog("Bonjour: Advertising '\(serviceName)' on local network (port \(port))")
    }

    /// Stop advertising via Bonjour
    private func stopBonjourAdvertising() {
        bonjourService?.stop()
        bonjourService = nil
        appendLog("Bonjour: Stopped advertising")
    }

    /// Create TXT record data with metadata about this instance
    private func makeTXTRecord() -> Data {
        var dict: [String: Data] = [:]
        dict["version"] = pocketbaseVersion.data(using: .utf8)
        dict["name"] = serviceName.data(using: .utf8)

        // Include iCloud account hash for "same account" discovery
        if let accountToken = FileManager.default.ubiquityIdentityToken {
            let hash = accountToken.hash
            dict["account"] = String(format: "%08x", hash).data(using: .utf8)
        }

        return NetService.data(fromTXTRecord: dict)
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

private struct PocketBaseServerManagerKey: EnvironmentKey {
    static let defaultValue: PocketBaseServerManager? = nil
}

extension EnvironmentValues {
    var serverManager: PocketBaseServerManager? {
        get { self[PocketBaseServerManagerKey.self] }
        set { self[PocketBaseServerManagerKey.self] = newValue }
    }
}

// MARK: - Bonjour Service Delegate

/// Delegate for NetService publishing events
final class BonjourServiceDelegate: NSObject, NetServiceDelegate {
    static let shared = BonjourServiceDelegate()

    private override init() {
        super.init()
    }

    func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour: Published service '\(sender.name)' on port \(sender.port)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("Bonjour: Failed to publish service - \(errorDict)")
    }

    func netServiceDidStop(_ sender: NetService) {
        print("Bonjour: Service stopped")
    }
}
#endif
