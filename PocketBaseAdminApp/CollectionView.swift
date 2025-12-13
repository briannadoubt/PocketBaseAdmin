//
//  CollectionView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI
import PocketBaseAdmin
import PocketBase
import OSLog
import Foundation

@Observable @MainActor
final class CollectionState: Identifiable {
    var collection: CollectionModel
    
    init(collection: CollectionModel) {
        self.collection = collection
    }
    
    var records: [RecordModel] = []
    var page: Int = 1
    
    var logger = Logger(subsystem: "PocketBaseAdminApp", category: "RecordsState")
    
    var retryCount: Int = 0
    var maxRetryCount: Int = 5
    
    var searchQuery: String = ""
    
    @concurrent
    func load(with pocketbase: PocketBase, sort: String? = nil) async {
        do {
            let newRecords = try await pocketbase.admin
                .records(collection.name)
                .list(page: page, sort: sort)
                .items
            await MainActor.run {
                records = newRecords
                retryCount = 0
            }
        } catch {
            let nsError = error as NSError

            if nsError.domain == NSURLErrorDomain,
               nsError.code == NSURLErrorCancelled {
                await MainActor.run {
                    retryCount += 1
                }
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    if retryCount >= maxRetryCount {
                        retryCount = 0
                        logger.error("Failed to load records after \(self.maxRetryCount) retries: \(String(describing: error))")
                        return
                    }
                    logger.info("Retrying to load records... (Attempt \(self.retryCount)/\(self.maxRetryCount))")
                }
                if await retryCount != 0 {
                    await load(with: pocketbase, sort: sort)
                }
            } else {
                await MainActor.run {
                    logger.error("Failed to load records: \(String(describing: error))")
                    retryCount = 0
                }
            }
        }
    }
}

struct CollectionView: View {
    @Bindable var state: CollectionState
    
    init(
        state: CollectionState,
    ) {
        self.state = state
    }
    
    @State private var selectedRecords: Set<RecordModel.ID> = []
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showRecordEditor = false
    @State private var editingRecord: RecordModel? = nil
    @State private var showCollectionEditor = false
    @State private var isDeletingCollection = false

    private var selectedRecordModel: RecordModel? {
        state.records.first { $0.id == selectedRecords.first }
    }

    private var schema: [Field] {
        state.collection.schema ?? []
    }

    private var sort: String? {
        let hasCreatedKey = schema.contains(where: { $0.name == "created" })
        return hasCreatedKey ? "-created" : nil
    }

    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionsState.self) private var collectionsState
    
    @State private var selectedInpector: InspectorTab?
    
    enum InspectorTab: String, CaseIterable, Identifiable {
        case record
        case schema
        case api

        var id: String { rawValue }

        var title: String {
            switch self {
            case .api:
                "API Preview"
            case .record:
                "Record Details"
            case .schema:
                "Schema"
            }
        }
    }
    
    var body: some View {
        Table(state.records, selection: $selectedRecords) {
            if horizontalSizeClass == .compact {
                TableColumn("Compact") { record in
                    CompactRecordRow(
                        schema: schema,
                        record: record
                    )
                }
            }

            // These are implicitely ignored when rendered with compact horizontal size class
            TableColumn("id") { record in
                FieldView(
                    field: Field(
                        id: "id",
                        name: "id",
                        presentable: false,
                        system: true,
                        type: .text
                    ),
                    record: record
                )
            }
            
            TableColumnForEach(schema, id: \.id) { field in
                TableColumn(field.name) { record in
                    FieldView(field: field, record: record)
                }
            }
        }
        .refreshable { [state = state, pocketbase = pocketbase, sort = sort] in
            await state.load(with: pocketbase, sort: sort)
        }
        .task { [state = state, pocketbase = pocketbase] in
            print("Loading collection records...")
            await state.load(with: pocketbase)
        }
        .navigationTitle(state.collection.name)
        .searchable(text: $state.searchQuery)
        .inspector(
            isPresented: Binding(
                get: { self.selectedInpector != nil },
                set: { _ in })
        ) {
            VStack {
                Picker(
                    selection: Binding {
                        selectedInpector ?? .record
                    } set: { inspector, _ in
                        self.selectedInpector = inspector
                    }
                ) {
                    ForEach(InspectorTab.allCases) { tab in
                        Text(tab.title)
                    }
                } label: {
                    EmptyView()
                }
            }
            switch selectedInpector {
            case .record:
                if
                    let selectedRecordModel,
                    let record = state.records.first(
                        where: { $0.id == selectedRecordModel.id }
                    )
                {
                    RecordInspectorView(record: record, schema: schema) { recordToEdit in
                        editingRecord = recordToEdit
                        showRecordEditor = true
                    }
                } else {
                    ContentUnavailableView(
                        "No record selected",
                        systemImage: "doc"
                    )
                }
            case .schema:
                SchemaInspectorView(
                    collection: state.collection,
                    onEdit: {
                        showCollectionEditor = true
                    },
                    onDelete: {
                        Task {
                            await deleteCollection()
                        }
                    }
                )
            case .api:
                ContentUnavailableView(
                    "API Preview Unavailable",
                    systemImage: "xmark",
                    description: Text("")
                )
            case nil:
                ContentUnavailableView(
                    "What the heck are you even doing?? Get a life.",
                    systemImage: "questionmark"
                )
            }
            
        }
        .toolbar {
#if !os(macOS)
            ToolbarItem(placement: .status) {
                if !selectedRecords.isEmpty {
                    Button("Deselect (\(selectedRecords.count.description))") {
                        selectedRecords.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
#endif // !os(macOS)
            
            ToolbarItem(placement: .status) {
                if !selectedRecords.isEmpty {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDeleting)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("New Record", systemImage: "plus") {
                    editingRecord = nil
                    showRecordEditor = true
                }
            }
        }
        .alert(
            "Delete \(selectedRecords.count) Record\(selectedRecords.count == 1 ? "" : "s")?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSelectedRecords()
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showRecordEditor) {
            RecordEditorView(
                collection: state.collection,
                record: editingRecord,
                onSave: { [state = state, pocketbase = pocketbase, sort = sort] in
                    await state.load(with: pocketbase, sort: sort)
                }
            )
        }
        .sheet(isPresented: $showCollectionEditor) {
            CollectionEditorView(
                collection: state.collection,
                onSave: { updatedCollection in
                    state.collection = updatedCollection
                }
            )
        }
    }

    private func deleteSelectedRecords() async {
        isDeleting = true
        defer { isDeleting = false }

        let recordsToDelete = selectedRecords
        var failedDeletions: [String] = []

        for recordId in recordsToDelete {
            do {
                try await pocketbase.admin.records(state.collection.name).delete(id: recordId)
            } catch {
                failedDeletions.append(recordId)
                state.logger.error("Failed to delete record \(recordId): \(error)")
            }
        }

        // Clear selection and refresh
        selectedRecords.removeAll()
        await state.load(with: pocketbase, sort: sort)

        if !failedDeletions.isEmpty {
            state.logger.warning("Failed to delete \(failedDeletions.count) records")
        }
    }

    private func deleteCollection() async {
        isDeletingCollection = true
        defer { isDeletingCollection = false }

        do {
            try await collectionsState.delete(id: state.collection.id, using: pocketbase)
            dismiss()
        } catch {
            state.logger.error("Failed to delete collection: \(error)")
        }
    }
}

struct CompactRecordRow: View {
    var schema: [Field]
    var record: RecordModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(schema, id: \.name) { field in
                    VStack(alignment: .leading) {
                        FieldView(field: field, record: record)
                        Text(field.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct RecordInspectorView: View {
    let record: RecordModel?
    let schema: [Field]
    var onEdit: ((RecordModel) -> Void)?

    var body: some View {
        Group {
            if let record = record {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Inspector").font(.headline)
                            Spacer()
                            if let onEdit {
                                Button("Edit", systemImage: "pencil") {
                                    onEdit(record)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        HStack(alignment: .top) {
                            Text("id").fontWeight(.semibold)
                            Spacer()
                            FieldView(
                                field: Field(
                                    id: "id",
                                    name: "id",
                                    presentable: false,
                                    system: false,
                                    type: .text
                                ),
                                record: record
                            )
                            if case let .bool(verified) = record
                                .content["verified"] ?? .null, verified {
                                Image(systemName: verified ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(verified ? .green : .secondary)
                            }
                        }
                        ForEach(schema, id: \.name) { field in
                            HStack(alignment: .top) {
                                Text(field.name).fontWeight(.semibold)
                                Spacer()
                                FieldView(field: field, record: record)
                            }
                        }
                    }
                    .safeAreaPadding()
                }
            } else {
                ContentUnavailableView(
                    "Select a record to inspect",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Once you select a record, you can inspect its fields here.")
                )
            }
        }
        #if os(macOS)
        .frame(maxWidth: 320, maxHeight: .infinity, alignment: .top)
        #endif
        .background(Color.gray.opacity(0.07))
    }
}

struct MailLink: View {
    let email: String
    @Environment(\.openURL) private var open
    var body: some View {
        #if os(iOS)
        Button(email) {
            if let url = URL(string: "mailto:\(email)") {
                open(url)
            }
        }
        #elseif os(macOS)
        Button(email) {
            if let url = URL(string: "mailto:\(email)") {
                open(url)
            }
        }
        #else
        Link(email, destination: URL(string: "mailto:\(email)")!)
        #endif
    }
}

struct FieldView: View {
    var field: Field
    var record: RecordModel
    
    var body: some View {
        switch field.name {
        case "id":
            Text(record.id)
        case "collectionId":
            Text(record.collectionId)
        case "collectionName":
            Text(record.collectionName)
        case "expand":
            if let expand = record.expand {
                JSONValueView(value: .dictionary(expand))
            }
        default:
            let fieldValue = record.content[field.name] ?? .null
            switch field.type {
            case .password:
                if case .string(let string) = fieldValue {
                    Text(Array(repeating: "•", count: string.count).joined())
                } else {
                    JSONValueView(value: fieldValue)
                }
            case .autodate, .date, .dateTime:
                if case .date(let date) = fieldValue {
                    Text(date, format: .dateTime)
                } else if case .string(let string) = fieldValue, let date = ISO8601DateFormatter().date(from: string) {
                    Text(date, format: .dateTime)
                } else {
                    JSONValueView(value: fieldValue)
                }
            case .bool:
                if case .bool(let bool) = fieldValue {
                    Image(systemName: bool ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(bool ? .green : .secondary)
                } else {
                    JSONValueView(value: fieldValue)
                }
            case .customEmail, .email:
                if case .string(let email) = fieldValue {
                    MailLink(email: email)
                } else {
                    JSONValueView(value: fieldValue)
                }
            case .file:
                if case .string(let string) = fieldValue, let url = URL(string: string) {
                    Link("File", destination: url)
                } else if case .array(let array) = fieldValue {
                    VStack(alignment: .leading) {
                        ForEach(array.indices, id: \ .self) { idx in
                            if case .string(let urlString) = array[idx], let url = URL(string: urlString) {
                                Link("File \(idx + 1)", destination: url)
                            }
                        }
                    }
                } else {
                    JSONValueView(value: fieldValue)
                }
            case .json:
                JSONValueView(value: fieldValue)
            case .number:
                switch fieldValue {
                case .int(let int):
                    Text(int, format: .number)
                case .double(let double):
                    Text(double, format: .number)
                case .decimal(let decimal):
                    Text(decimal, format: .number)
                default:
                    JSONValueView(value: fieldValue)
                }
            case .relation:
                JSONValueView(value: fieldValue)
            case .select:
                if case .string(let string) = fieldValue {
                    Text(string)
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                } else if case .array(let array) = fieldValue {
                    HStack { ForEach(array, id: \ .self) { value in JSONValueView(value: value) } }
                } else {
                    JSONValueView(value: fieldValue)
                }
            case .text, .editor:
                // Always render as plain text, never a Link, regardless of underlying value type
                switch fieldValue {
                case .string(let string):
                    Text(string)
                case .url(let url):
                    Text(url.absoluteString)
                case .int(let int):
                    Text(int, format: .number)
                case .double(let double):
                    Text(double, format: .number)
                case .decimal(let decimal):
                    Text(decimal, format: .number)
                case .bool(let bool):
                    Text(bool.description)
                case .date(let date):
                    Text(date, format: .dateTime)
                default:
                    JSONValueView(value: fieldValue)
                }
            case .url:
                if case .string(let string) = fieldValue, let url = URL(string: string) {
                    Link(string, destination: url)
                } else if case .url(let url) = fieldValue {
                    Link(url.absoluteString, destination: url)
                } else {
                    JSONValueView(value: fieldValue)
                }
            }
        }
    }
}

struct JSONValueView: View {
    var value: JSONValue
    var body: some View {
        switch value {
        case .array(let array):
            VStack {
                ForEach(array, id: \.self) { item in
                    JSONValueView(value: item)
                }
            }
        case .bool(let bool):
            Text(bool.description)
        case .date(let date):
            Text(date, format: .dateTime)
        case .decimal(let decimal):
            Text(decimal, format: .number)
        case .url(let url):
            Link(destination: url) {
                Text(url.absoluteString)
            }
            .buttonStyle(.plain)
        case .dictionary(let dictionary):
            VStack {
                ForEach(Array(dictionary.keys).sorted(), id: \.self) { key in
                    HStack {
                        Text(key) + Text(verbatim: ":")
                        if let value = dictionary[key] {
                            JSONValueView(value: value)
                        }
                    }
                }
            }
        case .double(let double):
            Text(double, format: .number)
        case .null:
            Text("(Empty)")
                .foregroundStyle(.secondary)
        case .string(let string):
            Text(string)
        case .int(let int):
            Text(int, format: .number)
        }
    }
}

struct SchemaInspectorView: View {
    let collection: CollectionModel
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private var schema: [Field] {
        collection.schema ?? []
    }

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Schema")
                        .font(.headline)
                    Spacer()
                    if let onEdit, !collection.system {
                        Button("Edit", systemImage: "pencil") {
                            onEdit()
                        }
                        .buttonStyle(.bordered)
                    }
                    if let _ = onDelete, !collection.system {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .alert("Delete Collection?", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        onDelete?()
                    }
                } message: {
                    Text("Are you sure you want to delete \"\(collection.name)\"? This will permanently delete all records in this collection. This action cannot be undone.")
                }

                // Collection info
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Type") {
                        Text(collection.type.rawValue.capitalized)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(collectionTypeColor.opacity(0.2))
                            )
                    }
                    if collection.system {
                        LabeledContent("System") {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                Divider()

                // Fields section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fields")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if schema.isEmpty {
                        Text("No fields defined")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(schema, id: \.id) { field in
                            SchemaFieldRow(field: field)
                        }
                    }
                }

                Divider()

                // Rules section
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Rules")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    RuleRow(name: "List", rule: collection.listRule)
                    RuleRow(name: "View", rule: collection.viewRule)
                    RuleRow(name: "Create", rule: collection.createRule)
                    RuleRow(name: "Update", rule: collection.updateRule)
                    RuleRow(name: "Delete", rule: collection.deleteRule)
                }

                if let indexes = collection.indexes, !indexes.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Indexes")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(indexes, id: \.self) { index in
                            Text(index)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .safeAreaPadding()
        }
        #if os(macOS)
        .frame(maxWidth: 320, maxHeight: .infinity, alignment: .top)
        #endif
        .background(Color.gray.opacity(0.07))
    }

    private var collectionTypeColor: Color {
        switch collection.type {
        case .base:
            return .blue
        case .auth:
            return .green
        case .view:
            return .purple
        }
    }
}

struct SchemaFieldRow: View {
    let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(field.name)
                    .fontWeight(.medium)
                if field.required == true {
                    Text("*")
                        .foregroundStyle(.red)
                }
                if field.system {
                    Text("system")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.2))
                        )
                }
                Spacer()
                Text(field.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fieldTypeColor.opacity(0.15))
                    )
                    .foregroundStyle(fieldTypeColor)
            }

            if let options = field.options {
                FieldOptionsView(options: options, fieldType: field.type)
            }
        }
        .padding(.vertical, 4)
    }

    private var fieldTypeColor: Color {
        switch field.type {
        case .text, .editor:
            return .blue
        case .number:
            return .orange
        case .bool:
            return .green
        case .email, .customEmail:
            return .purple
        case .url:
            return .cyan
        case .date, .dateTime, .autodate:
            return .pink
        case .select:
            return .indigo
        case .file:
            return .brown
        case .relation:
            return .mint
        case .json:
            return .gray
        case .password:
            return .red
        }
    }
}

struct FieldOptionsView: View {
    let options: FieldOptions
    let fieldType: FieldType

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let min = options.min {
                optionRow("Min", value: "\(min)")
            }
            if let max = options.max {
                optionRow("Max", value: "\(max)")
            }
            if let maxSize = options.maxSize {
                optionRow("Max size", value: ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .file))
            }
            if let values = options.values, !values.isEmpty {
                optionRow("Values", value: values.joined(separator: ", "))
            }
            if let collectionId = options.collectionId {
                optionRow("Collection", value: collectionId)
            }
            if let mimeTypes = options.mimeTypes, !mimeTypes.isEmpty {
                optionRow("MIME types", value: mimeTypes.joined(separator: ", "))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func optionRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
            Text(value)
        }
    }
}

struct RuleRow: View {
    let name: String
    let rule: String?

    var body: some View {
        HStack(alignment: .top) {
            Text(name)
                .frame(width: 60, alignment: .leading)
                .foregroundStyle(.secondary)

            if let rule, !rule.isEmpty {
                Text(rule)
                    .font(.system(.caption, design: .monospaced))
            } else if rule == "" {
                Text("(public)")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("(locked)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

#if os(macOS)
enum UserInterfaceSizeClass {
    case compact
    case regular
}

struct HorizontalSizeClassEnvironmentKey: EnvironmentKey {
    static let defaultValue: UserInterfaceSizeClass = .regular
}

struct VerticalSizeClassEnvironmentKey: EnvironmentKey {
    static let defaultValue: UserInterfaceSizeClass = .regular
}

extension EnvironmentValues {
    var horizontalSizeClass: UserInterfaceSizeClass {
        get { self[HorizontalSizeClassEnvironmentKey.self] }
        set { self[HorizontalSizeClassEnvironmentKey.self] = newValue }
    }

    var verticalSizeClass: UserInterfaceSizeClass {
        get { self[VerticalSizeClassEnvironmentKey.self] }
        set { self[VerticalSizeClassEnvironmentKey.self] = newValue }
    }
}
#endif // os(macOS)
