//
//  RecordEditorView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin
import UniformTypeIdentifiers

struct RecordEditorView: View {
    let collection: CollectionModel
    let record: RecordModel?
    let onSave: () async -> Void

    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.dismiss) private var dismiss

    @State private var fieldValues: [String: JSONValue] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { record != nil }

    private var schema: [Field] {
        collection.schema ?? []
    }

    private var editableFields: [Field] {
        schema.filter { !$0.system }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                ForEach(editableFields, id: \.id) { field in
                    Section {
                        FieldEditorRow(
                            field: field,
                            value: binding(for: field.name),
                            pocketbase: pocketbase
                        )
                    } header: {
                        HStack {
                            Text(field.name)
                            if field.required == true {
                                Text("*")
                                    .foregroundStyle(.red)
                            }
                        }
                    } footer: {
                        if let options = field.options {
                            fieldOptionsFooter(field: field, options: options)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Record" : "New Record")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task {
                            await saveRecord()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .onAppear {
            initializeFieldValues()
        }
    }

    private func binding(for fieldName: String) -> Binding<JSONValue> {
        Binding(
            get: { fieldValues[fieldName] ?? .null },
            set: { fieldValues[fieldName] = $0 }
        )
    }

    @ViewBuilder
    private func fieldOptionsFooter(field: Field, options: FieldOptions) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let min = options.min {
                Text("Min: \(min)")
            }
            if let max = options.max {
                Text("Max: \(max)")
            }
            if let maxSize = options.maxSize {
                Text("Max size: \(ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .file))")
            }
            if let values = options.values, !values.isEmpty {
                Text("Options: \(values.joined(separator: ", "))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func initializeFieldValues() {
        if let record {
            // Edit mode: populate with existing values
            fieldValues = record.content
        } else {
            // Create mode: initialize with defaults
            for field in editableFields {
                fieldValues[field.name] = defaultValue(for: field)
            }
        }
    }

    private func defaultValue(for field: Field) -> JSONValue {
        switch field.type {
        case .bool:
            return .bool(false)
        case .number:
            return .int(0)
        case .text, .editor, .email, .url, .password:
            return .string("")
        case .select:
            if let values = field.options?.values, !values.isEmpty {
                return .string(values[0])
            }
            return .string("")
        case .json:
            return .dictionary([:])
        case .date, .dateTime, .autodate:
            return .date(Date())
        case .file, .relation:
            return .null
        case .customEmail:
            return .string("")
        }
    }

    private func saveRecord() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            if let record {
                // Update existing record
                _ = try await pocketbase.admin
                    .records(collection.name)
                    .update(id: record.id, fieldValues)
            } else {
                // Create new record
                _ = try await pocketbase.admin
                    .records(collection.name)
                    .create(fieldValues)
            }

            await onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FieldEditorRow: View {
    let field: Field
    @Binding var value: JSONValue
    var pocketbase: PocketBase?

    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String?

    @State private var showRelationPicker = false

    var body: some View {
        switch field.type {
        case .text:
            TextField(field.name, text: stringBinding)
        case .editor:
            TextEditor(text: stringBinding)
                .frame(minHeight: 100)
        case .number:
            TextField(field.name, value: numberBinding, format: .number)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
        case .bool:
            Toggle(field.name, isOn: boolBinding)
        case .email:
            TextField(field.name, text: stringBinding)
            #if os(iOS)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            #endif
        case .url:
            TextField(field.name, text: stringBinding)
            #if os(iOS)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocapitalization(.none)
            #endif
        case .password:
            SecureField(field.name, text: stringBinding)
        case .date:
            DatePicker(
                field.name,
                selection: dateBinding,
                displayedComponents: .date
            )
        case .dateTime, .autodate:
            DatePicker(
                field.name,
                selection: dateBinding,
                displayedComponents: [.date, .hourAndMinute]
            )
        case .select:
            if let options = field.options?.values, !options.isEmpty {
                Picker(field.name, selection: stringBinding) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } else {
                TextField(field.name, text: stringBinding)
            }
        case .json:
            TextEditor(text: jsonStringBinding)
                .frame(minHeight: 100)
                .font(.system(.body, design: .monospaced))
        case .file:
            FileFieldEditor(
                field: field,
                value: $value,
                showFilePicker: $showFilePicker,
                selectedFileName: $selectedFileName
            )
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: allowedFileTypes,
                allowsMultipleSelection: field.options?.maxSelect ?? 1 > 1
            ) { result in
                handleFileSelection(result)
            }
        case .relation:
            RelationFieldEditor(
                field: field,
                value: $value,
                showRelationPicker: $showRelationPicker,
                pocketbase: pocketbase
            )
            .sheet(isPresented: $showRelationPicker) {
                if let collectionId = field.options?.collectionId, let pocketbase {
                    RelationPickerSheet(
                        collectionId: collectionId,
                        maxSelect: field.options?.maxSelect ?? 1,
                        selectedIds: relationIdsBinding,
                        pocketbase: pocketbase
                    )
                }
            }
        case .customEmail:
            TextField(field.name, text: stringBinding)
            #if os(iOS)
                .keyboardType(.emailAddress)
            #endif
        }
    }

    private var allowedFileTypes: [UTType] {
        guard let mimeTypes = field.options?.mimeTypes, !mimeTypes.isEmpty else {
            return [.data]
        }
        return mimeTypes.compactMap { mimeType in
            UTType(mimeType: mimeType)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                selectedFileURL = url
                selectedFileName = url.lastPathComponent
                value = .string(url.lastPathComponent)
            }
        case .failure:
            break
        }
    }

    private var relationIdsBinding: Binding<[String]> {
        Binding(
            get: {
                switch value {
                case .string(let s) where !s.isEmpty:
                    return [s]
                case .array(let arr):
                    return arr.compactMap { item in
                        if case .string(let s) = item { return s }
                        return nil
                    }
                default:
                    return []
                }
            },
            set: { newIds in
                if field.options?.maxSelect == 1 {
                    value = newIds.first.map { .string($0) } ?? .null
                } else {
                    value = .array(newIds.map { .string($0) })
                }
            }
        )
    }

    // MARK: - Bindings

    private var stringBinding: Binding<String> {
        Binding(
            get: {
                switch value {
                case .string(let s): return s
                case .url(let url): return url.absoluteString
                case .int(let i): return String(i)
                case .double(let d): return String(d)
                default: return ""
                }
            },
            set: { value = .string($0) }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                if case .bool(let b) = value { return b }
                return false
            },
            set: { value = .bool($0) }
        )
    }

    private var numberBinding: Binding<Double> {
        Binding(
            get: {
                switch value {
                case .int(let i): return Double(i)
                case .double(let d): return d
                case .decimal(let d): return NSDecimalNumber(decimal: d).doubleValue
                default: return 0
                }
            },
            set: {
                if $0.truncatingRemainder(dividingBy: 1) == 0 {
                    value = .int(Int($0))
                } else {
                    value = .double($0)
                }
            }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                if case .date(let d) = value { return d }
                return Date()
            },
            set: { value = .date($0) }
        )
    }

    private var jsonStringBinding: Binding<String> {
        Binding(
            get: {
                // Serialize JSONValue to string for editing
                do {
                    let data = try JSONEncoder().encode(value)
                    return String(data: data, encoding: .utf8) ?? "{}"
                } catch {
                    return "{}"
                }
            },
            set: { newString in
                // Try to parse as JSON
                if let data = newString.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode(JSONValue.self, from: data) {
                    value = parsed
                }
            }
        )
    }
}

// MARK: - File Field Editor

struct FileFieldEditor: View {
    let field: Field
    @Binding var value: JSONValue
    @Binding var showFilePicker: Bool
    @Binding var selectedFileName: String?

    private var currentFileName: String? {
        switch value {
        case .string(let s) where !s.isEmpty:
            return s
        case .array(let arr):
            return arr.compactMap { item -> String? in
                if case .string(let s) = item { return s }
                return nil
            }.first
        default:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fileName = selectedFileName ?? currentFileName {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.blue)
                    Text(fileName)
                        .lineLimit(1)
                    Spacer()
                    Button(role: .destructive) {
                        value = .null
                        selectedFileName = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Choose File", systemImage: "folder")
            }
            .buttonStyle(.bordered)

            if let maxSize = field.options?.maxSize {
                Text("Max size: \(ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let mimeTypes = field.options?.mimeTypes, !mimeTypes.isEmpty {
                Text("Allowed: \(mimeTypes.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Relation Field Editor

struct RelationFieldEditor: View {
    let field: Field
    @Binding var value: JSONValue
    @Binding var showRelationPicker: Bool
    var pocketbase: PocketBase?

    private var selectedIds: [String] {
        switch value {
        case .string(let s) where !s.isEmpty:
            return [s]
        case .array(let arr):
            return arr.compactMap { item in
                if case .string(let s) = item { return s }
                return nil
            }
        default:
            return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !selectedIds.isEmpty {
                ForEach(selectedIds, id: \.self) { id in
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.blue)
                        Text(id)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive) {
                            removeRelation(id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
            }

            if pocketbase != nil && field.options?.collectionId != nil {
                Button {
                    showRelationPicker = true
                } label: {
                    Label("Select Record", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
            } else {
                TextField("Record ID", text: manualIdBinding)
                    .font(.system(.body, design: .monospaced))
            }

            if let collectionId = field.options?.collectionId {
                Text("Related to: \(collectionId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var manualIdBinding: Binding<String> {
        Binding(
            get: { selectedIds.first ?? "" },
            set: { newValue in
                if newValue.isEmpty {
                    value = .null
                } else {
                    value = .string(newValue)
                }
            }
        )
    }

    private func removeRelation(_ id: String) {
        var ids = selectedIds
        ids.removeAll { $0 == id }

        if ids.isEmpty {
            value = .null
        } else if field.options?.maxSelect == 1 {
            value = ids.first.map { .string($0) } ?? .null
        } else {
            value = .array(ids.map { .string($0) })
        }
    }
}

// MARK: - Relation Picker Sheet

struct RelationPickerSheet: View {
    let collectionId: String
    let maxSelect: Int
    @Binding var selectedIds: [String]
    let pocketbase: PocketBase

    @State private var records: [RecordModel] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    private var filteredRecords: [RecordModel] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { record in
            record.id.localizedCaseInsensitiveContains(searchText) ||
            record.content.values.contains { value in
                if case .string(let s) = value {
                    return s.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            Task {
                                await loadRecords()
                            }
                        }
                    }
                } else if records.isEmpty {
                    ContentUnavailableView {
                        Label("No Records", systemImage: "tray")
                    } description: {
                        Text("This collection has no records.")
                    }
                } else {
                    List(filteredRecords) { record in
                        RecordSelectionRow(
                            record: record,
                            isSelected: selectedIds.contains(record.id),
                            onToggle: {
                                toggleSelection(record.id)
                            }
                        )
                    }
                    .searchable(text: $searchText, prompt: "Search records")
                }
            }
            .navigationTitle("Select Record")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadRecords()
        }
    }

    private func loadRecords() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await pocketbase.admin.records(collectionId).list(perPage: 100)
            records = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.removeAll { $0 == id }
        } else {
            if maxSelect == 1 {
                selectedIds = [id]
            } else if selectedIds.count < maxSelect {
                selectedIds.append(id)
            }
        }
    }
}

struct RecordSelectionRow: View {
    let record: RecordModel
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.id)
                        .font(.system(.body, design: .monospaced))

                    if let displayValue = primaryDisplayValue {
                        Text(displayValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var primaryDisplayValue: String? {
        // Try common field names for display
        for key in ["name", "title", "email", "username", "label"] {
            if case .string(let s) = record.content[key], !s.isEmpty {
                return s
            }
        }
        return nil
    }
}
