//
//  CollectionEditorView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct CollectionEditorView: View {
    let collection: CollectionModel?
    let onSave: (CollectionModel) -> Void

    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: CollectionModelType = .base
    @State private var fields: [EditableField] = []
    @State private var listRule: String = ""
    @State private var viewRule: String = ""
    @State private var createRule: String = ""
    @State private var updateRule: String = ""
    @State private var deleteRule: String = ""

    // Auth collection email templates
    @State private var verificationSubject: String = ""
    @State private var verificationBody: String = ""
    @State private var resetPasswordSubject: String = ""
    @State private var resetPasswordBody: String = ""
    @State private var confirmEmailChangeSubject: String = ""
    @State private var confirmEmailChangeBody: String = ""
    @State private var authAlertEnabled: Bool = false
    @State private var authAlertSubject: String = ""
    @State private var authAlertBody: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showFieldEditor = false
    @State private var editingFieldIndex: Int?

    private var isEditing: Bool { collection != nil }
    private var isSystemCollection: Bool { collection?.system ?? false }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextField("Name", text: $name, prompt: Text("posts"))
                        .disabled(isSystemCollection)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif

                    Picker("Type", selection: $type) {
                        Label("Base", systemImage: "rectangle.stack").tag(CollectionModelType.base)
                        Label("Auth", systemImage: "person.badge.key").tag(CollectionModelType.auth)
                        Label("View", systemImage: "eye").tag(CollectionModelType.view)
                    }
                    .disabled(isEditing)
                }

                Section("Schema") {
                    if fields.isEmpty {
                        Text("No fields yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fields.indices, id: \.self) { index in
                            FieldRow(field: fields[index]) {
                                editingFieldIndex = index
                                showFieldEditor = true
                            }
                            .disabled(fields[index].system)
                        }
                        .onDelete { indexSet in
                            let indicesToDelete = indexSet.filter { !fields[$0].system }
                            fields.remove(atOffsets: IndexSet(indicesToDelete))
                        }
                        .onMove { from, to in
                            fields.move(fromOffsets: from, toOffset: to)
                        }
                    }

                    Button {
                        editingFieldIndex = nil
                        showFieldEditor = true
                    } label: {
                        Label("New Field", systemImage: "plus.circle.fill")
                    }
                }

                Section("API Rules") {
                    RuleEditor(name: "List", rule: $listRule)
                    RuleEditor(name: "View", rule: $viewRule)
                    RuleEditor(name: "Create", rule: $createRule)
                    RuleEditor(name: "Update", rule: $updateRule)
                    RuleEditor(name: "Delete", rule: $deleteRule)
                }

                if type == .auth {
                    Section("Email Templates") {
                        EmailTemplateEditor(
                            title: "Verification",
                            subject: $verificationSubject,
                            bodyText: $verificationBody
                        )
                        EmailTemplateEditor(
                            title: "Password Reset",
                            subject: $resetPasswordSubject,
                            bodyText: $resetPasswordBody
                        )
                        EmailTemplateEditor(
                            title: "Email Change",
                            subject: $confirmEmailChangeSubject,
                            bodyText: $confirmEmailChangeBody
                        )
                    }

                    Section("Security") {
                        Toggle("Auth Alert", isOn: $authAlertEnabled)

                        if authAlertEnabled {
                            EmailTemplateEditor(
                                title: "Alert Email",
                                subject: $authAlertSubject,
                                bodyText: $authAlertBody
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Collection" : "New Collection")
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
                            await saveCollection()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || name.isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .sheet(isPresented: $showFieldEditor) {
                FieldEditorView(
                    field: editingFieldIndex.map { fields[$0] },
                    onSave: { editedField in
                        if let index = editingFieldIndex {
                            fields[index] = editedField
                        } else {
                            fields.append(editedField)
                        }
                    }
                )
            }
        }
        .onAppear {
            initializeFromCollection()
        }
    }

    private func initializeFromCollection() {
        guard let collection else { return }

        name = collection.name
        type = collection.type
        fields = (collection.schema ?? []).map { EditableField(from: $0) }
        listRule = collection.listRule ?? ""
        viewRule = collection.viewRule ?? ""
        createRule = collection.createRule ?? ""
        updateRule = collection.updateRule ?? ""
        deleteRule = collection.deleteRule ?? ""

        // Load email templates for auth collections
        if collection.type == .auth {
            verificationSubject = collection.verificationTemplate?.subject ?? ""
            verificationBody = collection.verificationTemplate?.body ?? ""
            resetPasswordSubject = collection.resetPasswordTemplate?.subject ?? ""
            resetPasswordBody = collection.resetPasswordTemplate?.body ?? ""
            confirmEmailChangeSubject = collection.confirmEmailChangeTemplate?.subject ?? ""
            confirmEmailChangeBody = collection.confirmEmailChangeTemplate?.body ?? ""
            authAlertEnabled = collection.authAlert?.enabled ?? false
            authAlertSubject = collection.authAlert?.emailTemplate?.subject ?? ""
            authAlertBody = collection.authAlert?.emailTemplate?.body ?? ""
        }
    }

    private func saveCollection() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let schemaFields = fields.map { $0.toField() }

        // Build email templates for auth collections
        let verification: EmailTemplate? = type == .auth && (!verificationSubject.isEmpty || !verificationBody.isEmpty)
            ? EmailTemplate(subject: verificationSubject, body: verificationBody) : nil
        let resetPassword: EmailTemplate? = type == .auth && (!resetPasswordSubject.isEmpty || !resetPasswordBody.isEmpty)
            ? EmailTemplate(subject: resetPasswordSubject, body: resetPasswordBody) : nil
        let confirmEmailChange: EmailTemplate? = type == .auth && (!confirmEmailChangeSubject.isEmpty || !confirmEmailChangeBody.isEmpty)
            ? EmailTemplate(subject: confirmEmailChangeSubject, body: confirmEmailChangeBody) : nil
        let authAlertConfig: AuthAlertConfig? = type == .auth
            ? AuthAlertConfig(
                enabled: authAlertEnabled,
                emailTemplate: authAlertEnabled && (!authAlertSubject.isEmpty || !authAlertBody.isEmpty)
                    ? EmailTemplate(subject: authAlertSubject, body: authAlertBody) : nil
            ) : nil

        do {
            let savedCollection: CollectionModel

            if let collection {
                // Update existing collection
                let request = CollectionUpdateRequest(
                    name: name,
                    schema: schemaFields,
                    listRule: listRule.isEmpty ? nil : listRule,
                    viewRule: viewRule.isEmpty ? nil : viewRule,
                    createRule: createRule.isEmpty ? nil : createRule,
                    updateRule: updateRule.isEmpty ? nil : updateRule,
                    deleteRule: deleteRule.isEmpty ? nil : deleteRule,
                    verificationTemplate: verification,
                    resetPasswordTemplate: resetPassword,
                    confirmEmailChangeTemplate: confirmEmailChange,
                    authAlert: authAlertConfig
                )
                savedCollection = try await pocketbase.admin.collections.update(id: collection.id, request)
            } else {
                // Create new collection
                let request = CollectionCreateRequest(
                    name: name,
                    type: type,
                    schema: schemaFields,
                    listRule: listRule.isEmpty ? nil : listRule,
                    viewRule: viewRule.isEmpty ? nil : viewRule,
                    createRule: createRule.isEmpty ? nil : createRule,
                    updateRule: updateRule.isEmpty ? nil : updateRule,
                    deleteRule: deleteRule.isEmpty ? nil : deleteRule,
                    verificationTemplate: verification,
                    resetPasswordTemplate: resetPassword,
                    confirmEmailChangeTemplate: confirmEmailChange,
                    authAlert: authAlertConfig
                )
                savedCollection = try await pocketbase.admin.collections.create(request)
            }

            onSave(savedCollection)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Mutable version of Field for editing purposes
struct EditableField: Identifiable {
    var id: String
    var name: String
    var type: FieldType
    var system: Bool
    var required: Bool
    var presentable: Bool

    // Options
    var min: Int?
    var max: Int?
    var maxSelect: Int?
    var maxSize: Int?
    var values: [String]
    var collectionId: String?
    var cascadeDelete: Bool
    var mimeTypes: [String]

    init(
        id: String = UUID().uuidString,
        name: String = "",
        type: FieldType = .text,
        system: Bool = false,
        required: Bool = false,
        presentable: Bool = false,
        min: Int? = nil,
        max: Int? = nil,
        maxSelect: Int? = nil,
        maxSize: Int? = nil,
        values: [String] = [],
        collectionId: String? = nil,
        cascadeDelete: Bool = false,
        mimeTypes: [String] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.system = system
        self.required = required
        self.presentable = presentable
        self.min = min
        self.max = max
        self.maxSelect = maxSelect
        self.maxSize = maxSize
        self.values = values
        self.collectionId = collectionId
        self.cascadeDelete = cascadeDelete
        self.mimeTypes = mimeTypes
    }

    init(from field: Field) {
        self.id = field.id
        self.name = field.name
        self.type = field.type
        self.system = field.system
        self.required = field.required ?? false
        self.presentable = field.presentable ?? false
        self.min = field.options?.min
        self.max = field.options?.max
        self.maxSelect = field.options?.maxSelect
        self.maxSize = field.options?.maxSize
        self.values = field.options?.values ?? []
        self.collectionId = field.options?.collectionId
        self.cascadeDelete = field.options?.cascadeDelete ?? false
        self.mimeTypes = field.options?.mimeTypes ?? []
    }

    func toField() -> Field {
        let options: FieldOptions?

        // Only include options if they have values
        if min != nil || max != nil || maxSelect != nil || maxSize != nil ||
            !values.isEmpty || collectionId != nil || cascadeDelete || !mimeTypes.isEmpty {
            options = FieldOptions(
                min: min,
                max: max,
                maxSelect: maxSelect,
                maxSize: maxSize,
                values: values.isEmpty ? nil : values,
                collectionId: collectionId,
                cascadeDelete: cascadeDelete ? true : nil,
                mimeTypes: mimeTypes.isEmpty ? nil : mimeTypes
            )
        } else {
            options = nil
        }

        return Field(
            id: id,
            name: name,
            type: type,
            system: system,
            required: required,
            presentable: presentable,
            options: options
        )
    }
}

struct FieldRow: View {
    let field: EditableField
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(field.name.isEmpty ? "(unnamed)" : field.name)
                            .foregroundStyle(field.name.isEmpty ? .secondary : .primary)
                        if field.required {
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
                    }

                    Text(field.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RuleEditor: View {
    let name: String
    @Binding var rule: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                Spacer()
                Text(rule.isEmpty ? "Public" : "Custom")
                    .font(.caption)
                    .foregroundStyle(rule.isEmpty ? .green : .orange)
            }
            TextField("", text: $rule, prompt: Text("Leave empty for public access"))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            #endif
        }
    }
}

struct EmailTemplateEditor: View {
    let title: String
    @Binding var subject: String
    @Binding var bodyText: String

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Subject", text: $subject)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $bodyText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(subject.isEmpty && bodyText.isEmpty ? "Default" : "Custom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
