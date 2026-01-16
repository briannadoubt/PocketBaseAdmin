//
//  RuleSuggestion.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// A suggestion for autocomplete in the rule editor.
struct RuleSuggestion: Identifiable, Hashable {
    let id = UUID()
    /// The text to insert when this suggestion is selected.
    let text: String
    /// The text to display in the suggestion list.
    let displayText: String
    /// The category of this suggestion (for grouping and styling).
    let category: Category
    /// Optional description/help text.
    let description: String?

    /// Categories for rule suggestions.
    enum Category: String, CaseIterable, Hashable {
        case requestAuth = "@request.auth"
        case requestBody = "@request.body"
        case requestQuery = "@request.query"
        case requestOther = "@request"
        case field = "Field"
        case relation = "Relation"
        case `operator` = "Operator"
        case modifier = "Modifier"
        case macro = "Macro"
        case function = "Function"

        /// The display color for this category.
        var color: Color {
            switch self {
            case .requestAuth: return .blue
            case .requestBody: return .green
            case .requestQuery: return .cyan
            case .requestOther: return .purple
            case .field: return .orange
            case .relation: return .pink
            case .operator: return .gray
            case .modifier: return .indigo
            case .macro: return .teal
            case .function: return .mint
            }
        }
    }

    init(text: String, displayText: String? = nil, category: Category, description: String? = nil) {
        self.text = text
        self.displayText = displayText ?? text
        self.category = category
        self.description = description
    }
}

// MARK: - Static Suggestions

extension RuleSuggestion {
    /// @request.auth.* suggestions
    static let authSuggestions: [RuleSuggestion] = [
        RuleSuggestion(text: "@request.auth.id", category: .requestAuth, description: "Authenticated user ID"),
        RuleSuggestion(text: "@request.auth.email", category: .requestAuth, description: "Authenticated user email"),
        RuleSuggestion(text: "@request.auth.verified", category: .requestAuth, description: "Email verification status"),
        RuleSuggestion(text: "@request.auth.username", category: .requestAuth, description: "Authenticated username"),
        RuleSuggestion(text: "@request.auth.created", category: .requestAuth, description: "Account creation date"),
        RuleSuggestion(text: "@request.auth.updated", category: .requestAuth, description: "Account last update date"),
        RuleSuggestion(text: "@request.auth.collectionId", category: .requestAuth, description: "Auth collection ID"),
        RuleSuggestion(text: "@request.auth.collectionName", category: .requestAuth, description: "Auth collection name"),
    ]

    /// @request.body.* base suggestion
    static let bodyBaseSuggestion = RuleSuggestion(
        text: "@request.body.",
        displayText: "@request.body.*",
        category: .requestBody,
        description: "Submitted form/body data"
    )

    /// @request.* other suggestions
    static let requestOtherSuggestions: [RuleSuggestion] = [
        RuleSuggestion(text: "@request.method", category: .requestOther, description: "HTTP method (GET, POST, etc.)"),
        RuleSuggestion(text: "@request.context", category: .requestOther, description: "Request context (default, oauth2, etc.)"),
        RuleSuggestion(text: "@request.headers.", displayText: "@request.headers.*", category: .requestOther, description: "Request headers"),
        RuleSuggestion(text: "@request.query.", displayText: "@request.query.*", category: .requestQuery, description: "Query parameters"),
    ]

    /// Operator suggestions
    static let operatorSuggestions: [RuleSuggestion] = [
        RuleSuggestion(text: " = ", displayText: "=", category: .operator, description: "Equals"),
        RuleSuggestion(text: " != ", displayText: "!=", category: .operator, description: "Not equals"),
        RuleSuggestion(text: " ~ ", displayText: "~", category: .operator, description: "Like/Contains"),
        RuleSuggestion(text: " !~ ", displayText: "!~", category: .operator, description: "Not like/Contains"),
        RuleSuggestion(text: " > ", displayText: ">", category: .operator, description: "Greater than"),
        RuleSuggestion(text: " >= ", displayText: ">=", category: .operator, description: "Greater or equal"),
        RuleSuggestion(text: " < ", displayText: "<", category: .operator, description: "Less than"),
        RuleSuggestion(text: " <= ", displayText: "<=", category: .operator, description: "Less or equal"),
        RuleSuggestion(text: " && ", displayText: "&&", category: .operator, description: "AND"),
        RuleSuggestion(text: " || ", displayText: "||", category: .operator, description: "OR"),
        RuleSuggestion(text: " ?= ", displayText: "?=", category: .operator, description: "Any equals (for arrays)"),
        RuleSuggestion(text: " ?~ ", displayText: "?~", category: .operator, description: "Any like (for arrays)"),
    ]

    /// Modifier suggestions
    static let modifierSuggestions: [RuleSuggestion] = [
        RuleSuggestion(text: ":isset", category: .modifier, description: "Check if field was submitted"),
        RuleSuggestion(text: ":changed", category: .modifier, description: "Check if field value changed"),
        RuleSuggestion(text: ":length", category: .modifier, description: "Array/string length"),
        RuleSuggestion(text: ":each", category: .modifier, description: "Apply to each array item"),
        RuleSuggestion(text: ":lower", category: .modifier, description: "Case-insensitive comparison"),
    ]

    /// Date/time macro suggestions
    static let macroSuggestions: [RuleSuggestion] = [
        RuleSuggestion(text: "@now", category: .macro, description: "Current datetime"),
        RuleSuggestion(text: "@todayStart", category: .macro, description: "Start of today (00:00:00)"),
        RuleSuggestion(text: "@todayEnd", category: .macro, description: "End of today (23:59:59)"),
        RuleSuggestion(text: "@yesterday", category: .macro, description: "Yesterday's date"),
        RuleSuggestion(text: "@tomorrow", category: .macro, description: "Tomorrow's date"),
        RuleSuggestion(text: "@monthStart", category: .macro, description: "Start of current month"),
        RuleSuggestion(text: "@monthEnd", category: .macro, description: "End of current month"),
        RuleSuggestion(text: "@yearStart", category: .macro, description: "Start of current year"),
        RuleSuggestion(text: "@yearEnd", category: .macro, description: "End of current year"),
    ]

    /// Function suggestions
    static let functionSuggestions: [RuleSuggestion] = [
        RuleSuggestion(
            text: "geoDistance(",
            displayText: "geoDistance(lonA, latA, lonB, latB)",
            category: .function,
            description: "Calculate distance in km between two points"
        ),
    ]

    /// All static suggestions combined
    static var allStaticSuggestions: [RuleSuggestion] {
        authSuggestions +
        [bodyBaseSuggestion] +
        requestOtherSuggestions +
        operatorSuggestions +
        modifierSuggestions +
        macroSuggestions +
        functionSuggestions
    }
}
