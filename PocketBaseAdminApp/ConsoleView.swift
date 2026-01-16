//
//  ConsoleView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import SwiftUI

/// Console view displaying PocketBase server logs
struct ConsoleView: View {
    @Environment(\.serverManager) private var serverManager

    @State private var autoScroll = true

    private var logs: [PocketBaseServerManager.LogEntry] {
        serverManager?.logs ?? []
    }

    var body: some View {
        Group {
            if logs.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Logs", systemImage: "text.alignleft")
        } description: {
            Text("Start the server to see logs")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(logs) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: logs.count) { _, _ in
                if autoScroll, let lastLog = logs.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct LogEntryRow: View {
    let entry: PocketBaseServerManager.LogEntry

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(entry.isError ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(2)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.message, forType: .string)
            }
            Button("Copy with Timestamp") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("[\(entry.formattedTimestamp)] \(entry.message)", forType: .string)
            }
        }
    }
}

#Preview {
    ConsoleView()
        .frame(height: 300)
}
#endif
