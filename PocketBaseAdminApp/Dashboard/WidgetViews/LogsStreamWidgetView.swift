//
//  LogsStreamWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// Logs stream widget showing recent log entries
struct LogsStreamWidgetView: View {
    let data: LogsStreamData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Logs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(data.logs.count)")
                            .font(.title2.bold())
                        Text("recent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if data.logs.isEmpty {
                ContentUnavailableView {
                    Label("No Logs", systemImage: "doc.text")
                } description: {
                    Text("No recent log entries")
                }
                .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(data.logs) { log in
                            LogEntryRow(log: log)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LogEntryRow: View {
    let log: LogsStreamData.LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Level indicator
            Circle()
                .fill(log.levelColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                // Main content
                HStack(spacing: 4) {
                    if let method = log.method {
                        Text(method)
                            .font(.caption2.bold())
                            .foregroundStyle(methodColor(method))
                    }

                    if let status = log.status {
                        Text("\(status)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(statusColor(status))
                    }

                    if let url = log.url {
                        Text(shortenUrl(url))
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text(log.message)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }

                // Timestamp
                Text(log.timestamp, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .blue
        case "POST": return .green
        case "PUT", "PATCH": return .orange
        case "DELETE": return .red
        default: return .secondary
        }
    }

    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .secondary
        }
    }

    private func shortenUrl(_ url: String) -> String {
        let path = url.components(separatedBy: "?").first ?? url
        let components = path.split(separator: "/")
        if components.count > 3 {
            return "/" + components.suffix(3).joined(separator: "/")
        }
        return path
    }
}

#Preview {
    LogsStreamWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
