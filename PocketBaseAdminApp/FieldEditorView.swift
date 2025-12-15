//
//  FieldEditorView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct FieldEditorView: View {
    let field: EditableField?
    let onSave: (EditableField) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: FieldType = .text
    @State private var required: Bool = false
    @State private var presentable: Bool = false

    // Type-specific options
    @State private var min: String = ""
    @State private var max: String = ""
    @State private var maxSelect: String = ""
    @State private var maxSize: String = ""
    @State private var selectValues: String = ""
    @State private var collectionId: String = ""
    @State private var cascadeDelete: Bool = false
    @State private var mimeTypes: String = ""

    private var isEditing: Bool { field != nil }
    private var isSystemField: Bool { field?.system ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section("Field Info") {
                    TextField("Name", text: $name)
                        .disabled(isSystemField)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif

                    Picker("Type", selection: $type) {
                        ForEach(FieldType.allCases, id: \.self) { fieldType in
                            Text(fieldType.displayName).tag(fieldType)
                        }
                    }
                    .disabled(isEditing)

                    Toggle("Required", isOn: $required)
                    Toggle("Presentable", isOn: $presentable)
                }

                // Type-specific options
                switch type {
                case .text, .editor, .password:
                    Section("Text Options") {
                        numberField("Min length", text: $min)
                        numberField("Max length", text: $max)
                    }

                case .number:
                    Section("Number Options") {
                        numberField("Min value", text: $min)
                        numberField("Max value", text: $max)
                    }

                case .select:
                    Section {
                        TextField("Values (comma separated)", text: $selectValues, axis: .vertical)
                            .lineLimit(2...4)
                        numberField("Max select", text: $maxSelect)
                    } header: {
                        Text("Select Options")
                    } footer: {
                        Text("Enter values separated by commas, e.g.: option1, option2, option3")
                    }

                case .file:
                    Section {
                        numberField("Max select", text: $maxSelect)
                        numberField("Max size (bytes)", text: $maxSize)
                        TextField("MIME types (comma separated)", text: $mimeTypes, axis: .vertical)
                            .lineLimit(2...4)
                    } header: {
                        Text("File Options")
                    } footer: {
                        Text("Leave MIME types empty to allow all file types")
                    }

                case .relation:
                    Section("Relation Options") {
                        TextField("Collection ID", text: $collectionId)
                        numberField("Max select", text: $maxSelect)
                        Toggle("Cascade Delete", isOn: $cascadeDelete)
                    }

                case .email, .customEmail, .url, .bool, .date, .dateTime, .autodate, .json, .primaryKey, .geoPoint, .unknown:
                    EmptyView()
                }
            }
            .navigationTitle(isEditing ? "Edit Field" : "New Field")
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
                    Button(isEditing ? "Save" : "Add") {
                        saveField()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            initializeFromField()
        }
    }

    @ViewBuilder
    private func numberField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
        #if os(iOS)
            .keyboardType(.numberPad)
        #endif
    }

    private func initializeFromField() {
        guard let field else { return }

        name = field.name
        type = field.type
        required = field.required
        presentable = field.presentable

        if let minVal = field.min {
            min = String(minVal)
        }
        if let maxVal = field.max {
            max = String(maxVal)
        }
        if let maxSelectVal = field.maxSelect {
            maxSelect = String(maxSelectVal)
        }
        if let maxSizeVal = field.maxSize {
            maxSize = String(maxSizeVal)
        }
        selectValues = field.values.joined(separator: ", ")
        collectionId = field.collectionId ?? ""
        cascadeDelete = field.cascadeDelete
        mimeTypes = field.mimeTypes.joined(separator: ", ")
    }

    private func saveField() {
        let editableField = EditableField(
            id: field?.id ?? UUID().uuidString,
            name: name,
            type: type,
            system: field?.system ?? false,
            required: required,
            presentable: presentable,
            min: Int(min),
            max: Int(max),
            maxSelect: Int(maxSelect),
            maxSize: Int(maxSize),
            values: parseCommaSeparated(selectValues),
            collectionId: collectionId.isEmpty ? nil : collectionId,
            cascadeDelete: cascadeDelete,
            mimeTypes: parseCommaSeparated(mimeTypes)
        )

        onSave(editableField)
        dismiss()
    }

    private func parseCommaSeparated(_ input: String) -> [String] {
        input.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

extension FieldType: @retroactive CaseIterable {
    public static var allCases: [FieldType] {
        [.text, .editor, .number, .bool, .email, .url, .date, .dateTime, .select, .json, .file, .relation, .password]
    }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .editor: return "Editor"
        case .number: return "Number"
        case .bool: return "Bool"
        case .email: return "Email"
        case .url: return "URL"
        case .date: return "Date"
        case .dateTime: return "DateTime"
        case .autodate: return "Autodate"
        case .select: return "Select"
        case .json: return "JSON"
        case .file: return "File"
        case .relation: return "Relation"
        case .password: return "Password"
        case .customEmail: return "Custom Email"
        case .primaryKey: return "Primary Key"
        case .geoPoint: return "Geo Point"
        case .unknown(let value): return value.capitalized
        }
    }
}
