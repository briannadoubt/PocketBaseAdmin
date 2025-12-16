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
    
    /// Get all relation field names for expanding
    private var relationFieldNames: String? {
        let names = (collection.fields ?? [])
            .filter { $0.type == .relation }
            .map(\.name)
        return names.isEmpty ? nil : names.joined(separator: ",")
    }

    func load(with pocketbase: PocketBase, sort: String? = nil) async {
        // Capture values on main actor before async work
        let collectionName = collection.name
        let expandFields = relationFieldNames

        do {
            let newRecords = try await pocketbase.admin
                .records(collectionName)
                .list(page: page, sort: sort, expand: expandFields)
                .items
            records = newRecords
            retryCount = 0
        } catch {
            let nsError = error as NSError

            if nsError.domain == NSURLErrorDomain,
               nsError.code == NSURLErrorCancelled {
                retryCount += 1
                try? await Task.sleep(for: .seconds(1))
                if retryCount >= maxRetryCount {
                    retryCount = 0
                    logger.error("Failed to load records after \(self.maxRetryCount) retries: \(String(describing: error))")
                    return
                }
                logger.info("Retrying to load records... (Attempt \(self.retryCount)/\(self.maxRetryCount))")
                await load(with: pocketbase, sort: sort)
            } else {
                logger.error("Failed to load records: \(String(describing: error))")
                retryCount = 0
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
    @State private var recordEditorMode: RecordEditorMode? = nil
    @State private var showCollectionEditor = false
    @State private var isDeletingCollection = false

    /// Mode for the record editor sheet
    enum RecordEditorMode: Identifiable {
        case new
        case edit(RecordModel)

        var id: String {
            switch self {
            case .new: return "new-record"
            case .edit(let record): return "edit-\(record.id)"
            }
        }

        var record: RecordModel? {
            switch self {
            case .new: return nil
            case .edit(let record): return record
            }
        }
    }

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

    /// Presentable fields to show in compact card view (limit to first few meaningful fields)
    private var presentableFields: [Field] {
        let fields = schema.filter { field in
            // Prioritize presentable fields, then text/email fields
            field.presentable == true ||
            field.type == .text ||
            field.type == .email ||
            field.type == .select
        }
        return Array(fields.prefix(3))
    }

    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionsState.self) private var collectionsState
    
    @State private var selectedInpector: InspectorTab? = .api
    @State private var showInspectorSheet = false

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

        var icon: String {
            switch self {
            case .api:
                "curlybraces"
            case .record:
                "doc.text"
            case .schema:
                "list.bullet.rectangle"
            }
        }
    }

    // MARK: - Inspector Content

    @ViewBuilder
    private var inspectorContent: some View {
        VStack(spacing: 0) {
            Picker(
                selection: Binding {
                    selectedInpector ?? .record
                } set: { inspector, _ in
                    self.selectedInpector = inspector
                }
            ) {
                ForEach(InspectorTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch selectedInpector {
                case .record:
                    if
                        let selectedRecordModel,
                        let record = state.records.first(
                            where: { $0.id == selectedRecordModel.id }
                        )
                    {
                        RecordInspectorView(record: record, schema: schema, collectionsState: collectionsState) { recordToEdit in
                            recordEditorMode = .edit(recordToEdit)
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
                    SwiftAPIPreviewView(collection: state.collection)
                case nil:
                    ContentUnavailableView(
                        "Select an inspector tab",
                        systemImage: "sidebar.trailing"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Compact Layout (iOS)

    @ViewBuilder
    private var compactRecordsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if state.records.isEmpty {
                    ContentUnavailableView {
                        Label("No Records", systemImage: "doc")
                    } description: {
                        Text("This collection is empty. Tap + to create a record.")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(state.records) { record in
                        RecordCardView(
                            record: record,
                            schema: schema,
                            presentableFields: presentableFields,
                            collectionsState: collectionsState,
                            onEdit: {
                                recordEditorMode = .edit(record)
                            }
                        )
                        .contextMenu {
                            RecordMenuContent(
                                record: record,
                                schema: schema,
                                collectionName: state.collection.name,
                                onEdit: {
                                    recordEditorMode = .edit(record)
                                },
                                onDuplicate: {
                                    duplicateRecord(record)
                                },
                                onDelete: {
                                    selectedRecords = Set([record.id])
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Regular Layout (macOS/iPad)

    @ViewBuilder
    private var regularTable: some View {
        Table(state.records, selection: $selectedRecords) {
            TableColumn("id") { record in
                FieldView(
                    field: Field(
                        id: "id",
                        name: "id",
                        presentable: false,
                        system: true,
                        type: .text
                    ),
                    record: record,
                    collectionsState: collectionsState
                )
            }
            .width(min: 80, ideal: 120, max: 200)

            TableColumnForEach(schema, id: \.id) { field in
                TableColumn(field.name) { record in
                    FieldView(field: field, record: record, collectionsState: collectionsState)
                }
                .width(min: 80, ideal: columnWidth(for: field), max: 300)
            }
        }
        .contextMenu(forSelectionType: RecordModel.ID.self) { selectedIds in
            if let recordId = selectedIds.first,
               let record = state.records.first(where: { $0.id == recordId }) {
                RecordMenuContent(
                    record: record,
                    schema: schema,
                    collectionName: state.collection.name,
                    onEdit: {
                        recordEditorMode = .edit(record)
                    },
                    onDuplicate: {
                        duplicateRecord(record)
                    },
                    onDelete: {
                        selectedRecords = Set([record.id])
                        showDeleteConfirmation = true
                    }
                )
            }
        } primaryAction: { selectedIds in
            // Double-click to edit
            if let recordId = selectedIds.first,
               let record = state.records.first(where: { $0.id == recordId }) {
                recordEditorMode = .edit(record)
            }
        }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactRecordsList
            } else {
                regularTable
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
                get: { horizontalSizeClass != .compact && self.selectedInpector != nil },
                set: { _ in })
        ) {
            inspectorContent
                .inspectorColumnWidth(min: 300, ideal: 400, max: 600)
        }
        .sheet(isPresented: $showInspectorSheet) {
            NavigationStack {
                inspectorContent
                    .navigationTitle("Inspector")
                    #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showInspectorSheet = false
                            }
                        }
                    }
            }
            #if !os(macOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
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
                Button {
                    recordEditorMode = .new
                } label: {
                    Label("New Record", systemImage: "doc.badge.plus")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    if horizontalSizeClass == .compact {
                        showInspectorSheet = true
                    } else {
                        if selectedInpector == nil {
                            selectedInpector = .api
                        } else {
                            selectedInpector = nil
                        }
                    }
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
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
        .sheet(item: $recordEditorMode) { mode in
            RecordEditorView(
                collection: state.collection,
                record: mode.record,
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
        .focusedValue(\.selectedRecord, selectedRecordModel)
        .focusedValue(\.selectedCollection, state.collection)
        .onReceive(NotificationCenter.default.publisher(for: .newRecord)) { _ in
            recordEditorMode = .new
        }
        .onReceive(NotificationCenter.default.publisher(for: .refresh)) { _ in
            Task {
                await state.load(with: pocketbase, sort: sort)
            }
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

    private func duplicateRecord(_ record: RecordModel) {
        // Open the record editor with the record data for duplication
        // The editor will create a new record when saved (uses record content but creates new)
        recordEditorMode = .edit(record)
    }

    /// Returns ideal column width based on field type
    private func columnWidth(for field: Field) -> CGFloat {
        switch field.type {
        case .text, .editor:
            return 200
        case .number:
            return 100
        case .bool:
            return 80
        case .email, .customEmail:
            return 180
        case .url:
            return 200
        case .date, .dateTime, .autodate:
            return 160
        case .select:
            return 120
        case .json:
            return 200
        case .file:
            return 150
        case .relation:
            return 150
        case .password:
            return 120
        case .primaryKey:
            return 120
        case .geoPoint:
            return 150
        case .unknown:
            return 150
        }
    }

}

/// Card-style view for displaying a record on compact layouts (iOS)
struct RecordCardView: View {
    let record: RecordModel
    let schema: [Field]
    let presentableFields: [Field]
    var collectionsState: CollectionsState?
    var onEdit: (() -> Void)?

    @State private var isExpanded = false

    /// Get summary fields to show in collapsed state (prioritize presentable fields)
    private var summaryFields: [(String, String)] {
        var results: [(String, String)] = []

        // First try presentable fields
        for field in presentableFields.prefix(2) {
            if let value = record.content[field.name], !isEmptyValue(value) {
                results.append((field.name, stringValue(from: value)))
            }
        }

        // If no presentable fields, try common field names
        if results.isEmpty {
            for fieldName in ["name", "title", "label", "email", "username"] {
                if let value = record.content[fieldName], !isEmptyValue(value) {
                    results.append((fieldName, stringValue(from: value)))
                    break
                }
            }
        }

        return results
    }

    /// All displayable fields for expanded view
    private var allFields: [(String, String)] {
        var results: [(String, String)] = []

        // Add ID first
        results.append(("id", record.id))

        // Add schema fields
        for field in schema {
            if let value = record.content[field.name] {
                results.append((field.name, stringValue(from: value)))
            }
        }

        // Add created/updated if available
        if let created = record.created {
            results.append(("created", created.formatted(date: .numeric, time: .omitted)))
        }

        return results
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("id: \(record.id)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if !summaryFields.isEmpty {
                            HStack(spacing: 12) {
                                ForEach(summaryFields, id: \.0) { name, value in
                                    Text("\(name): \(value)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)

                VStack(spacing: 8) {
                    ForEach(allFields, id: \.0) { name, value in
                        HStack(alignment: .top) {
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 80, alignment: .leading)

                            Spacer()

                            Text(value)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    if let onEdit {
                        Divider()
                            .padding(.vertical, 4)

                        Button {
                            onEdit()
                        } label: {
                            Label("Edit Record", systemImage: "pencil")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
        )
    }

    private func isEmptyValue(_ value: JSONValue) -> Bool {
        switch value {
        case .null: return true
        case .string(let str): return str.isEmpty
        case .array(let arr): return arr.isEmpty
        default: return false
        }
    }

    private func stringValue(from value: JSONValue) -> String {
        switch value {
        case .string(let str): return str
        case .int(let num): return String(num)
        case .double(let num): return num.formatted(.number.precision(.fractionLength(0...2)))
        case .bool(let bool): return bool ? "Yes" : "No"
        case .date(let date): return date.formatted(date: .numeric, time: .omitted)
        case .array(let arr): return "[\(arr.count) items]"
        case .dictionary: return "{...}"
        case .null: return "-"
        case .url(let url): return url.absoluteString
        case .decimal(let dec): return "\(dec)"
        }
    }
}

struct RecordInspectorView: View {
    let record: RecordModel?
    let schema: [Field]
    var collectionsState: CollectionsState?
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
                                record: record,
                                collectionsState: collectionsState
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
                                FieldView(field: field, record: record, collectionsState: collectionsState)
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
        .frame(maxHeight: .infinity, alignment: .top)
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
    var collectionsState: CollectionsState?

    /// Get presentable field values from an expanded relation record
    private func presentableValue(from expandedRecord: [String: JSONValue], collectionId: String?) -> String? {
        guard let collectionId,
              let collectionsState,
              let relatedCollection = collectionsState.collections.first(where: { $0.collection.id == collectionId })?.collection
        else {
            // Fallback: try common presentable field names
            for key in ["name", "title", "label", "username", "email"] {
                if case .string(let value) = expandedRecord[key] {
                    return value
                }
            }
            return nil
        }

        // Find fields marked as presentable
        let presentableFields = (relatedCollection.fields ?? []).filter { $0.presentable == true }

        if presentableFields.isEmpty {
            // Fallback: try common presentable field names
            for key in ["name", "title", "label", "username", "email"] {
                if case .string(let value) = expandedRecord[key] {
                    return value
                }
            }
            return nil
        }

        // Collect presentable values
        let values = presentableFields.compactMap { field -> String? in
            guard let value = expandedRecord[field.name] else { return nil }
            switch value {
            case .string(let str): return str
            case .int(let num): return String(num)
            case .double(let num): return String(num)
            case .bool(let bool): return bool ? "Yes" : "No"
            default: return nil
            }
        }

        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    var body: some View {
        switch field.name {
        case "id":
            Text(record.id)
        case "collectionId":
            Text(record.collectionId)
        case "collectionName":
            Text(record.collectionName)
        case "created":
            if let date = record.created {
                Text(date, format: .dateTime)
            } else {
                Text("(Empty)")
                    .foregroundStyle(.secondary)
            }
        case "updated":
            if let date = record.updated {
                Text(date, format: .dateTime)
            } else {
                Text("(Empty)")
                    .foregroundStyle(.secondary)
            }
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
                RelationFieldView(
                    fieldName: field.name,
                    fieldValue: fieldValue,
                    expandedData: record.expand,
                    collectionId: field.options?.collectionId,
                    collectionsState: collectionsState,
                    presentableValue: presentableValue
                )
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
            case .primaryKey:
                if case .string(let string) = fieldValue {
                    Text(string)
                        .font(.system(.body, design: .monospaced))
                } else {
                    JSONValueView(value: fieldValue)
                }
            case .geoPoint:
                JSONValueView(value: fieldValue)
            case .unknown:
                JSONValueView(value: fieldValue)
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
                        Text("\(key):")
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

struct RelationFieldView: View {
    let fieldName: String
    let fieldValue: JSONValue
    let expandedData: [String: JSONValue]?
    let collectionId: String?
    let collectionsState: CollectionsState?
    let presentableValue: ([String: JSONValue], String?) -> String?

    var body: some View {
        // Check if we have expanded data for this relation
        if let expandedData,
           let expanded = expandedData[fieldName] {
            switch expanded {
            case .dictionary(let dict):
                // Single relation - show presentable value
                if let displayValue = presentableValue(dict, collectionId) {
                    RelationChip(text: displayValue)
                } else if case .string(let id) = dict["id"] {
                    RelationChip(text: id, isId: true)
                } else {
                    Text("(Empty)")
                        .foregroundStyle(.secondary)
                }

            case .array(let records):
                // Multiple relations
                if records.isEmpty {
                    Text("(Empty)")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        ForEach(records.prefix(3).indices, id: \.self) { idx in
                            if case .dictionary(let dict) = records[idx] {
                                if let displayValue = presentableValue(dict, collectionId) {
                                    RelationChip(text: displayValue)
                                } else if case .string(let id) = dict["id"] {
                                    RelationChip(text: id, isId: true)
                                }
                            }
                        }
                        if records.count > 3 {
                            Text("+\(records.count - 3)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            default:
                JSONValueView(value: fieldValue)
            }
        } else {
            // No expanded data, show raw IDs
            switch fieldValue {
            case .string(let id):
                RelationChip(text: id, isId: true)
            case .array(let ids):
                if ids.isEmpty {
                    Text("(Empty)")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        ForEach(ids.prefix(3).indices, id: \.self) { idx in
                            if case .string(let id) = ids[idx] {
                                RelationChip(text: id, isId: true)
                            }
                        }
                        if ids.count > 3 {
                            Text("+\(ids.count - 3)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            case .null:
                Text("(Empty)")
                    .foregroundStyle(.secondary)
            default:
                JSONValueView(value: fieldValue)
            }
        }
    }
}

struct RelationChip: View {
    let text: String
    var isId: Bool = false

    var body: some View {
        Text(isId ? String(text.prefix(8)) + "..." : text)
            .font(isId ? .system(.caption, design: .monospaced) : .caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isId ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.15))
            )
            .foregroundStyle(isId ? .secondary : .primary)
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
        .frame(maxHeight: .infinity, alignment: .top)
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

// MARK: - Swift API Preview

struct SwiftAPIPreviewView: View {
    let collection: CollectionModel

    @State private var selectedOperation: APIOperation = .list

    enum APIOperation: String, CaseIterable, Identifiable {
        case list = "List"
        case query = "Query"
        case view = "View"
        case create = "Create"
        case update = "Update"
        case delete = "Delete"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .query: return "magnifyingglass"
            case .view: return "eye"
            case .create: return "plus"
            case .update: return "pencil"
            case .delete: return "trash"
            }
        }

        var httpMethod: String {
            switch self {
            case .list, .view, .query: return "GET"
            case .create: return "POST"
            case .update: return "PATCH"
            case .delete: return "DELETE"
            }
        }

        var methodColor: Color {
            switch self {
            case .list, .view, .query: return .green
            case .create: return .blue
            case .update: return .orange
            case .delete: return .red
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Swift SDK")
                    .font(.headline)

                // Model definition
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Definition")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    CodeBlockView(code: modelDefinitionCode)
                }

                // Collection instance
                VStack(alignment: .leading, spacing: 8) {
                    Text("Collection Instance")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    CodeBlockView(code: collectionDefinitionCode)
                }

                Divider()

                // Operation selector
                Picker("Operation", selection: $selectedOperation) {
                    ForEach(APIOperation.allCases) { op in
                        Text(op.rawValue).tag(op)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // Code preview
                VStack(alignment: .leading, spacing: 8) {
                    Text(operationTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(operationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if selectedOperation == .query {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@RealtimeQuery")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.green)
                                Text("Real-time updates via Server-Sent Events")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                CodeBlockView(code: realtimeQueryCode)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("@StaticQuery")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                                Text("Fetch once with optional filtering")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                CodeBlockView(code: staticQueryCode)
                            }
                        }
                    } else {
                        CodeBlockView(code: swiftCode)
                    }
                }

                Divider()

                // API Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Text(selectedOperation.httpMethod)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(selectedOperation.methodColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(selectedOperation.methodColor.opacity(0.15))
                            )

                        Text(apiEndpoint)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if selectedOperation == .list || selectedOperation == .query {
                    Divider()
                    queryParametersSection
                }
            }
            .safeAreaPadding()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.gray.opacity(0.07))
    }

    private var operationTitle: String {
        switch selectedOperation {
        case .list: return "List (\(collection.name))"
        case .query: return "Query (\(collection.name))"
        case .view: return "View (\(collection.name))"
        case .create: return "Create (\(collection.name))"
        case .update: return "Update (\(collection.name))"
        case .delete: return "Delete (\(collection.name))"
        }
    }

    private var operationDescription: String {
        switch selectedOperation {
        case .list: return "Fetch a paginated \(collection.name) records list with #Filter for type-safe filtering."
        case .query: return "Use @RealtimeQuery or @StaticQuery property wrappers for SwiftUI views."
        case .view: return "Fetch a single \(collection.name) record by ID."
        case .create: return "Create a new \(collection.name) record."
        case .update: return "Update an existing \(collection.name) record."
        case .delete: return "Delete an existing \(collection.name) record."
        }
    }

    private var apiEndpoint: String {
        switch selectedOperation {
        case .list, .query: return "/api/collections/\(collection.name)/records"
        case .view: return "/api/collections/\(collection.name)/records/:id"
        case .create: return "/api/collections/\(collection.name)/records"
        case .update: return "/api/collections/\(collection.name)/records/:id"
        case .delete: return "/api/collections/\(collection.name)/records/:id"
        }
    }

    private var collectionDefinitionCode: String {
        let name = collection.name
        let typeName = singularized(name).prefix(1).uppercased() + singularized(name).dropFirst()

        return """
        let pb = PocketBase(url: "http://127.0.0.1:8090")
        let \(name) = pb.collection(\(typeName).self)
        """
    }

    private var modelDefinitionCode: String {
        let name = collection.name
        let typeName = singularized(name).prefix(1).uppercased() + singularized(name).dropFirst()
        let isAuth = collection.type == .auth
        let macroName = isAuth ? "AuthCollection" : "BaseCollection"

        return """
        import PocketBase

        @\(macroName)("\(name)")
        struct \(typeName) {
        \(fieldDefinitions)
        }
        """
    }

    private var swiftCode: String {
        let name = collection.name
        let typeName = singularized(name).prefix(1).uppercased() + singularized(name).dropFirst()

        switch selectedOperation {
        case .list:
            return """
            // Type-safe filtering with #Filter macro
            let filter = #Filter<\(typeName)> { record in
                record.created > .distantPast
            }

            // Fetch a paginated records list
            let records = try await \(name).list(
                page: 1,
                perPage: 50,
                filter: filter,
                sort: [.init(\\.created, order: .reverse)]
            )

            // Or fetch all records at once
            let allRecords = try await \(name).getFullList(
                sort: [.init(\\.created, order: .reverse)]
            )

            // Or fetch the first matching record
            let record = try await \(name).getFirstListItem(
                filter: #Filter { $0.id != "" }
            )
            """

        case .query:
            return "" // Handled separately with realtimeQueryCode and staticQueryCode

        case .view:
            return """
            // Fetch a single record by ID
            let record = try await \(name).getOne("RECORD_ID")

            // With expanded relations
            let expanded = try await \(name).getOne(
                "RECORD_ID",
                expand: "relField1,relField2"
            )
            """

        case .create:
            return """
            // Create a new record
            let record = try await \(name).create(\(typeName)(
                \(fieldInitializers)
            ))
            """

        case .update:
            return """
            // Update an existing record
            var record = try await \(name).getOne("RECORD_ID")
            record.someField = "newValue"
            let saved = try await \(name).update(record.id, body: record)
            """

        case .delete:
            return """
            // Delete a record by ID
            try await \(name).delete("RECORD_ID")
            """
        }
    }

    private var realtimeQueryCode: String {
        let name = collection.name
        let typeName = singularized(name).prefix(1).uppercased() + singularized(name).dropFirst()

        return """
        struct \(typeName)ListView: View {
            @RealtimeQuery<\(typeName)>(
                sort: [.init(\\.created, order: .reverse)]
            ) private var \(name)

            var body: some View {
                List(\(name)) { record in
                    Text(record.id)
                }
                .task {
                    try? await $\(name).start()
                }
            }
        }
        """
    }

    private var staticQueryCode: String {
        let name = collection.name
        let typeName = singularized(name).prefix(1).uppercased() + singularized(name).dropFirst()

        return """
        struct \(typeName)ListView: View {
            @StaticQuery<\(typeName)>(
                sort: [.init(\\.created, order: .reverse)],
                filter: #Filter<\(typeName)> { $0.created < .now }
            ) private var \(name)

            var body: some View {
                List(\(name)) { record in
                    Text(record.id)
                }
                .task {
                    try? await \(name).load()
                }
            }
        }
        """
    }

    private var fieldDefinitions: String {
        // Fields auto-generated by macros - don't show in model definition
        let baseAutoFields: Set<String> = ["id", "created", "updated", "collectionId", "collectionName"]
        let authAutoFields: Set<String> = ["email", "emailVisibility", "verified", "tokenKey", "password", "passwordConfirm", "username"]
        let autoFields = collection.type == .auth ? baseAutoFields.union(authAutoFields) : baseAutoFields

        let fields = (collection.fields ?? []).filter { !$0.system && !autoFields.contains($0.name) }
        if fields.isEmpty {
            return "    // Add your custom fields here"
        }

        return fields.map { field in
            let swiftType = swiftType(for: field)
            let prefix = fieldPrefix(for: field)
            return "    \(prefix)var \(field.name): \(swiftType)"
        }.joined(separator: "\n")
    }

    private var fieldInitializers: String {
        // Fields auto-generated by macros - don't show in initializer
        let baseAutoFields: Set<String> = ["id", "created", "updated", "collectionId", "collectionName"]
        let authAutoFields: Set<String> = ["email", "emailVisibility", "verified", "tokenKey", "password", "passwordConfirm", "username"]
        let autoFields = collection.type == .auth ? baseAutoFields.union(authAutoFields) : baseAutoFields

        let fields = (collection.fields ?? []).filter { !$0.system && !autoFields.contains($0.name) }
        if fields.isEmpty {
            return "// ..."
        }

        return fields.prefix(3).map { field in
            "\(field.name): \(defaultValue(for: field))"
        }.joined(separator: ",\n        ")
    }

    private func swiftType(for field: Field) -> String {
        switch field.type {
        case .text, .editor, .email, .url:
            return field.required == true ? "String" : "String?"
        case .number:
            return field.required == true ? "Int" : "Int?"
        case .bool:
            return field.required == true ? "Bool" : "Bool?"
        case .date, .dateTime, .autodate:
            return field.required == true ? "Date" : "Date?"
        case .select:
            if field.options?.maxSelect ?? 1 > 1 {
                return "[String]"
            }
            return field.required == true ? "String" : "String?"
        case .file:
            if field.options?.maxSelect ?? 1 > 1 {
                return "[FileValue]?"
            }
            return "FileValue?"
        case .relation:
            return "[RelatedRecord]?"
        case .json, .geoPoint:
            return "[String: Any]?"
        case .password, .customEmail:
            return "String?"
        case .primaryKey:
            return "String?"
        case .unknown:
            return "String?"
        }
    }

    private func fieldPrefix(for field: Field) -> String {
        switch field.type {
        case .file:
            return "@File "
        case .relation:
            return "@Relation "
        default:
            return ""
        }
    }

    private func defaultValue(for field: Field) -> String {
        switch field.type {
        case .text, .editor, .email, .url, .select:
            return "\"\""
        case .number:
            return "0"
        case .bool:
            return "false"
        case .date, .dateTime, .autodate:
            return "Date()"
        case .file, .relation, .json, .geoPoint:
            return "nil"
        case .password, .customEmail, .primaryKey:
            return "nil"
        case .unknown:
            return "nil"
        }
    }

    private var queryParameters: [QueryParam] {
        [
            QueryParam(name: "page", type: "Int", description: "The page number (default: 1)"),
            QueryParam(name: "perPage", type: "Int", description: "Records per page (default: 30, max: 500)"),
            QueryParam(name: "sort", type: "String", description: "Sort expression, e.g. \"-created,title\""),
            QueryParam(name: "filter", type: "String", description: "Filter expression, e.g. \"status='active'\""),
            QueryParam(name: "expand", type: "String", description: "Relations to expand, e.g. \"user,tags\""),
        ]
    }

    @ViewBuilder
    private var queryParametersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Query Parameters")
                .font(.subheadline)
                .fontWeight(.semibold)

            Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Param")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .gridCellColumns(3)

                ForEach(queryParameters) { param in
                    GridRow {
                        Text(param.name)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)

                        Text(param.type)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange.opacity(0.15))
                            )

                        Text(param.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.bottom)
    }

    /// Convert plural collection name to singular type name
    private func singularized(_ name: String) -> String {
        let lowercased = name.lowercased()

        // Uncountable words - same in singular and plural
        let uncountables: Set<String> = [
            "equipment", "information", "rice", "money", "species", "series",
            "fish", "sheep", "deer", "aircraft", "salmon", "trout", "swine",
            "moose", "bison", "corps", "means", "offspring", "news", "metadata"
        ]
        if uncountables.contains(lowercased) {
            return name
        }

        // Irregular plurals (plural -> singular)
        let irregulars: [String: String] = [
            "people": "person",
            "children": "child",
            "mice": "mouse",
            "lice": "louse",
            "geese": "goose",
            "men": "man",
            "women": "woman",
            "teeth": "tooth",
            "feet": "foot",
            "oxen": "ox",
            "indices": "index",
            "matrices": "matrix",
            "vertices": "vertex",
            "axes": "axis",
            "analyses": "analysis",
            "diagnoses": "diagnosis",
            "theses": "thesis",
            "crises": "crisis",
            "phenomena": "phenomenon",
            "criteria": "criterion",
            "data": "datum",
            "media": "medium",
            "strata": "stratum",
            "cacti": "cactus",
            "foci": "focus",
            "fungi": "fungus",
            "nuclei": "nucleus",
            "syllabi": "syllabus",
            "alumni": "alumnus",
            "octopi": "octopus",
            "radii": "radius",
            "stimuli": "stimulus",
            "larvae": "larva",
            "antennae": "antenna",
            "formulae": "formula",
            "nebulae": "nebula",
            "vertebrae": "vertebra",
            "lives": "life",
            "wives": "wife",
            "knives": "knife",
            "leaves": "leaf",
            "halves": "half",
            "selves": "self",
            "elves": "elf",
            "loaves": "loaf",
            "wolves": "wolf",
            "calves": "calf",
            "shelves": "shelf",
            "thieves": "thief",
        ]

        if let irregular = irregulars[lowercased] {
            // Preserve original casing
            if name.first?.isUppercase == true {
                return irregular.prefix(1).uppercased() + irregular.dropFirst()
            }
            return irregular
        }

        // Regex-like rules (applied in order)

        // -ves -> -f (scarves -> scarf, but not all)
        if lowercased.hasSuffix("ves") && name.count > 4 {
            let stem = String(name.dropLast(3))
            return stem + "f"
        }

        // -ies -> -y (categories -> category, but not "series", "species")
        if lowercased.hasSuffix("ies") && name.count > 3 {
            // Check if preceded by vowel (stays as -ie: movies->movie is wrong, should stay)
            let beforeIes = name.dropLast(3)
            if let lastChar = beforeIes.last, !"aeiou".contains(lastChar.lowercased()) {
                return String(beforeIes) + "y"
            }
        }

        // -oes -> -o (heroes -> hero, potatoes -> potato)
        if lowercased.hasSuffix("oes") && name.count > 3 {
            return String(name.dropLast(2))
        }

        // -ses, -xes, -zes, -ches, -shes -> drop -es
        if name.count > 3 {
            let suffixes = ["sses", "xes", "zes", "ches", "shes"]
            for suffix in suffixes {
                if lowercased.hasSuffix(suffix) {
                    return String(name.dropLast(2))
                }
            }
        }

        // -us (status -> status, not statuse; already handled by removing trailing s)
        // -is (analysis already in irregulars)

        // Default: remove trailing -s
        if lowercased.hasSuffix("s") && !lowercased.hasSuffix("ss") && name.count > 1 {
            return String(name.dropLast())
        }

        return name
    }
}

struct CodeBlockView: View {
    let code: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Swift")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    #else
                    UIPasteboard.general.string = code
                    #endif
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))

            ScrollView(.horizontal, showsIndicators: false) {
                highlightedCode
                    .font(.system(.caption, design: .monospaced))
                    .padding(12)
            }
        }
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var highlightedCode: Text {
        var result = AttributedString()

        let lines = code.components(separatedBy: "\n")
        for (lineIndex, line) in lines.enumerated() {
            if lineIndex > 0 {
                result.append(AttributedString("\n"))
            }

            // Check if it's a comment line
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") {
                var comment = AttributedString(line)
                comment.foregroundColor = SwiftSyntaxColors.comment
                result.append(comment)
                continue
            }

            // Process the line token by token
            var remaining = line[...]
            while !remaining.isEmpty {
                if let match = remaining.firstMatch(of: SwiftSyntaxPatterns.token) {
                    // Add any text before the match
                    if match.range.lowerBound > remaining.startIndex {
                        let before = String(remaining[remaining.startIndex..<match.range.lowerBound])
                        var beforeAttr = AttributedString(before)
                        beforeAttr.foregroundColor = .white
                        result.append(beforeAttr)
                    }

                    let token = String(match.output)
                    let color = colorForToken(token)
                    var tokenAttr = AttributedString(token)
                    tokenAttr.foregroundColor = color
                    result.append(tokenAttr)

                    remaining = remaining[match.range.upperBound...]
                } else {
                    var remainingAttr = AttributedString(String(remaining))
                    remainingAttr.foregroundColor = .white
                    result.append(remainingAttr)
                    break
                }
            }
        }

        return Text(result)
    }

    private func colorForToken(_ token: String) -> Color {
        // Keywords
        if SwiftSyntaxColors.keywords.contains(token) {
            return SwiftSyntaxColors.keyword
        }

        // Types (starts with uppercase)
        if let first = token.first, first.isUppercase, first.isLetter {
            return SwiftSyntaxColors.type
        }

        // Strings
        if token.hasPrefix("\"") {
            return SwiftSyntaxColors.string
        }

        // Numbers
        if token.first?.isNumber == true {
            return SwiftSyntaxColors.number
        }

        // Dots and punctuation
        if token == "." || token == "," || token == ":" || token == "(" || token == ")" ||
           token == "[" || token == "]" || token == "{" || token == "}" {
            return .white
        }

        return .white
    }
}

private enum SwiftSyntaxColors {
    static let keyword = Color(red: 0.988, green: 0.376, blue: 0.639)  // Pink
    static let type = Color(red: 0.596, green: 0.855, blue: 0.945)     // Light blue
    static let string = Color(red: 0.988, green: 0.416, blue: 0.365)   // Red/orange
    static let number = Color(red: 0.816, green: 0.749, blue: 0.412)   // Yellow
    static let comment = Color(red: 0.424, green: 0.475, blue: 0.529)  // Gray

    static let keywords: Set<String> = [
        "import", "let", "var", "func", "struct", "class", "enum", "protocol",
        "extension", "if", "else", "for", "while", "return", "try", "await",
        "async", "throw", "throws", "catch", "do", "guard", "switch", "case",
        "default", "break", "continue", "static", "self", "Self", "nil", "true", "false"
    ]
}

private enum SwiftSyntaxPatterns {
    // Match strings, keywords, identifiers, numbers, and punctuation
    static let token = /\"[^\"]*\"|[a-zA-Z_][a-zA-Z0-9_]*|\d+\.?\d*|[.,:;\(\)\[\]\{\}=<>!&|+\-*\/]/
}

struct QueryParam: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let description: String
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
        case .primaryKey:
            return .yellow
        case .geoPoint:
            return .teal
        case .unknown:
            return .secondary
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

    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 60

    var body: some View {
        HStack(alignment: .top) {
            Text(name)
                .frame(minWidth: labelWidth, alignment: .leading)
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
