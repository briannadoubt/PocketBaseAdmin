//
//  PocketBaseIntents.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import Foundation

/// PocketBaseIntents module provides App Intents for PocketBase Admin
///
/// This module includes:
/// - **Entities**: ServerStatusEntity, BackupEntity, CollectionEntity, LogEntryEntity
/// - **Intents**: Check status, create/list/restore backups, get collections, view logs
/// - **Snippet Views**: Custom SwiftUI views for Siri/Shortcuts results
/// - **Shortcuts Provider**: Pre-configured Siri phrases
///
/// ## Usage
///
/// ```swift
/// import PocketBaseIntents
///
/// // Check server status
/// let intent = CheckServerStatusIntent()
/// let result = try await intent.perform()
///
/// // Create a backup
/// let backup = CreateBackupIntent()
/// backup.name = "my-backup"
/// try await backup.perform()
/// ```
///
/// ## Configuration
///
/// Before using intents, configure the server URL:
///
/// ```swift
/// await ServerConfiguration.shared.setServerURL(myURL)
/// await ServerConfiguration.shared.setAuthToken(myToken)
/// ```
public enum PocketBaseIntentsModule {
    /// The version of the PocketBaseIntents module
    public static let version = "1.0.0"
}
