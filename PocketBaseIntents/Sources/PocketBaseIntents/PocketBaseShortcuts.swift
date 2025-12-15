//
//  PocketBaseShortcuts.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents

/// Provides Siri Shortcuts for PocketBase Admin
public struct PocketBaseShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckServerStatusIntent(),
            phrases: [
                "Check \(.applicationName) status",
                "Is \(.applicationName) online",
                "Check my \(.applicationName) server"
            ],
            shortTitle: "Server Status",
            systemImageName: "server.rack"
        )

        AppShortcut(
            intent: CreateBackupIntent(),
            phrases: [
                "Create \(.applicationName) backup",
                "Backup my \(.applicationName) database",
                "Make a \(.applicationName) backup"
            ],
            shortTitle: "Create Backup",
            systemImageName: "archivebox"
        )

        AppShortcut(
            intent: ListBackupsIntent(),
            phrases: [
                "List \(.applicationName) backups",
                "Show my \(.applicationName) backups",
                "What \(.applicationName) backups do I have"
            ],
            shortTitle: "List Backups",
            systemImageName: "archivebox.fill"
        )

        AppShortcut(
            intent: GetRecentLogsIntent(),
            phrases: [
                "Show \(.applicationName) logs",
                "Check \(.applicationName) for errors",
                "Get \(.applicationName) logs"
            ],
            shortTitle: "View Logs",
            systemImageName: "doc.text"
        )

        AppShortcut(
            intent: GetErrorCountIntent(),
            phrases: [
                "How many \(.applicationName) errors",
                "Check \(.applicationName) error count",
                "Any \(.applicationName) errors today"
            ],
            shortTitle: "Error Count",
            systemImageName: "exclamationmark.circle"
        )

        AppShortcut(
            intent: GetCollectionsIntent(),
            phrases: [
                "List \(.applicationName) collections",
                "Show my \(.applicationName) collections",
                "What \(.applicationName) collections do I have"
            ],
            shortTitle: "Collections",
            systemImageName: "rectangle.stack"
        )

        AppShortcut(
            intent: GetServerStatsIntent(),
            phrases: [
                "Get \(.applicationName) stats",
                "\(.applicationName) statistics",
                "\(.applicationName) server overview"
            ],
            shortTitle: "Server Stats",
            systemImageName: "chart.bar"
        )
    }
}
