//
//  RuleEditor.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBaseAdmin

/// A view for editing a single API rule with lock/unlock toggle and autocomplete.
struct RuleEditor: View {
    let name: String
    @Binding var rule: RuleAccessState
    let suggestionProvider: RuleSuggestionProvider

    @State private var ruleText: String = ""
    @State private var showSuggestions = false
    @State private var suggestions: [RuleSuggestion] = []
    @State private var selectedSuggestionIndex: Int?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with name, status badge, and lock toggle
            HStack {
                Text(name)
                    .fontWeight(.medium)

                Spacer()

                statusBadge
                lockToggleButton
            }

            // Rule input (only shown when unlocked)
            if !rule.isLocked {
                ruleInputArea
            }
        }
        .onAppear {
            // Initialize ruleText from the rule state
            ruleText = rule.ruleText
        }
        .onChange(of: rule) { _, newValue in
            // Sync ruleText when rule changes externally
            if newValue.ruleText != ruleText {
                ruleText = newValue.ruleText
            }
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text(rule.statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statusColor: Color {
        switch rule {
        case .locked:
            return .red
        case .publicAccess:
            return .green
        case .custom:
            return .orange
        }
    }

    // MARK: - Lock Toggle Button

    private var lockToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                toggleLockState()
            }
        } label: {
            Image(systemName: rule.isLocked ? "lock.fill" : "lock.open")
                .font(.body)
                .foregroundStyle(rule.isLocked ? .red : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(rule.isLocked ? "Unlock to allow custom rule" : "Lock to restrict to admin only")
    }

    private func toggleLockState() {
        switch rule {
        case .locked:
            // Unlock defaults to public access
            rule = .publicAccess
            ruleText = ""
        case .publicAccess, .custom:
            // Lock resets to admin only
            rule = .locked
            ruleText = ""
            showSuggestions = false
        }
    }

    // MARK: - Rule Input Area

    private var ruleInputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("", text: $ruleText, prompt: Text("Leave empty for public access"))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .focused($isTextFieldFocused)
                .onChange(of: ruleText) { _, newValue in
                    updateRuleFromText(newValue)
                    updateSuggestions(for: newValue)
                }
                .onChange(of: isTextFieldFocused) { _, focused in
                    if focused && !ruleText.isEmpty {
                        updateSuggestions(for: ruleText)
                    } else if !focused {
                        // Delay hiding to allow click on suggestion
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if !isTextFieldFocused {
                                showSuggestions = false
                            }
                        }
                    }
                }
                #if os(macOS)
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.return) {
                    if let index = selectedSuggestionIndex, index < suggestions.count {
                        selectSuggestion(suggestions[index])
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    showSuggestions = false
                    return .handled
                }
                #endif

            // Suggestions overlay
            if showSuggestions && !suggestions.isEmpty {
                SuggestionsView(
                    suggestions: suggestions,
                    onSelect: selectSuggestion,
                    selectedIndex: $selectedSuggestionIndex
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showSuggestions)
    }

    // MARK: - Helpers

    private func updateRuleFromText(_ text: String) {
        if text.isEmpty {
            rule = .publicAccess
        } else {
            rule = .custom(text)
        }
    }

    private func updateSuggestions(for text: String) {
        suggestions = suggestionProvider.suggestions(for: text)
        showSuggestions = !suggestions.isEmpty && isTextFieldFocused
        selectedSuggestionIndex = suggestions.isEmpty ? nil : 0
    }

    private func moveSelection(by offset: Int) {
        guard !suggestions.isEmpty else { return }
        let current = selectedSuggestionIndex ?? 0
        let newIndex = (current + offset + suggestions.count) % suggestions.count
        selectedSuggestionIndex = newIndex
    }

    private func selectSuggestion(_ suggestion: RuleSuggestion) {
        // Replace the current token with the suggestion
        let currentToken = extractCurrentToken(from: ruleText)

        if currentToken.isEmpty {
            ruleText += suggestion.text
        } else {
            // Find the last occurrence of the current token and replace it
            if let range = ruleText.range(of: currentToken, options: .backwards) {
                ruleText.replaceSubrange(range, with: suggestion.text)
            } else {
                ruleText += suggestion.text
            }
        }

        updateRuleFromText(ruleText)
        showSuggestions = false
    }

    private func extractCurrentToken(from text: String) -> String {
        let separators = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "()"))
        let components = text.components(separatedBy: separators)
        return components.last ?? ""
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var rule: RuleAccessState = .locked
        @State private var provider = RuleSuggestionProvider()

        var body: some View {
            Form {
                Section("API Rules") {
                    RuleEditor(name: "List", rule: $rule, suggestionProvider: provider)
                }
            }
            .frame(width: 500, height: 400)
        }
    }

    return PreviewWrapper()
}
