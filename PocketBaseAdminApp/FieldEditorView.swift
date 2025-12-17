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
    // Autodate options
    @State private var onCreate: Bool = false
    @State private var onUpdate: Bool = false

    private var isEditing: Bool { field != nil }
    private var isSystemField: Bool { field?.system ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("field_name"))
                        .disabled(isSystemField)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif

                    Picker("Type", selection: $type) {
                        ForEach(FieldType.allCases, id: \.self) { fieldType in
                            Label(fieldType.displayName, systemImage: fieldType.icon)
                                .tag(fieldType)
                        }
                    }
                    .disabled(isEditing)
                }

                Section {
                    Toggle("Required", isOn: $required)
                    Toggle("Presentable", isOn: $presentable)
                }

                // Type-specific options
                switch type {
                case .text, .editor, .password:
                    Section("Validation") {
                        numberField("Min Length", text: $min)
                        numberField("Max Length", text: $max)
                    }

                case .number:
                    Section("Validation") {
                        numberField("Min Value", text: $min)
                        numberField("Max Value", text: $max)
                    }

                case .select:
                    Section("Options") {
                        TextField("Values", text: $selectValues, prompt: Text("option1, option2, option3"), axis: .vertical)
                            .lineLimit(2...4)
                        numberField("Max Selections", text: $maxSelect)
                    }

                case .file:
                    Section("Constraints") {
                        numberField("Max Files", text: $maxSelect)
                        numberField("Max Size (bytes)", text: $maxSize)
                        TextField("MIME Types", text: $mimeTypes, prompt: Text("image/*, application/pdf"), axis: .vertical)
                            .lineLimit(2...4)
                    }

                case .relation:
                    Section("Relation") {
                        TextField("Collection ID", text: $collectionId, prompt: Text("target_collection"))
                        numberField("Max Select", text: $maxSelect)
                        Toggle("Cascade Delete", isOn: $cascadeDelete)
                    }

                case .autodate:
                    Section("Auto-set Date") {
                        Toggle("On Create", isOn: $onCreate)
                        Toggle("On Update", isOn: $onUpdate)
                    }

                case .email, .customEmail, .url, .bool, .date, .dateTime, .json, .primaryKey, .geoPoint:
                    EmptyView()
                case .unknown:
                    EmptyView()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Field" : "New Field")
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
                    .buttonStyle(.borderedProminent)
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
        onCreate = field.onCreate
        onUpdate = field.onUpdate
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
            mimeTypes: parseCommaSeparated(mimeTypes),
            onCreate: onCreate,
            onUpdate: onUpdate
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

    var icon: String {
        switch self {
        case .text: return "textformat"
        case .editor: return "doc.richtext"
        case .number: return "number"
        case .bool: return "checkmark.square"
        case .email: return "envelope"
        case .url: return "link"
        case .date: return "calendar"
        case .dateTime: return "calendar.badge.clock"
        case .autodate: return "clock"
        case .select: return "list.bullet"
        case .json: return "curlybraces"
        case .file: return "doc"
        case .relation: return "arrow.triangle.branch"
        case .password: return "key"
        case .customEmail: return "envelope.badge"
        case .primaryKey: return "key.fill"
        case .geoPoint: return "mappin"
        case .unknown: return "questionmark"
        }
    }
}
