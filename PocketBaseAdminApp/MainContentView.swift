//
//  MainContentView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import SwiftUI

/// Main view container with collapsible console pane
struct ConsoleContainerView: View {
    var onLogout: (() -> Void)?

    @Environment(\.serverManager) private var serverManager

    @AppStorage("io.pocketbase.admin.consoleVisible") private var isConsoleVisible = false
    @State private var consoleHeight: CGFloat = 200

    private let minConsoleHeight: CGFloat = 100
    private let maxConsoleHeight: CGFloat = 500

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main content
                ContentView(onLogout: onLogout)
                    .frame(maxHeight: isConsoleVisible ? geometry.size.height - consoleHeight - 40 : .infinity)

                if isConsoleVisible {
                    // Drag handle
                    dragHandle

                    // Console pane
                    consolePaneContent
                        .frame(height: consoleHeight)
                }

                // Bottom bar
                ConsoleBottomBar(isConsoleVisible: $isConsoleVisible)
            }
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

    private var dragHandle: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .overlay(alignment: .center) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 36, height: 4)
                    .padding(.vertical, 2)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newHeight = consoleHeight - value.translation.height
                        consoleHeight = max(minConsoleHeight, min(maxConsoleHeight, newHeight))
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
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
