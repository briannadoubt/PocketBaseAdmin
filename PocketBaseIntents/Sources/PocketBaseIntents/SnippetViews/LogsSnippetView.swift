//
//  LogsSnippetView.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// Visual snippet view for logs shown in Siri/Shortcuts
public struct LogsSnippetView: View {
    public let logs: [LogEntryEntity]

    public init(logs: [LogEntryEntity]) {
        self.logs = logs
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                Text("Recent Logs")
                    .font(.headline)
                Spacer()

                let errorCount = logs.filter { $0.level == .error }.count
                if errorCount > 0 {
                    Text("\(errorCount) errors")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if logs.isEmpty {
                Text("No logs found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(logs.prefix(5), id: \.id) { log in
                    LogEntryRow(log: log)
                }

                if logs.count > 5 {
                    Text("+ \(logs.count - 5) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

/// Compact row for a single log entry
public struct LogEntryRow: View {
    public let log: LogEntryEntity

    public init(log: LogEntryEntity) {
        self.log = log
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(log.level.color)
                .frame(width: 8, height: 8)

            Text(log.message)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Text(log.created.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

/// Compact error count view for widgets
public struct ErrorCountView: View {
    public let count: Int

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(countColor)

            Text(count == 1 ? "error" : "errors")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("last 24h")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var countColor: Color {
        switch count {
        case 0: return .green
        case 1...5: return .yellow
        default: return .red
        }
    }
}
