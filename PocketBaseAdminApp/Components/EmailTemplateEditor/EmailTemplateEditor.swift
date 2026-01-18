//
//  EmailTemplateEditor.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// A view for editing email templates with variable autocomplete.
struct EmailTemplateEditor: View {
    let title: String
    let templateType: EmailTemplateSuggestion.EmailTemplateType
    @Binding var subject: String
    @Binding var bodyText: String

    @State private var isExpanded = false
    @State private var showSubjectSuggestions = false
    @State private var showBodySuggestions = false
    @State private var selectedSuggestionIndex: Int? = 0
    @FocusState private var subjectFocused: Bool
    @FocusState private var bodyFocused: Bool

    private var suggestions: [EmailTemplateSuggestion] {
        EmailTemplateSuggestion.suggestions(for: templateType)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // Subject field with autocomplete
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subject")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Subject", text: $subject)
                        .textFieldStyle(.roundedBorder)
                        .focused($subjectFocused)
                        .onChange(of: subject) { _, newValue in
                            showSubjectSuggestions = shouldShowSuggestions(for: newValue) && subjectFocused
                        }
                        .onChange(of: subjectFocused) { _, focused in
                            if !focused {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showSubjectSuggestions = false
                                }
                            }
                        }

                    if showSubjectSuggestions {
                        suggestionsList { suggestion in
                            insertSuggestion(suggestion, into: $subject)
                            showSubjectSuggestions = false
                        }
                    }
                }

                // Body field with autocomplete
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $bodyText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .focused($bodyFocused)
                        .onChange(of: bodyText) { _, newValue in
                            showBodySuggestions = shouldShowSuggestions(for: newValue) && bodyFocused
                        }
                        .onChange(of: bodyFocused) { _, focused in
                            if !focused {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showBodySuggestions = false
                                }
                            }
                        }

                    if showBodySuggestions {
                        suggestionsList { suggestion in
                            insertSuggestion(suggestion, into: $bodyText)
                            showBodySuggestions = false
                        }
                    }
                }

                // Available variables help
                availableVariablesHelp
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

    // MARK: - Suggestions List

    private func suggestionsList(onSelect: @escaping (EmailTemplateSuggestion) -> Void) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack {
                            Text(suggestion.text)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(suggestion.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 150)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    // MARK: - Available Variables Help

    private var availableVariablesHelp: some View {
        DisclosureGroup("Available variables") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(suggestions) { suggestion in
                    HStack(alignment: .top) {
                        Text(suggestion.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(suggestion.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private func shouldShowSuggestions(for text: String) -> Bool {
        // Show suggestions when user types "{"
        guard let lastBrace = text.lastIndex(of: "{") else { return false }
        let afterBrace = text[lastBrace...]
        // Don't show if there's already a closing brace
        return !afterBrace.contains("}")
    }

    private func insertSuggestion(_ suggestion: EmailTemplateSuggestion, into binding: Binding<String>) {
        var text = binding.wrappedValue

        // Find the last incomplete variable (after last "{" without "}")
        if let lastBrace = text.lastIndex(of: "{") {
            let afterBrace = text[lastBrace...]
            if !afterBrace.contains("}") {
                // Remove the incomplete part and insert the suggestion
                text = String(text[..<lastBrace]) + suggestion.text
            } else {
                // Just append
                text += suggestion.text
            }
        } else {
            text += suggestion.text
        }

        binding.wrappedValue = text
    }
}

// MARK: - Legacy Compatibility

/// Legacy EmailTemplateEditor without template type (for backwards compatibility)
extension EmailTemplateEditor {
    init(title: String, subject: Binding<String>, bodyText: Binding<String>) {
        self.title = title
        self.templateType = .verification // Default
        self._subject = subject
        self._bodyText = bodyText
    }
}

#Preview {
    Form {
        EmailTemplateEditor(
            title: "Verification",
            templateType: .verification,
            subject: .constant("Verify your {APP_NAME} email"),
            bodyText: .constant("Hello,\n\nClick the link below:\n{ACTION_URL}")
        )
    }
    .frame(width: 500, height: 600)
}
