//
//  ConsoleBottomBar.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import SwiftUI

/// Persistent bottom toolbar for server controls and console toggle
struct ConsoleBottomBar: View {
    @Environment(\.serverManager) private var serverManager
    @Binding var isConsoleVisible: Bool

    private var state: PocketBaseServerManager.ServerState {
        serverManager?.state ?? .stopped
    }

    private var logCount: Int {
        serverManager?.logs.count ?? 0
    }

    private var errorCount: Int {
        serverManager?.logs.filter { $0.isError }.count ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Server controls
            serverControls

            Divider()
                .frame(height: 16)

            // Status indicator
            statusIndicator

            Spacer()

            // Log summary
            logSummary

            Divider()
                .frame(height: 16)

            // Console toggle
            consoleToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var serverControls: some View {
        HStack(spacing: 4) {
            // Play/Start button
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
                Image(systemName: "play.fill")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .disabled(!state.canStart)
            .help("Start Server (⌘R)")

            // Stop button
            Button {
                serverManager?.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .disabled(!state.canStop)
            .help("Stop Server (⌘.)")
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay {
                    if case .starting = state {
                        Circle()
                            .stroke(statusColor, lineWidth: 1)
                            .scaleEffect(1.5)
                            .opacity(0)
                            .animation(
                                .easeOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                value: state
                            )
                    }
                }

            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch state {
        case .stopped:
            return .secondary
        case .starting, .stopping:
            return .orange
        case .running:
            return .green
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch state {
        case .stopped:
            return "Server Stopped"
        case .starting:
            return "Starting..."
        case .running:
            return "Server Running"
        case .stopping:
            return "Stopping..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    private var logSummary: some View {
        HStack(spacing: 8) {
            if errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text("\(errorCount)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
                    .font(.caption2)
                Text("\(logCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var consoleToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isConsoleVisible.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isConsoleVisible ? "rectangle.bottomthird.inset.filled" : "rectangle.bottomthird.inset.filled")
                    .symbolRenderingMode(.hierarchical)
                Text(isConsoleVisible ? "Hide Console" : "Show Console")
                    .font(.caption)
            }
        }
        .buttonStyle(.borderless)
        .help(isConsoleVisible ? "Hide Console (⌘⇧Y)" : "Show Console (⌘⇧Y)")
    }
}

#Preview {
    VStack {
        Spacer()
        ConsoleBottomBar(isConsoleVisible: .constant(true))
    }
    .frame(height: 200)
}
#endif
