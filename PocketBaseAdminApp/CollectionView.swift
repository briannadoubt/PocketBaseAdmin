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
    
    @State private var selectedInpector: InspectorTab?
    
    enum InspectorTab: String, CaseIterable, Identifiable {
        case record
        case api
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .api:
                "API Preview"
            case .record:
                "Record Details"
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
