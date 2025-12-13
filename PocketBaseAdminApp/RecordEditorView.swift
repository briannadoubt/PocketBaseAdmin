//
//  RecordEditorView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

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
                            value: binding(for: field.name)
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
            // File upload - placeholder for now
            Text("File upload not yet supported")
                .foregroundStyle(.secondary)
        case .relation:
            // Relation picker - placeholder for now
            TextField("Record ID", text: stringBinding)
                .help("Enter the related record ID")
        case .customEmail:
            TextField(field.name, text: stringBinding)
            #if os(iOS)
                .keyboardType(.emailAddress)
            #endif
        }
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
