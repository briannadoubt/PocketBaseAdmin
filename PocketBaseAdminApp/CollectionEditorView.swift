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

    @Environment(CollectionsState.self) private var collectionsState

    @State private var name: String = ""
    @State private var type: CollectionModelType = .base
    @State private var fields: [EditableField] = []
    @State private var listRule: RuleAccessState = .locked
    @State private var viewRule: RuleAccessState = .locked
    @State private var createRule: RuleAccessState = .locked
    @State private var updateRule: RuleAccessState = .locked
    @State private var deleteRule: RuleAccessState = .locked

    /// Suggestion provider for API rules autocomplete
    @State private var ruleSuggestionProvider = RuleSuggestionProvider()

    // View collection specific state
    @State private var viewQuery: String = ""

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
    @State private var fieldEditorMode: FieldEditorMode?

    /// Mode for the field editor sheet
    enum FieldEditorMode: Identifiable {
        case new
        case edit(Int, EditableField)

        var id: String {
            switch self {
            case .new: return "new-field"
            case .edit(let index, _): return "edit-\(index)"
            }
        }

        var field: EditableField? {
            switch self {
            case .new: return nil
            case .edit(_, let field): return field
            }
        }

        var index: Int? {
            switch self {
            case .new: return nil
            case .edit(let index, _): return index
            }
        }
    }

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

                // View collections show query editor and rules inline
                if type == .view {
                    Section {
                        ViewQueryEditorView(query: $viewQuery)
                    }

                    Section("API Rules") {
                        RuleEditor(name: "List/Search", rule: $listRule, suggestionProvider: ruleSuggestionProvider)
                        RuleEditor(name: "View", rule: $viewRule, suggestionProvider: ruleSuggestionProvider)
                    }
                } else {
                    // Base and Auth collections show Schema and API Rules sections
                    Section("Schema") {
                        if fields.isEmpty {
                            Text("No fields yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(fields.indices, id: \.self) { index in
                                FieldRow(field: fields[index]) {
                                    fieldEditorMode = .edit(index, fields[index])
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
                            fieldEditorMode = .new
                        } label: {
                            Label("New Field", systemImage: "plus.circle.fill")
                        }
                    }

                    Section("API Rules") {
                        RuleEditor(name: "List", rule: $listRule, suggestionProvider: ruleSuggestionProvider)
                        RuleEditor(name: "View", rule: $viewRule, suggestionProvider: ruleSuggestionProvider)
                        RuleEditor(name: "Create", rule: $createRule, suggestionProvider: ruleSuggestionProvider)
                        RuleEditor(name: "Update", rule: $updateRule, suggestionProvider: ruleSuggestionProvider)
                        RuleEditor(name: "Delete", rule: $deleteRule, suggestionProvider: ruleSuggestionProvider)
                    }
                }

                if type == .auth {
                    Section("Email Templates") {
                        EmailTemplateEditor(
                            title: "Verification",
                            templateType: .verification,
                            subject: $verificationSubject,
                            bodyText: $verificationBody
                        )
                        EmailTemplateEditor(
                            title: "Password Reset",
                            templateType: .resetPassword,
                            subject: $resetPasswordSubject,
                            bodyText: $resetPasswordBody
                        )
                        EmailTemplateEditor(
                            title: "Email Change",
                            templateType: .confirmEmailChange,
                            subject: $confirmEmailChangeSubject,
                            bodyText: $confirmEmailChangeBody
                        )
                    }

                    Section("Security") {
                        Toggle("Auth Alert", isOn: $authAlertEnabled)

                        if authAlertEnabled {
                            EmailTemplateEditor(
                                title: "Alert Email",
                                templateType: .authAlert,
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
            .sheet(item: $fieldEditorMode) { mode in
                FieldEditorView(
                    field: mode.field,
                    onSave: { editedField in
                        if let index = mode.index {
                            fields[index] = editedField
                        } else {
                            fields.append(editedField)
                        }
                    }
                )
            }
        }
        .onAppear {
            if collection == nil {
                // New collection: initialize with system fields for the default type
                fields = EditableField.systemFields(for: type)
            } else {
                initializeFromCollection()
            }
            updateSuggestionProvider()
        }
        .onChange(of: type) { _, newValue in
            // Only update system fields when creating a new collection
            guard !isEditing else { return }
            updateSystemFieldsForType(newValue)

            // Initialize default email templates when switching to auth type
            if newValue == .auth {
                initializeDefaultEmailTemplates()
            }
        }
        .onChange(of: fields) { _, _ in
            updateSuggestionProvider()
        }
    }

    /// Updates the rule suggestion provider with current fields and collections.
    private func updateSuggestionProvider() {
        ruleSuggestionProvider.fields = fields
        ruleSuggestionProvider.collections = collectionsState.collections.map(\.collection)
    }

    /// Updates the system fields when the collection type changes (for new collections only)
    private func updateSystemFieldsForType(_ newType: CollectionModelType) {
        // Preserve user-defined fields
        let userFields = fields.filter { !$0.system }
        // Get new system fields for the selected type
        let newSystemFields = EditableField.systemFields(for: newType)
        // Combine: system fields first, then user fields
        fields = newSystemFields + userFields
    }

    /// Initializes default email templates for new auth collections
    private func initializeDefaultEmailTemplates() {
        // Only set defaults if templates are empty
        if verificationSubject.isEmpty && verificationBody.isEmpty {
            verificationSubject = DefaultEmailTemplates.verificationSubject
            verificationBody = DefaultEmailTemplates.verificationBody
        }
        if resetPasswordSubject.isEmpty && resetPasswordBody.isEmpty {
            resetPasswordSubject = DefaultEmailTemplates.resetPasswordSubject
            resetPasswordBody = DefaultEmailTemplates.resetPasswordBody
        }
        if confirmEmailChangeSubject.isEmpty && confirmEmailChangeBody.isEmpty {
            confirmEmailChangeSubject = DefaultEmailTemplates.confirmEmailChangeSubject
            confirmEmailChangeBody = DefaultEmailTemplates.confirmEmailChangeBody
        }
        if authAlertSubject.isEmpty && authAlertBody.isEmpty {
            authAlertSubject = DefaultEmailTemplates.authAlertSubject
            authAlertBody = DefaultEmailTemplates.authAlertBody
        }
    }

    private func initializeFromCollection() {
        guard let collection else { return }

        name = collection.name
        type = collection.type
        fields = (collection.schema ?? []).map { EditableField(from: $0) }
        listRule = RuleAccessState(from: collection.listRule)
        viewRule = RuleAccessState(from: collection.viewRule)
        createRule = RuleAccessState(from: collection.createRule)
        updateRule = RuleAccessState(from: collection.updateRule)
        deleteRule = RuleAccessState(from: collection.deleteRule)

        // View collections: viewQuery support not yet available in PocketBase library
        // TODO: Add viewQuery loading when library supports it

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

        // Filter out system fields - PocketBase creates these automatically
        let schemaFields = fields.filter { !$0.system }.map { $0.toField() }

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
                    schema: type == .view ? nil : schemaFields,
                    listRule: listRule.apiValue,
                    viewRule: viewRule.apiValue,
                    createRule: type == .view ? nil : createRule.apiValue,
                    updateRule: type == .view ? nil : updateRule.apiValue,
                    deleteRule: type == .view ? nil : deleteRule.apiValue,
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
                    schema: type == .view ? nil : schemaFields,
                    listRule: listRule.apiValue,
                    viewRule: viewRule.apiValue,
                    createRule: type == .view ? nil : createRule.apiValue,
                    updateRule: type == .view ? nil : updateRule.apiValue,
                    deleteRule: type == .view ? nil : deleteRule.apiValue,
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
            // Log the full error for debugging
            print("Collection save error: \(error)")
            print("Error type: \(Swift.type(of: error))")
            if let networkError = error as? NetworkError {
                print("Network error details: \(networkError)")
            }
            errorMessage = error.localizedDescription
        }
    }
}

/// Mutable version of Field for editing purposes
struct EditableField: Identifiable, Equatable {
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
    // Autodate options
    var onCreate: Bool
    var onUpdate: Bool

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
        mimeTypes: [String] = [],
        onCreate: Bool = false,
        onUpdate: Bool = false
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
        self.onCreate = onCreate
        self.onUpdate = onUpdate
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
        self.onCreate = field.options?.onCreate ?? false
        self.onUpdate = field.options?.onUpdate ?? false
    }

    func toField() -> Field {
        let options: FieldOptions?

        // For autodate fields, onCreate/onUpdate are required
        let needsAutodateOptions = type == .autodate && (onCreate || onUpdate)

        // Only include options if they have values
        if min != nil || max != nil || maxSelect != nil || maxSize != nil ||
            !values.isEmpty || collectionId != nil || cascadeDelete || !mimeTypes.isEmpty || needsAutodateOptions {
            options = FieldOptions(
                min: min,
                max: max,
                maxSelect: maxSelect,
                maxSize: maxSize,
                values: values.isEmpty ? nil : values,
                collectionId: collectionId,
                cascadeDelete: cascadeDelete ? true : nil,
                mimeTypes: mimeTypes.isEmpty ? nil : mimeTypes,
                onCreate: onCreate ? true : nil,
                onUpdate: onUpdate ? true : nil
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

    /// Returns the system fields for a given collection type.
    /// These are fields automatically created by PocketBase.
    static func systemFields(for type: CollectionModelType) -> [EditableField] {
        switch type {
        case .base:
            return baseSystemFields
        case .auth:
            return baseSystemFields + authSystemFields
        case .view:
            // View collections derive fields from query, no editable system fields
            return []
        }
    }

    /// System fields common to base and auth collections
    private static var baseSystemFields: [EditableField] {
        [
            EditableField(
                id: "_pb_id_field_",
                name: "id",
                type: .primaryKey,
                system: true,
                required: true,
                presentable: false
            ),
            EditableField(
                id: "_pb_created_field_",
                name: "created",
                type: .autodate,
                system: true,
                required: false,
                presentable: false,
                onCreate: true,
                onUpdate: false
            ),
            EditableField(
                id: "_pb_updated_field_",
                name: "updated",
                type: .autodate,
                system: true,
                required: false,
                presentable: false,
                onCreate: true,
                onUpdate: true
            )
        ]
    }

    /// Additional system fields for auth collections
    private static var authSystemFields: [EditableField] {
        [
            EditableField(
                id: "_pb_username_field_",
                name: "username",
                type: .text,
                system: true,
                required: true,
                presentable: true
            ),
            EditableField(
                id: "_pb_email_field_",
                name: "email",
                type: .email,
                system: true,
                required: false,
                presentable: false
            ),
            EditableField(
                id: "_pb_verified_field_",
                name: "verified",
                type: .bool,
                system: true,
                required: false,
                presentable: false
            ),
            EditableField(
                id: "_pb_emailVisibility_field_",
                name: "emailVisibility",
                type: .bool,
                system: true,
                required: false,
                presentable: false
            ),
            EditableField(
                id: "_pb_password_field_",
                name: "password",
                type: .password,
                system: true,
                required: true,
                presentable: false
            )
        ]
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
