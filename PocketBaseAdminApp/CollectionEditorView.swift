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

                Section("Collection Info") {
                    TextField("Name", text: $name)
                        .disabled(isSystemCollection)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif

                    Picker("Type", selection: $type) {
                        Text("Base").tag(CollectionModelType.base)
                        Text("Auth").tag(CollectionModelType.auth)
                        Text("View").tag(CollectionModelType.view)
                    }
                    .disabled(isEditing)
                }

                Section {
                    ForEach(fields.indices, id: \.self) { index in
                        FieldRow(field: fields[index]) {
                            editingFieldIndex = index
                            showFieldEditor = true
                        }
                        .disabled(fields[index].system)
                    }
                    .onDelete { indexSet in
                        // Only delete non-system fields
                        let indicesToDelete = indexSet.filter { !fields[$0].system }
                        fields.remove(atOffsets: IndexSet(indicesToDelete))
                    }
                    .onMove { from, to in
                        fields.move(fromOffsets: from, toOffset: to)
                    }

                    Button("Add Field", systemImage: "plus") {
                        editingFieldIndex = nil
                        showFieldEditor = true
                    }
                } header: {
                    HStack {
                        Text("Fields")
                        Spacer()
                        #if !os(macOS)
                        EditButton()
                        #endif
                    }
                }

                Section {
                    RuleEditor(name: "List", rule: $listRule)
                    RuleEditor(name: "View", rule: $viewRule)
                    RuleEditor(name: "Create", rule: $createRule)
                    RuleEditor(name: "Update", rule: $updateRule)
                    RuleEditor(name: "Delete", rule: $deleteRule)
                } header: {
                    Text("API Rules")
                } footer: {
                    Text("Leave empty for public access. Set to nil/null to lock.")
                }

                if type == .auth {
                    Section {
                        EmailTemplateEditor(
                            title: "Verification Email",
                            subject: $verificationSubject,
                            bodyText: $verificationBody
                        )
                    } header: {
                        Text("Email Templates")
                    } footer: {
                        Text("Placeholders: {APP_NAME}, {APP_URL}, {TOKEN}, {ACTION_URL}")
                    }

                    Section {
                        EmailTemplateEditor(
                            title: "Password Reset",
                            subject: $resetPasswordSubject,
                            bodyText: $resetPasswordBody
                        )
                    }

                    Section {
                        EmailTemplateEditor(
                            title: "Confirm Email Change",
                            subject: $confirmEmailChangeSubject,
                            bodyText: $confirmEmailChangeBody
                        )
                    }

                    Section {
                        Toggle("Enable Auth Alert", isOn: $authAlertEnabled)

                        if authAlertEnabled {
                            EmailTemplateEditor(
                                title: "Login Alert",
                                subject: $authAlertSubject,
                                bodyText: $authAlertBody
                            )
                        }
                    } header: {
                        Text("Auth Alert")
                    } footer: {
                        Text("Send email notifications when users login from a new location.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Collection" : "New Collection")
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
                            await saveCollection()
                        }
                    }
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

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            TextField("Rule expression", text: $rule, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(3...6)
            #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            #endif
        } label: {
            HStack {
                Text(name)
                Spacer()
                if rule.isEmpty {
                    Text("(public)")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("custom")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subject")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Email subject", text: $subject)
                    #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                    #endif
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Body")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $bodyText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Text(title)
                Spacer()
                if subject.isEmpty && bodyText.isEmpty {
                    Text("default")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("custom")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}
