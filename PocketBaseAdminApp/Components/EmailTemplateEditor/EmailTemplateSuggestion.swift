//
//  EmailTemplateSuggestion.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// A suggestion for autocomplete in email template editors.
struct EmailTemplateSuggestion: Identifiable, Hashable {
    let id = UUID()
    /// The variable text to insert (e.g., "{APP_NAME}")
    let text: String
    /// Description of what the variable represents
    let description: String
    /// The template type(s) this variable is available in
    let availableIn: Set<EmailTemplateType>

    enum EmailTemplateType: String, CaseIterable {
        case verification = "Verification"
        case resetPassword = "Password Reset"
        case confirmEmailChange = "Email Change"
        case authAlert = "Auth Alert"
    }
}

// MARK: - Available Variables

extension EmailTemplateSuggestion {
    /// Variables available in all email templates
    static let commonVariables: [EmailTemplateSuggestion] = [
        EmailTemplateSuggestion(
            text: "{APP_NAME}",
            description: "Application name from settings",
            availableIn: Set(EmailTemplateType.allCases)
        ),
        EmailTemplateSuggestion(
            text: "{APP_URL}",
            description: "Application URL from settings",
            availableIn: Set(EmailTemplateType.allCases)
        ),
    ]

    /// Variables for verification, password reset, and email change templates
    static let actionVariables: [EmailTemplateSuggestion] = [
        EmailTemplateSuggestion(
            text: "{TOKEN}",
            description: "Verification/reset token",
            availableIn: [.verification, .resetPassword, .confirmEmailChange]
        ),
        EmailTemplateSuggestion(
            text: "{ACTION_URL}",
            description: "Full action URL with token",
            availableIn: [.verification, .resetPassword, .confirmEmailChange]
        ),
    ]

    /// Variables specific to email change confirmation
    static let emailChangeVariables: [EmailTemplateSuggestion] = [
        EmailTemplateSuggestion(
            text: "{NEW_EMAIL}",
            description: "The new email address to confirm",
            availableIn: [.confirmEmailChange]
        ),
    ]

    /// Variables for accessing record fields
    static let recordVariables: [EmailTemplateSuggestion] = [
        EmailTemplateSuggestion(
            text: "{RECORD:id}",
            description: "User's record ID",
            availableIn: Set(EmailTemplateType.allCases)
        ),
        EmailTemplateSuggestion(
            text: "{RECORD:email}",
            description: "User's email address",
            availableIn: Set(EmailTemplateType.allCases)
        ),
        EmailTemplateSuggestion(
            text: "{RECORD:username}",
            description: "User's username",
            availableIn: Set(EmailTemplateType.allCases)
        ),
        EmailTemplateSuggestion(
            text: "{RECORD:verified}",
            description: "User's verification status",
            availableIn: Set(EmailTemplateType.allCases)
        ),
        EmailTemplateSuggestion(
            text: "{RECORD:created}",
            description: "Record creation timestamp",
            availableIn: Set(EmailTemplateType.allCases)
        ),
    ]

    /// Auth alert specific variables
    static let authAlertVariables: [EmailTemplateSuggestion] = [
        EmailTemplateSuggestion(
            text: "{IP}",
            description: "IP address of the login",
            availableIn: [.authAlert]
        ),
        EmailTemplateSuggestion(
            text: "{USER_AGENT}",
            description: "Browser/client user agent",
            availableIn: [.authAlert]
        ),
        EmailTemplateSuggestion(
            text: "{DEVICE}",
            description: "Device information",
            availableIn: [.authAlert]
        ),
    ]

    /// Get all suggestions for a specific template type
    static func suggestions(for templateType: EmailTemplateType) -> [EmailTemplateSuggestion] {
        var suggestions = commonVariables + recordVariables

        switch templateType {
        case .verification, .resetPassword:
            suggestions += actionVariables
        case .confirmEmailChange:
            suggestions += actionVariables + emailChangeVariables
        case .authAlert:
            suggestions += authAlertVariables
        }

        return suggestions
    }

    /// All available suggestions
    static var allSuggestions: [EmailTemplateSuggestion] {
        commonVariables + actionVariables + emailChangeVariables + recordVariables + authAlertVariables
    }
}

// MARK: - Default Templates

struct DefaultEmailTemplates {
    static let verificationSubject = "Verify your {APP_NAME} email"
    static let verificationBody = """
Hello,

Click on the button below to verify your email address.

{ACTION_URL}

If you did not request this email, you can safely ignore it.

Thanks,
{APP_NAME} team
"""

    static let resetPasswordSubject = "Reset your {APP_NAME} password"
    static let resetPasswordBody = """
Hello,

Click on the button below to reset your password.

{ACTION_URL}

If you did not request this email, you can safely ignore it.

Thanks,
{APP_NAME} team
"""

    static let confirmEmailChangeSubject = "Confirm your {APP_NAME} new email address"
    static let confirmEmailChangeBody = """
Hello,

Click on the button below to confirm your new email address.

{ACTION_URL}

If you did not request this email, you can safely ignore it.

Thanks,
{APP_NAME} team
"""

    static let authAlertSubject = "New login to your {APP_NAME} account"
    static let authAlertBody = """
Hello,

We noticed a new login to your account from:

Device: {DEVICE}
IP: {IP}

If this was you, you can safely ignore this email.

If you did not log in, please secure your account immediately.

Thanks,
{APP_NAME} team
"""
}
