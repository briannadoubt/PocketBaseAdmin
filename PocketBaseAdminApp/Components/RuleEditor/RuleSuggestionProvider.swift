//
//  RuleSuggestionProvider.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import PocketBaseAdmin

/// Provides autocomplete suggestions for PocketBase API rules.
@Observable
@MainActor
final class RuleSuggestionProvider {
    /// The fields of the current collection (for field name suggestions).
    var fields: [EditableField] = []

    /// All available collections (for relation traversal suggestions).
    var collections: [CollectionModel] = []

    init(fields: [EditableField] = [], collections: [CollectionModel] = []) {
        self.fields = fields
        self.collections = collections
    }

    /// Generate suggestions based on the current input text and cursor position.
    /// - Parameters:
    ///   - text: The current rule text
    ///   - cursorPosition: The cursor position in the text (defaults to end)
    /// - Returns: Array of matching suggestions
    func suggestions(for text: String, cursorPosition: Int? = nil) -> [RuleSuggestion] {
        let position = cursorPosition ?? text.count
        let prefix = extractCurrentToken(from: text, at: position)

        var allSuggestions: [RuleSuggestion] = []

        // Add static suggestions based on context
        if prefix.isEmpty || prefix.hasPrefix("@") {
            allSuggestions.append(contentsOf: RuleSuggestion.authSuggestions)
            allSuggestions.append(RuleSuggestion.bodyBaseSuggestion)
            allSuggestions.append(contentsOf: RuleSuggestion.requestOtherSuggestions)
            allSuggestions.append(contentsOf: RuleSuggestion.macroSuggestions)
        }

        // Add field-specific @request.body.* suggestions
        if prefix.isEmpty || prefix.hasPrefix("@request.body") {
            allSuggestions.append(contentsOf: bodyFieldSuggestions())
        }

        // Add collection field suggestions
        if prefix.isEmpty || !prefix.hasPrefix("@") {
            allSuggestions.append(contentsOf: fieldSuggestions())
        }

        // Add operator and modifier suggestions
        allSuggestions.append(contentsOf: RuleSuggestion.operatorSuggestions)
        allSuggestions.append(contentsOf: RuleSuggestion.modifierSuggestions)
        allSuggestions.append(contentsOf: RuleSuggestion.functionSuggestions)

        // Filter by prefix match
        let filtered = allSuggestions.filter { suggestion in
            prefix.isEmpty ||
            suggestion.text.localizedCaseInsensitiveContains(prefix) ||
            suggestion.displayText.localizedCaseInsensitiveContains(prefix)
        }

        // Remove duplicates and sort
        let unique = Array(Set(filtered))
        return unique.sorted { $0.text < $1.text }
    }

    /// Extract the current token being typed at the given cursor position.
    private func extractCurrentToken(from text: String, at position: Int) -> String {
        guard position > 0, position <= text.count else { return "" }

        let beforeCursor = String(text.prefix(position))
        let separators = CharacterSet.whitespaces
            .union(CharacterSet(charactersIn: "()"))

        // Split by separators and get the last component
        let components = beforeCursor.components(separatedBy: separators)
        return components.last ?? ""
    }

    /// Generate @request.body.* suggestions for collection fields.
    private func bodyFieldSuggestions() -> [RuleSuggestion] {
        fields.compactMap { field in
            guard !field.system else { return nil }
            return RuleSuggestion(
                text: "@request.body.\(field.name)",
                category: .requestBody,
                description: "Submitted \(field.name) value (\(field.type.rawValue))"
            )
        }
    }

    /// Generate field name suggestions from the collection schema.
    private func fieldSuggestions() -> [RuleSuggestion] {
        var suggestions: [RuleSuggestion] = []

        for field in fields {
            // Direct field reference
            suggestions.append(RuleSuggestion(
                text: field.name,
                category: .field,
                description: "Field (\(field.type.rawValue))"
            ))

            // For relation fields, add traversal suggestions
            if field.type == .relation, let collectionId = field.collectionId {
                suggestions.append(contentsOf: relationFieldSuggestions(
                    fieldName: field.name,
                    targetCollectionId: collectionId
                ))
            }
        }

        return suggestions
    }

    /// Generate suggestions for traversing relation fields.
    private func relationFieldSuggestions(fieldName: String, targetCollectionId: String) -> [RuleSuggestion] {
        // Find the target collection
        guard let targetCollection = collections.first(where: {
            $0.id == targetCollectionId || $0.name == targetCollectionId
        }) else {
            return []
        }

        // Generate suggestions for each field in the target collection
        return (targetCollection.fields ?? []).map { targetField in
            RuleSuggestion(
                text: "\(fieldName).\(targetField.name)",
                category: .relation,
                description: "Related \(targetField.name) via \(fieldName) (\(targetField.type.rawValue))"
            )
        }
    }
}
