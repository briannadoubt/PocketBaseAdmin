//
//  LogsListView.swift
//  PocketBase Watch App
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import WatchKit

struct WatchLogEntry: Identifiable {
    let id: String
    let level: WatchLogLevel
    let message: String
    let timestamp: Date
}

enum WatchLogLevel: Int {
    case debug = -4
    case info = 0
    case warning = 4
    case error = 8

    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }

    var name: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}

struct LogsListView: View {
    @State private var logs: [WatchLogEntry] = []
    @State private var isLoading = false
    @State private var showErrorsOnly = false

    private var filteredLogs: [WatchLogEntry] {
        if showErrorsOnly {
            return logs.filter { $0.level == .error }
        }
        return logs
    }

    private var errorCount: Int {
        logs.filter { $0.level == .error }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Filter toggle
                Toggle(isOn: $showErrorsOnly) {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.red)
                        Text("Errors Only")
                    }
                }
                .padding(.horizontal)

                // Error count badge
                if errorCount > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("\(errorCount) errors in last 24h")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }

                Divider()

                // Logs list
                if isLoading {
                    ProgressView()
                        .padding()
                } else if filteredLogs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(showErrorsOnly ? "No errors" : "No logs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ForEach(filteredLogs) { log in
                        LogRow(log: log)
                    }
                }
            }
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        WKInterfaceDevice.current().play(.start)

        // TODO: Use GetRecentLogsIntent
        // For now, use sample data
        try? await Task.sleep(for: .milliseconds(500))

        logs = [
            WatchLogEntry(id: "1", level: .info, message: "Request completed", timestamp: Date()),
            WatchLogEntry(id: "2", level: .warning, message: "Slow query", timestamp: Date().addingTimeInterval(-300)),
            WatchLogEntry(id: "3", level: .error, message: "Connection timeout", timestamp: Date().addingTimeInterval(-600)),
            WatchLogEntry(id: "4", level: .info, message: "User logged in", timestamp: Date().addingTimeInterval(-900)),
            WatchLogEntry(id: "5", level: .error, message: "Auth failed", timestamp: Date().addingTimeInterval(-1200))
        ]

        WKInterfaceDevice.current().play(.success)
    }
}

struct LogRow: View {
    let log: WatchLogEntry

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(log.level.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.message)
                    .font(.caption)
                    .lineLimit(2)

                Text(log.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        LogsListView()
    }
}
