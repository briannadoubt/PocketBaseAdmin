//
//  RuleAccessState.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation

/// Represents the access state for a PocketBase API rule.
///
/// PocketBase API rules have three states:
/// - `nil` = Admin only (locked)
/// - `""` (empty string) = Public access
/// - `"rule"` = Custom rule expression
enum RuleAccessState: Equatable, Hashable {
    /// Admin only - no public access, only accessible via admin API.
    /// Sends `nil` to the PocketBase API.
    case locked

    /// Public access - anyone can access without authentication.
    /// Sends empty string `""` to the PocketBase API.
    case publicAccess

    /// Custom rule expression for fine-grained access control.
    /// Sends the rule string to the PocketBase API.
    case custom(String)

    /// The value to send to the PocketBase API.
    var apiValue: String? {
        switch self {
        case .locked:
            return nil
        case .publicAccess:
            return ""
        case .custom(let rule):
            return rule.isEmpty ? "" : rule
        }
    }

    /// Initialize from an API response value.
    /// - Parameter apiValue: The rule value from the API (nil, empty string, or rule expression)
    init(from apiValue: String?) {
        switch apiValue {
        case nil:
            self = .locked
        case "":
            self = .publicAccess
        case let rule?:
            self = .custom(rule)
        }
    }

    /// Whether this rule is in the locked (admin-only) state.
    var isLocked: Bool {
        if case .locked = self {
            return true
        }
        return false
    }

    /// The display text for the current state.
    var statusText: String {
        switch self {
        case .locked:
            return "Admin Only"
        case .publicAccess:
            return "Public"
        case .custom:
            return "Custom"
        }
    }

    /// The rule text if custom, otherwise empty string.
    var ruleText: String {
        switch self {
        case .locked, .publicAccess:
            return ""
        case .custom(let rule):
            return rule
        }
    }
}
