//
//  SettingsIntents.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Send a test email to verify SMTP configuration
public struct TestEmailIntent: AppIntent {
    public static let title: LocalizedStringResource = "Test Email Settings"
    public static let description = IntentDescription("Send a test email to verify your SMTP configuration")

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Recipient Email")
    public var recipient: String

    public init() {}

    public init(recipient: String) {
        self.recipient = recipient
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()
            try await client.admin.settings.testEmail(to: recipient)

            return .result(dialog: "Test email sent to \(recipient)")
        } catch {
            throw ServerConfigurationError.serverError("Failed to send test email: \(error.localizedDescription)")
        }
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Send test email to \(\.$recipient)")
    }
}

/// Test S3 storage connection
public struct TestS3Intent: AppIntent {
    public static let title: LocalizedStringResource = "Test S3 Storage"
    public static let description = IntentDescription("Test your S3 storage connection")

    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()
            try await client.admin.settings.testS3()

            return .result(dialog: "S3 storage connection successful")
        } catch {
            throw ServerConfigurationError.serverError("S3 connection failed: \(error.localizedDescription)")
        }
    }
}
