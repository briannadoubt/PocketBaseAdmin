//
//  MainContentView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import SwiftUI

/// Main view container with VSplitView for collapsible console pane
struct MainContentView: View {
    var onLogout: (() -> Void)?

    @Environment(\.serverManager) private var serverManager

    @AppStorage("io.pocketbase.admin.consoleVisible") private var isConsoleVisible = false
    @AppStorage("io.pocketbase.admin.consoleHeight") private var consoleHeight: Double = 200

    /// Minimum console height when visible
    private let minConsoleHeight: CGFloat = 100
    /// Maximum console height (percentage of window)
    private let maxConsoleHeightRatio: CGFloat = 0.6

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main content area with optional console
                if isConsoleVisible {
                    VSplitView {
                        // Main content
                        ContentView(onLogout: onLogout)
                            .frame(minHeight: 200)

                        // Console pane
                        consolePane
                            .frame(
                                minHeight: minConsoleHeight,
                                idealHeight: consoleHeight,
                                maxHeight: geometry.size.height * maxConsoleHeightRatio
                            )
                    }
                } else {
                    ContentView(onLogout: onLogout)
                }

                // Bottom bar (always visible)
                ConsoleBottomBar(isConsoleVisible: $isConsoleVisible)
            }
        }
        .toolbar {
            serverToolbarItems
        }
    }

    private var consolePane: some View {
        VStack(spacing: 0) {
            // Console header
            HStack {
                Label("Console", systemImage: "terminal")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Port info when running
                if serverManager?.state.isRunning == true {
                    if let port = serverManager?.port {
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
    private var serverToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Start/Run button
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

            // Stop button
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

// MARK: - VSplitView for macOS

/// A vertical split view that allows resizing between two views
struct VSplitView<Content: View>: NSViewRepresentable {
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = false // Horizontal divider (top/bottom split)
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator
        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        // Extract the two views from content
        let hostingViews = splitView.arrangedSubviews.compactMap { $0 as? NSHostingView<AnyView> }

        // Get the views from the content
        let mirror = Mirror(reflecting: content)
        var views: [AnyView] = []

        for child in mirror.children {
            if let tupleContent = child.value as? any View {
                views.append(AnyView(tupleContent))
            }
        }

        // If we have a TupleView, extract its content
        if views.isEmpty {
            // Try to get views from TupleView
            if let tuple = content as? TupleView<(some View, some View)> {
                let tupleMirror = Mirror(reflecting: tuple.value)
                for (_, value) in tupleMirror.children {
                    if let view = value as? any View {
                        views.append(AnyView(view))
                    }
                }
            }
        }

        // Fallback: create hosting views if needed
        if splitView.arrangedSubviews.isEmpty && views.count >= 2 {
            let topView = NSHostingView(rootView: views[0])
            let bottomView = NSHostingView(rootView: views[1])

            splitView.addArrangedSubview(topView)
            splitView.addArrangedSubview(bottomView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSSplitViewDelegate {
        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            return 200 // Minimum height for top view
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            return splitView.bounds.height - 100 // Leave at least 100pt for console
        }
    }
}

// MARK: - Simpler approach using native SwiftUI

/// Alternative implementation using native SwiftUI for better compatibility
struct ConsoleContainerView: View {
    var onLogout: (() -> Void)?

    @Environment(\.serverManager) private var serverManager

    @AppStorage("io.pocketbase.admin.consoleVisible") private var isConsoleVisible = false
    @State private var consoleHeight: CGFloat = 200

    private let minConsoleHeight: CGFloat = 100
    private let maxConsoleHeight: CGFloat = 500
    private let dragHandleHeight: CGFloat = 8

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
    MainContentView()
        .frame(width: 1000, height: 700)
}
#endif
