//
//  PocketBaseServerService.swift
//  PocketBaseServerHelper
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation

/// XPC service implementation for managing PocketBase server processes
class PocketBaseServerService: NSObject, PocketBaseServerProtocol {
    /// Currently running server process
    private var serverProcess: Process?

    /// Log streaming handler
    private var logHandler: ((String, Bool) -> Void)?

    /// Output pipe for server stdout
    private var stdoutPipe: Pipe?

    /// Output pipe for server stderr
    private var stderrPipe: Pipe?

    /// PocketBase binary path
    private var binaryPath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PocketBaseAdmin/bin/pocketbase")
    }

    /// Version file path
    private var versionFilePath: URL {
        binaryPath.deletingLastPathComponent().appendingPathComponent(".version")
    }

    // MARK: - PocketBaseServerProtocol

    func startServer(dataDirectory: String, port: Int, reply: @escaping (Bool, String?) -> Void) {
        // Check if already running
        guard serverProcess == nil || !serverProcess!.isRunning else {
            reply(false, PocketBaseServerError.alreadyRunning.localizedDescription)
            return
        }

        // Verify binary exists
        guard FileManager.default.fileExists(atPath: binaryPath.path) else {
            reply(false, "PocketBase binary not found. Please install first.")
            return
        }

        // Create the server process
        let process = Process()
        process.executableURL = binaryPath
        process.currentDirectoryURL = binaryPath.deletingLastPathComponent()
        process.arguments = [
            "serve",
            "--dir", dataDirectory,
            "--http", "127.0.0.1:\(port)"
        ]

        // Set up pipes for output
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        // Set up output handlers
        setupOutputHandlers()

        // Handle termination
        process.terminationHandler = { [weak self] process in
            self?.handleTermination(exitCode: process.terminationStatus)
        }

        do {
            try process.run()
            self.serverProcess = process
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func stopServer(reply: @escaping (Bool) -> Void) {
        guard let process = serverProcess, process.isRunning else {
            reply(true) // Already stopped
            return
        }

        process.terminate()

        // Give it time to stop gracefully
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.serverProcess?.isRunning == true {
                self?.serverProcess?.interrupt()
            }
            self?.serverProcess = nil
            self?.stdoutPipe = nil
            self?.stderrPipe = nil
            reply(true)
        }
    }

    func getServerStatus(reply: @escaping (Bool, Int) -> Void) {
        if let process = serverProcess, process.isRunning {
            reply(true, Int(process.processIdentifier))
        } else {
            reply(false, 0)
        }
    }

    func streamLogs(handler: @escaping (String, Bool) -> Void) {
        self.logHandler = handler
    }

    func installPocketBase(version: String, reply: @escaping (Bool, String?) -> Void) {
        // Determine architecture
        #if arch(arm64)
        let archSuffix = "darwin_arm64"
        #else
        let archSuffix = "darwin_amd64"
        #endif

        let downloadURL = URL(string: "https://github.com/pocketbase/pocketbase/releases/download/v\(version)/pocketbase_\(version)_\(archSuffix).zip")!

        // Create bin directory
        let binDir = binaryPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)

        // Download in background
        URLSession.shared.downloadTask(with: downloadURL) { [weak self] tempURL, response, error in
            guard let self = self else { return }

            if let error = error {
                reply(false, "Download failed: \(error.localizedDescription)")
                return
            }

            guard let tempURL = tempURL else {
                reply(false, "Download failed: No file received")
                return
            }

            do {
                // Extract using ditto
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-xk", tempURL.path, binDir.path]

                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    reply(false, "Extraction failed")
                    return
                }

                // Make executable
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: self.binaryPath.path
                )

                // Remove quarantine
                let xattrProcess = Process()
                xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattrProcess.arguments = ["-d", "com.apple.quarantine", self.binaryPath.path]
                try? xattrProcess.run()
                xattrProcess.waitUntilExit()

                // Save version
                try version.write(to: self.versionFilePath, atomically: true, encoding: .utf8)

                reply(true, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }.resume()
    }

    func checkInstallation(reply: @escaping (Bool, String?) -> Void) {
        guard FileManager.default.fileExists(atPath: binaryPath.path) else {
            reply(false, nil)
            return
        }

        let version = try? String(contentsOf: versionFilePath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        reply(true, version)
    }

    // MARK: - Private Methods

    private func setupOutputHandlers() {
        // Handle stdout
        stdoutPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8), !string.isEmpty {
                self?.logHandler?(string, false)
            }
        }

        // Handle stderr
        stderrPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8), !string.isEmpty {
                self?.logHandler?(string, true)
            }
        }
    }

    private func handleTermination(exitCode: Int32) {
        logHandler?("Server terminated with exit code \(exitCode)", exitCode != 0)
        serverProcess = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
}
