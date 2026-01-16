//
//  ServerCommands.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import SwiftUI

/// Menu bar commands for controlling the local PocketBase server
@available(macOS 15.0, *)
struct ServerCommands: Commands {
    @FocusedValue(\.serverManager) var serverManager

    var body: some Commands {
        // Product menu (like Xcode)
        CommandMenu("Server") {
            Button("Start Server") {
                Task {
                    await serverManager?.start()
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!(serverManager?.state.canStart ?? true))

            Button("Stop Server") {
                Task {
                    await serverManager?.stop()
                }
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(!(serverManager?.state.canStop ?? false))

            Divider()

            Button("Clear Console") {
                serverManager?.clearLogs()
            }
            .keyboardShortcut("k", modifiers: [.command])
        }

        // View menu additions for console toggle
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Toggle Console") {
                NotificationCenter.default.post(name: .toggleConsole, object: nil)
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Focused Value for Server Manager

@available(macOS 15.0, *)
struct ServerManagerKey: FocusedValueKey {
    typealias Value = PocketBaseServerManager
}

@available(macOS 15.0, *)
extension FocusedValues {
    var serverManager: PocketBaseServerManager? {
        get { self[ServerManagerKey.self] }
        set { self[ServerManagerKey.self] = newValue }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toggleConsole = Notification.Name("PocketBaseAdmin.toggleConsole")
    static let startServer = Notification.Name("PocketBaseAdmin.startServer")
    static let stopServer = Notification.Name("PocketBaseAdmin.stopServer")
}
#endif
