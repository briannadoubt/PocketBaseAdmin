//
//  BackupActions.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Actions that can be performed on backups
enum BackupAction: Identifiable {
    case download(BackupModel)
    case restore(BackupModel)
    case delete(BackupModel)
    case copyName(BackupModel)
    case copySize(BackupModel)

    var id: String {
        switch self {
        case .download(let b): return "download-\(b.id)"
        case .restore(let b): return "restore-\(b.id)"
        case .delete(let b): return "delete-\(b.id)"
        case .copyName(let b): return "copyName-\(b.id)"
        case .copySize(let b): return "copySize-\(b.id)"
        }
    }
}

/// Reusable menu content for backup context menus
struct BackupMenuContent: View {
    let backup: BackupModel
    let onDownload: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onDownload()
        } label: {
            Label("Download", systemImage: "arrow.down.circle")
        }

        Button {
            onRestore()
        } label: {
            Label("Restore", systemImage: "arrow.counterclockwise.circle")
        }

        Divider()

        Button {
            Clipboard.copy(backup.key)
        } label: {
            Label("Copy Name", systemImage: "doc.on.doc")
        }

        Button {
            Clipboard.copy(backup.formattedSize)
        } label: {
            Label("Copy Size", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
