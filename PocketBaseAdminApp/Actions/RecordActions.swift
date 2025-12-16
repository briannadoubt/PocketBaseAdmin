//
//  RecordActions.swift
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

/// Actions that can be performed on records
enum RecordAction: Identifiable {
    case edit(RecordModel)
    case duplicate(RecordModel)
    case delete(RecordModel)
    case copyID(RecordModel)
    case copyAsJSON(RecordModel)
    case copyFieldValue(RecordModel, fieldName: String)
    case shareURL(RecordModel, collectionName: String)

    var id: String {
        switch self {
        case .edit(let r): return "edit-\(r.id)"
        case .duplicate(let r): return "duplicate-\(r.id)"
        case .delete(let r): return "delete-\(r.id)"
        case .copyID(let r): return "copyID-\(r.id)"
        case .copyAsJSON(let r): return "copyAsJSON-\(r.id)"
        case .copyFieldValue(let r, let field): return "copyFieldValue-\(r.id)-\(field)"
        case .shareURL(let r, _): return "shareURL-\(r.id)"
        }
    }
}

/// Reusable menu content for record context menus and menu bar
struct RecordMenuContent: View {
    let record: RecordModel
    let schema: [Field]
    let collectionName: String
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @Environment(\.pocketbase) private var pocketbase

    var body: some View {
        Button {
            onEdit()
        } label: {
            Label("Edit Record", systemImage: "pencil")
        }
        .keyboardShortcut("e", modifiers: .command)

        Button {
            onDuplicate()
        } label: {
            Label("Duplicate Record", systemImage: "plus.square.on.square")
        }
        .keyboardShortcut("d", modifiers: .command)

        Divider()

        Button {
            Clipboard.copy(record.id)
        } label: {
            Label("Copy ID", systemImage: "doc.on.doc")
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])

        Button {
            copyRecordAsJSON()
        } label: {
            Label("Copy as JSON", systemImage: "curlybraces")
        }
        .keyboardShortcut("c", modifiers: [.command, .option])

        if !schema.isEmpty {
            Menu {
                ForEach(schema, id: \.id) { field in
                    Button {
                        copyFieldValue(field.name)
                    } label: {
                        Label(field.name, systemImage: fieldIcon(for: field.type))
                    }
                }
            } label: {
                Label("Copy Field Value", systemImage: "text.quote")
            }
        }

        Button {
            let recordURL = pocketbase.url
                .appendingPathComponent("/api/collections/\(collectionName)/records/\(record.id)")
            Clipboard.copy(recordURL.absoluteString)
        } label: {
            Label("Copy Record URL", systemImage: "link")
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete Record", systemImage: "trash")
        }
        .keyboardShortcut(.delete, modifiers: .command)
    }

    private func copyRecordAsJSON() {
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

        // Add content fields
        for (key, value) in record.content {
            dict[key] = jsonValue(from: value)
        }

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            Clipboard.copy(string)
        }
    }

    private func copyFieldValue(_ fieldName: String) {
        guard let value = record.content[fieldName] else { return }

        switch value {
        case .string(let str):
            Clipboard.copy(str)
        case .int(let num):
            Clipboard.copy(String(num))
        case .double(let num):
            Clipboard.copy(String(num))
        case .decimal(let num):
            Clipboard.copy(String(describing: num))
        case .bool(let bool):
            Clipboard.copy(bool ? "true" : "false")
        case .date(let date):
            Clipboard.copy(ISO8601DateFormatter().string(from: date))
        case .url(let url):
            Clipboard.copy(url.absoluteString)
        case .array, .dictionary:
            if let data = try? JSONSerialization.data(withJSONObject: jsonValue(from: value) ?? "", options: .prettyPrinted),
               let string = String(data: data, encoding: .utf8) {
                Clipboard.copy(string)
            }
        case .null:
            Clipboard.copy("null")
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

    private func fieldIcon(for type: FieldType) -> String {
        switch type {
        case .text: return "textformat"
        case .editor: return "doc.richtext"
        case .number: return "number"
        case .bool: return "checkmark.square"
        case .email, .customEmail: return "envelope"
        case .url: return "link"
        case .date, .dateTime, .autodate: return "calendar"
        case .select: return "list.bullet"
        case .json: return "curlybraces"
        case .file: return "doc"
        case .relation: return "arrow.triangle.branch"
        case .password: return "key"
        case .primaryKey: return "key.fill"
        case .geoPoint: return "mappin"
        case .unknown: return "questionmark"
        }
    }
}
