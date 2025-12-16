//
//  AppCommands.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Menu bar commands for PocketBase Admin
struct AppCommands: Commands {
    @FocusedValue(\.selectedCollection) var selectedCollection
    @FocusedValue(\.selectedRecord) var selectedRecord
    @FocusedValue(\.collectionsState) var collectionsState
    @FocusedValue(\.pocketbase) var pocketbase

    var body: some Commands {
        // File menu additions
        CommandGroup(after: .newItem) {
            Divider()

            Button("New Collection") {
                NotificationCenter.default.post(name: .newCollection, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Record") {
                NotificationCenter.default.post(name: .newRecord, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(selectedCollection == nil)
        }

        // Edit menu additions for Copy actions
        CommandGroup(after: .pasteboard) {
            Divider()

            if let collection = selectedCollection {
                Button("Copy Collection ID") {
                    Clipboard.copy(collection.id)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Copy API Endpoint") {
                    let endpoint = "/api/collections/\(collection.name)/records"
                    Clipboard.copy(endpoint)
                }
            }

            if let record = selectedRecord {
                Button("Copy Record ID") {
                    Clipboard.copy(record.id)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Copy Record as JSON") {
                    copyRecordAsJSON(record)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
            }
        }

        // View menu for refresh
        CommandGroup(after: .toolbar) {
            Button("Refresh") {
                NotificationCenter.default.post(name: .refresh, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
    }

    private func copyRecordAsJSON(_ record: RecordModel) {
        var dict: [String: Any] = [
            "id": record.id,
            "collectionId": record.collectionId,
            "collectionName": record.collectionName
        ]

        if let created = record.created {
            dict["created"] = ISO8601DateFormatter().string(from: created)
        }
        if let updated = record.updated {
            dict["updated"] = ISO8601DateFormatter().string(from: updated)
        }

        for (key, value) in record.content {
            dict[key] = jsonValue(from: value)
        }

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            Clipboard.copy(string)
        }
    }

    private func jsonValue(from value: JSONValue) -> Any? {
        switch value {
        case .string(let str): return str
        case .int(let num): return num
        case .double(let num): return num
        case .decimal(let num): return NSDecimalNumber(decimal: num)
        case .bool(let bool): return bool
        case .date(let date): return ISO8601DateFormatter().string(from: date)
        case .url(let url): return url.absoluteString
        case .array(let arr): return arr.compactMap { jsonValue(from: $0) }
        case .dictionary(let dict): return dict.mapValues { jsonValue(from: $0) }
        case .null: return NSNull()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newCollection = Notification.Name("PocketBaseAdmin.newCollection")
    static let newRecord = Notification.Name("PocketBaseAdmin.newRecord")
    static let refresh = Notification.Name("PocketBaseAdmin.refresh")
}

// MARK: - Focused Values

struct SelectedCollectionKey: FocusedValueKey {
    typealias Value = CollectionModel
}

struct SelectedRecordKey: FocusedValueKey {
    typealias Value = RecordModel
}

struct CollectionsStateKey: FocusedValueKey {
    typealias Value = CollectionsState
}

struct PocketBaseFocusedKey: FocusedValueKey {
    typealias Value = PocketBase
}

extension FocusedValues {
    var selectedCollection: CollectionModel? {
        get { self[SelectedCollectionKey.self] }
        set { self[SelectedCollectionKey.self] = newValue }
    }

    var selectedRecord: RecordModel? {
        get { self[SelectedRecordKey.self] }
        set { self[SelectedRecordKey.self] = newValue }
    }

    var collectionsState: CollectionsState? {
        get { self[CollectionsStateKey.self] }
        set { self[CollectionsStateKey.self] = newValue }
    }

    var pocketbase: PocketBase? {
        get { self[PocketBaseFocusedKey.self] }
        set { self[PocketBaseFocusedKey.self] = newValue }
    }
}
