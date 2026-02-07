//
//  GetRecentLogsIntent.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Filter for log levels
public enum LogLevelFilter: String, AppEnum, Sendable {
    case all = "all"
    case info = "info"
    case warning = "warning"
    case error = "error"

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Log Level Filter")

    public static let caseDisplayRepresentations: [LogLevelFilter: DisplayRepresentation] = [
        .all: DisplayRepresentation(title: "All Levels"),
        .info: DisplayRepresentation(title: "Info & Above"),
        .warning: DisplayRepresentation(title: "Warnings & Errors"),
        .error: DisplayRepresentation(title: "Errors Only")
    ]

    var minimumLevel: Int {
        switch self {
        case .all: return -10
        case .info: return 0
        case .warning: return 4
        case .error: return 8
        }
    }
}

/// Get recent log entries
public struct GetRecentLogsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Recent Logs"
    public static let description = IntentDescription("Get recent log entries from your PocketBase server")

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Level Filter", default: .all)
    public var level: LogLevelFilter

    @Parameter(title: "Limit", default: 10)
    public var limit: Int

    public init() {}

    public init(level: LogLevelFilter = .all, limit: Int = 10) {
        self.level = level
        self.limit = limit
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[LogEntryEntity]> & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()

            // Build filter based on level
            var filter: String? = nil
            if level != .all {
                filter = "level >= \(level.minimumLevel)"
            }

            let logs = try await client.admin.logs.list(
                page: 1,
                perPage: limit,
                filter: filter
            )

            let entities = logs.items.map { LogEntryEntity(from: $0) }
            let errorCount = entities.filter { $0.level == .error }.count

            let dialog: IntentDialog
            if errorCount > 0 {
                dialog = "Found \(entities.count) logs with \(errorCount) errors"
            } else {
                dialog = "Found \(entities.count) recent logs"
            }

            return .result(value: entities, dialog: dialog)
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$limit) recent \(\.$level) logs")
    }
}

/// Get error count in the last 24 hours
public struct GetErrorCountIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Error Count"
    public static let description = IntentDescription("Count errors in the last 24 hours")

    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()

            // Get errors from last 24 hours
            let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
            let filter = "level >= 8 && created >= '\(yesterday.ISO8601Format())'"

            let logs = try await client.admin.logs.list(
                page: 1,
                perPage: 1,
                filter: filter
            )

            let errorCount = logs.totalItems

            let dialog: IntentDialog
            switch errorCount {
            case 0:
                dialog = "No errors in the last 24 hours"
            case 1:
                dialog = "1 error in the last 24 hours"
            default:
                dialog = "\(errorCount) errors in the last 24 hours"
            }

            return .result(value: errorCount, dialog: dialog)
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }
}

/// Get warning count in the last 24 hours
public struct GetWarningCountIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Warning Count"
    public static let description = IntentDescription("Count warnings in the last 24 hours")

    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()

            // Get warnings from last 24 hours (level 4-7, not errors which are 8+)
            let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
            let filter = "level >= 4 && level < 8 && created >= '\(yesterday.ISO8601Format())'"

            let logs = try await client.admin.logs.list(
                page: 1,
                perPage: 1,
                filter: filter
            )

            let warningCount = logs.totalItems

            let dialog: IntentDialog
            switch warningCount {
            case 0:
                dialog = "No warnings in the last 24 hours"
            case 1:
                dialog = "1 warning in the last 24 hours"
            default:
                dialog = "\(warningCount) warnings in the last 24 hours"
            }

            return .result(value: warningCount, dialog: dialog)
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }
}
