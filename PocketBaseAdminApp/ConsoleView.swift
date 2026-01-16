//
//  ConsoleView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import SwiftUI

/// Console view displaying PocketBase server logs, similar to Xcode's console
struct ConsoleView: View {
    @Environment(\.serverManager) private var serverManager

    @State private var filterText = ""
    @State private var showErrorsOnly = false
    @State private var autoScroll = true

    private var filteredLogs: [PocketBaseServerManager.LogEntry] {
        guard let logs = serverManager?.logs else { return [] }

        return logs.filter { entry in
            if showErrorsOnly && !entry.isError {
                return false
            }
            if !filterText.isEmpty {
                return entry.message.localizedCaseInsensitiveContains(filterText)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Console toolbar
            consoleToolbar

            Divider()

            // Log content
            if filteredLogs.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var consoleToolbar: some View {
        HStack(spacing: 8) {
            // Filter field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TextField("Filter", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.caption)

                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 200)

            Spacer()

            // Errors only toggle
            Toggle(isOn: $showErrorsOnly) {
                Label("Errors Only", systemImage: "exclamationmark.triangle")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .font(.caption)

            // Auto-scroll toggle
            Toggle(isOn: $autoScroll) {
                Label("Auto-scroll", systemImage: "arrow.down.to.line")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .font(.caption)

            Divider()
                .frame(height: 16)

            // Clear button
            Button {
                serverManager?.clearLogs()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear Console")

            // Log count
            Text("\(filteredLogs.count) logs")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Logs", systemImage: "text.alignleft")
        } description: {
            if showErrorsOnly {
                Text("No errors to display")
            } else if !filterText.isEmpty {
                Text("No logs matching \"\(filterText)\"")
            } else {
                Text("Start the server to see logs")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredLogs) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: filteredLogs.count) { _, _ in
                if autoScroll, let lastLog = filteredLogs.last {
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
            // Timestamp
            Text(entry.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            // Message
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
