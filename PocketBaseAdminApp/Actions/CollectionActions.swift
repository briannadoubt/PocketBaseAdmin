//
//  CollectionActions.swift
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

/// Actions that can be performed on collections
enum CollectionAction: Identifiable {
    case edit(CollectionModel)
    case duplicate(CollectionModel)
    case delete(CollectionModel)
    case copyID(CollectionModel)
    case copyName(CollectionModel)
    case copyAPIEndpoint(CollectionModel)
    case exportSchema(CollectionModel)
    case openInBrowser(CollectionModel)

    var id: String {
        switch self {
        case .edit(let c): return "edit-\(c.id)"
        case .duplicate(let c): return "duplicate-\(c.id)"
        case .delete(let c): return "delete-\(c.id)"
        case .copyID(let c): return "copyID-\(c.id)"
        case .copyName(let c): return "copyName-\(c.id)"
        case .copyAPIEndpoint(let c): return "copyAPIEndpoint-\(c.id)"
        case .exportSchema(let c): return "exportSchema-\(c.id)"
        case .openInBrowser(let c): return "openInBrowser-\(c.id)"
        }
    }
}

/// Executor for collection actions
@MainActor
final class CollectionActionExecutor {
    let pocketbase: PocketBase
    let collectionsState: CollectionsState

    init(pocketbase: PocketBase, collectionsState: CollectionsState) {
        self.pocketbase = pocketbase
        self.collectionsState = collectionsState
    }

    func execute(_ action: CollectionAction) async {
        switch action {
        case .copyID(let collection):
            Clipboard.copy(collection.id)

        case .copyName(let collection):
            Clipboard.copy(collection.name)

        case .copyAPIEndpoint(let collection):
            let endpoint = "/api/collections/\(collection.name)/records"
            Clipboard.copy(endpoint)

        case .exportSchema(let collection):
            Clipboard.copyJSON(collection)

        case .openInBrowser(let collection):
            let adminURL = pocketbase.url.appendingPathComponent("/_/#/collections")
                .appendingPathComponent(collection.id)
            openURL(adminURL)

        case .delete(let collection):
            do {
                try await collectionsState.delete(id: collection.id, using: pocketbase)
            } catch {
                // Error handling could be improved with a callback
                print("Failed to delete collection: \(error)")
            }

        case .edit, .duplicate:
            // These actions require UI presentation and are handled by the view
            break
        }
    }

    private func openURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS) || os(visionOS)
        UIApplication.shared.open(url)
        #endif
    }
}

/// Reusable menu content for collection context menus and menu bar
struct CollectionMenuContent: View {
    let collection: CollectionModel
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @Environment(\.pocketbase) private var pocketbase

    var body: some View {
        Button {
            onEdit()
        } label: {
            Label("Edit Collection", systemImage: "pencil")
        }
        .keyboardShortcut("e", modifiers: .command)

        Button {
            onDuplicate()
        } label: {
            Label("Duplicate Collection", systemImage: "plus.square.on.square")
        }
        .keyboardShortcut("d", modifiers: .command)

        Divider()

        Button {
            Clipboard.copy(collection.id)
        } label: {
            Label("Copy ID", systemImage: "doc.on.doc")
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])

        Button {
            Clipboard.copy(collection.name)
        } label: {
            Label("Copy Name", systemImage: "textformat")
        }

        Button {
            let endpoint = "/api/collections/\(collection.name)/records"
            Clipboard.copy(endpoint)
        } label: {
            Label("Copy API Endpoint", systemImage: "link")
        }

        Button {
            Clipboard.copyJSON(collection)
        } label: {
            Label("Export Schema as JSON", systemImage: "curlybraces")
        }
        .keyboardShortcut("c", modifiers: [.command, .option])

        #if os(macOS) || os(iOS)
        Button {
            let adminURL = pocketbase.url.appendingPathComponent("/_/#/collections")
                .appendingPathComponent(collection.id)
            #if os(macOS)
            NSWorkspace.shared.open(adminURL)
            #elseif os(iOS)
            UIApplication.shared.open(adminURL)
            #endif
        } label: {
            Label("Open in Browser", systemImage: "safari")
        }
        #endif

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete Collection", systemImage: "trash")
        }
        .keyboardShortcut(.delete, modifiers: .command)
        .disabled(collection.system)
    }
}
