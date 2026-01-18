//
//  DashboardCustomizationSheet.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// Sheet for customizing dashboard widget layout
struct DashboardCustomizationSheet: View {
    @Bindable var state: DashboardState
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Visible widgets section
                Section {
                    ForEach(state.layout.visibleWidgets) { widget in
                        WidgetConfigRow(
                            widget: widget,
                            onSizeChange: { newSize in
                                state.setSize(for: widget.id, size: newSize)
                            },
                            onHide: {
                                withAnimation {
                                    state.toggleVisibility(for: widget.id)
                                }
                            }
                        )
                    }
                    .onMove { source, destination in
                        state.moveWidget(from: source, to: destination)
                    }
                } header: {
                    HStack {
                        Text("Visible Widgets")
                        Spacer()
                        Text("Drag to reorder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Drag widgets to reorder them on the dashboard. Tap the size button to change widget size.")
                }

                // Hidden widgets section
                if !state.layout.hiddenWidgets.isEmpty {
                    Section("Hidden Widgets") {
                        ForEach(state.layout.hiddenWidgets) { widget in
                            HiddenWidgetRow(widget: widget) {
                                withAnimation {
                                    state.toggleVisibility(for: widget.id)
                                }
                            }
                        }
                    }
                }

                // Reset section
                Section {
                    Button(role: .destructive) {
                        withAnimation {
                            state.resetToDefault()
                        }
                    } label: {
                        Label("Reset to Default Layout", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Customize Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss?()
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
    }
}

// MARK: - Widget Config Row

private struct WidgetConfigRow: View {
    let widget: WidgetConfig
    var onSizeChange: (WidgetSize) -> Void
    var onHide: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.body)
                .foregroundStyle(.secondary)

            // Widget info
            Image(systemName: widget.type.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(widget.type.title)
                    .font(.body)
                Text(widget.type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Size picker
            Menu {
                ForEach(WidgetSize.allCases) { size in
                    Button {
                        onSizeChange(size)
                    } label: {
                        Label(size.title, systemImage: size.systemImage)
                        if widget.size == size {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Label(widget.size.title, systemImage: widget.size.systemImage)
                    .labelStyle(.iconOnly)
                    .font(.body)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            // Hide button
            Button {
                onHide()
            } label: {
                Image(systemName: "eye.slash")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hidden Widget Row

private struct HiddenWidgetRow: View {
    let widget: WidgetConfig
    var onShow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: widget.type.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(widget.type.title)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(widget.type.description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onShow()
            } label: {
                Label("Show", systemImage: "eye")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    DashboardCustomizationSheet(state: DashboardState())
}
