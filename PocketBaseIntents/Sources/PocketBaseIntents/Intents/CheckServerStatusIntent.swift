//
//  CheckServerStatusIntent.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Check if the PocketBase server is online and responding
public struct CheckServerStatusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Check Server Status"
    public static let description = IntentDescription("Check if your PocketBase server is online and responding")

    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<ServerStatusEntity> & ProvidesDialog {
        let startTime = Date()

        do {
            let client = try await ServerConfiguration.shared.getClient()
            let health = try await client.admin.health.check()

            let latency = Date().timeIntervalSince(startTime)
            let status = ServerStatusEntity(
                isOnline: true,
                latency: latency,
                version: health.code == 200 ? "Healthy" : "Unhealthy",
                checkedAt: Date()
            )

            return .result(
                value: status,
                dialog: "PocketBase is online with \(Int(latency * 1000))ms response time"
            )
        } catch ServerConfigurationError.noServerURL {
            let status = ServerStatusEntity(isOnline: false, checkedAt: Date())
            return .result(
                value: status,
                dialog: "No server configured. Please open the app to set up."
            )
        } catch {
            let status = ServerStatusEntity(isOnline: false, checkedAt: Date())
            return .result(
                value: status,
                dialog: "Server is offline or unreachable"
            )
        }
    }
}

