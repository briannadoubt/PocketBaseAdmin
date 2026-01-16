//
//  MainContentView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import SwiftUI

/// Main view container with collapsible console pane using native VSplitView
struct ConsoleContainerView: View {
    var onLogout: (() -> Void)?

    @Environment(\.serverManager) private var serverManager

    @AppStorage("io.pocketbase.admin.consoleVisible") private var isConsoleVisible = false

    var body: some View {
        Group {
            if isConsoleVisible {
                VSplitView {
                    // Main content (top)
                    ContentView(onLogout: onLogout)
                        .frame(minHeight: 200)

                    // Console pane (bottom)
                    ConsolePane()
                        .frame(minHeight: 100, idealHeight: 200)
                }
            } else {
                ContentView(onLogout: onLogout)
            }
        }
        .focusedSceneValue(\.serverManager, serverManager)
        .toolbar {
            // Server controls in main toolbar
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await serverManager?.start()
                        if !isConsoleVisible {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isConsoleVisible = true
                            }
                        }
                    }
                } label: {
                    Label("Start Server", systemImage: "play.fill")
                }
                .disabled(!(serverManager?.state.canStart ?? true))
                .help("Start PocketBase Server")

                Button {
                    serverManager?.stop()
                } label: {
                    Label("Stop Server", systemImage: "stop.fill")
                }
                .disabled(!(serverManager?.state.canStop ?? false))
                .help("Stop PocketBase Server")
            }

            // Bottom accessory bar (like Xcode's debug console)
            ToolbarItem(placement: .accessoryBar(id: "console")) {
                HStack {
                    // Server status
                    ServerStatusIndicator()

                    Spacer()

                    // Console toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isConsoleVisible.toggle()
                        }
                    } label: {
                        Label(
                            isConsoleVisible ? "Hide Console" : "Show Console",
                            systemImage: "terminal"
                        )
                    }
                    .help(isConsoleVisible ? "Hide Console (⌘⇧Y)" : "Show Console (⌘⇧Y)")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleConsole)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isConsoleVisible.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startServer)) { _ in
            Task {
                await serverManager?.start()
                if !isConsoleVisible {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isConsoleVisible = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopServer)) { _ in
            serverManager?.stop()
        }
    }
}

// MARK: - Server Status Indicator

struct ServerStatusIndicator: View {
    @Environment(\.serverManager) private var serverManager

    private var state: PocketBaseServerManager.ServerState {
        serverManager?.state ?? .stopped
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let port = serverManager?.port, state.isRunning {
                Text("• 127.0.0.1:\(port)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusColor: Color {
        switch state {
        case .stopped: .secondary
        case .starting, .stopping: .orange
        case .running: .green
        case .error: .red
        }
    }

    private var statusText: String {
        switch state {
        case .stopped: "Stopped"
        case .starting: "Starting..."
        case .running: "Running"
        case .stopping: "Stopping..."
        case .error(let msg): "Error: \(msg)"
        }
    }
}

// MARK: - Console Pane

struct ConsolePane: View {
    @Environment(\.serverManager) private var serverManager

    @State private var filterText = ""

    var body: some View {
        VStack(spacing: 0) {
            ConsoleView()

            Divider()

            // Bottom toolbar (like Xcode)
            HStack(spacing: 12) {
                // Error/warning counts
                if let logs = serverManager?.logs {
                    let errorCount = logs.filter { $0.isError }.count
                    if errorCount > 0 {
                        Label("\(errorCount)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Label("\(logs.count)", systemImage: "text.alignleft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Filter field
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(.secondary)
                    TextField("Filter", text: $filterText)
                        .textFieldStyle(.plain)
                        .frame(width: 150)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)

                // Clear button
                Button {
                    serverManager?.clearLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear Console")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

#Preview {
    ConsoleContainerView()
        .frame(width: 1000, height: 700)
}
#endif
