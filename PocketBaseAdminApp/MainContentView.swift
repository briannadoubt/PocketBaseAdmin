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
        VStack(spacing: 0) {
            if isConsoleVisible {
                VSplitView {
                    // Main content (top)
                    ContentView(onLogout: onLogout)
                        .frame(minHeight: 200)

                    // Console pane (bottom)
                    consolePaneContent
                        .frame(minHeight: 100, idealHeight: 200)
                }
            } else {
                ContentView(onLogout: onLogout)
            }

            // Bottom bar (always visible)
            ConsoleBottomBar(isConsoleVisible: $isConsoleVisible)
        }
        .focusedSceneValue(\.serverManager, serverManager)
        .toolbar {
            serverToolbarContent
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

    private var consolePaneContent: some View {
        VStack(spacing: 0) {
            // Console header
            HStack {
                Label("Console", systemImage: "terminal")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                if serverManager?.state.isRunning == true, let port = serverManager?.port {
                    Link(destination: URL(string: "http://127.0.0.1:\(port)")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("127.0.0.1:\(port)")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ConsoleView()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ToolbarContentBuilder
    private var serverToolbarContent: some ToolbarContent {
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
    }
}

#Preview {
    ConsoleContainerView()
        .frame(width: 1000, height: 700)
}
#endif
