//
//  DashboardView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import OSLog

private let logger = Logger(subsystem: "PocketBaseAdminApp", category: "DashboardView")

struct DashboardView: View {
    @State private var state = DashboardState()
    @State private var showCustomizationSheet = false

    @AppStorage("io.pocketbase.admin.dashboardLayout.v11") private var layout = DashboardLayout.default

    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Number of columns based on size class
    private var columns: [GridItem] {
        let columnCount = horizontalSizeClass == .compact ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(state.layout.visibleWidgets) { widget in
                    DashboardWidgetContainer(
                        config: widget,
                        state: state,
                        isEditMode: state.isEditMode
                    )
                    .gridCellColumns(min(widget.size.columnSpan, columns.count))
                }
            }
            .padding()
            .animation(.smooth, value: state.layout.visibleWidgets)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if state.isEditMode {
                    Button("Done") {
                        withAnimation {
                            state.isEditMode = false
                            // Persist layout changes
                            layout = state.layout
                        }
                    }
                    .fontWeight(.semibold)
                } else {
                    Button {
                        Task {
                            await state.loadAllData(pocketbase: pocketbase)
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(state.isLoading)

                    Button {
                        showCustomizationSheet = true
                    } label: {
                        Label("Customize", systemImage: "slider.horizontal.3")
                    }

                    Button {
                        withAnimation {
                            state.isEditMode = true
                        }
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
        }
        .overlay {
            if state.isLoading && state.serverStatus == nil {
                ProgressView("Loading dashboard...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .refreshable {
            await state.loadAllData(pocketbase: pocketbase)
        }
        .task {
            // Load persisted layout
            state.layout = layout
            await state.loadAllData(pocketbase: pocketbase)
        }
        .sheet(isPresented: $showCustomizationSheet) {
            DashboardCustomizationSheet(state: state) {
                // On dismiss, persist layout
                layout = state.layout
            }
        }
    }
}

// MARK: - Widget Container

struct DashboardWidgetContainer: View {
    let config: WidgetConfig
    @Bindable var state: DashboardState
    var isEditMode: Bool

    @Environment(\.pocketbase) private var pocketbase

    var body: some View {
        ZStack(alignment: .topTrailing) {
            widgetContent
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isEditMode ? Color.accentColor : Color.clear, lineWidth: 2)
                )

            if isEditMode {
                editOverlay
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            widgetContextMenu
        }
    }

    /// Minimum height based on widget type
    private var minHeight: CGFloat {
        switch config.type {
        case .serverStatus, .quickActions, .storage, .errorDistribution, .responseCodes, .settingsStatus:
            return 140
        case .latency:
            return 200
        case .requestVolume, .errorRate, .collections, .topEndpoints:
            return 180
        case .recentErrors, .logsStream:
            return 240
        }
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch config.type {
        case .serverStatus:
            ServerStatusWidgetView(data: state.serverStatus ?? .placeholder)
        case .storage:
            StorageWidgetView(data: state.storage ?? .placeholder)
        case .recentErrors:
            RecentErrorsWidgetView(data: state.recentErrors ?? .placeholder)
        case .quickActions:
            QuickActionsWidgetView(pocketbase: pocketbase, onRefresh: {
                Task {
                    await state.loadAllData(pocketbase: pocketbase)
                }
            })
        case .collections:
            CollectionsWidgetView(data: state.collections ?? .placeholder)
        case .errorDistribution:
            ErrorDistributionWidgetView(data: state.errorDistribution ?? .placeholder)
        case .latency:
            LatencyWidgetView(data: state.latency ?? .placeholder)
        case .requestVolume:
            RequestVolumeWidgetView(data: state.requestVolume ?? .placeholder)
        case .errorRate:
            ErrorRateWidgetView(data: state.errorRate ?? .placeholder)
        case .topEndpoints:
            TopEndpointsWidgetView(data: state.topEndpoints ?? .placeholder)
        case .responseCodes:
            ResponseCodesWidgetView(data: state.responseCodes ?? .placeholder)
        case .settingsStatus:
            SettingsStatusWidgetView(data: state.settingsStatus ?? .placeholder)
        case .logsStream:
            LogsStreamWidgetView(data: state.logsStream ?? .placeholder)
        }
    }

    private var editOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    withAnimation {
                        state.toggleVisibility(for: config.id)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(8)
    }

    @ViewBuilder
    private var widgetContextMenu: some View {
        Menu("Size") {
            ForEach(WidgetSize.allCases) { size in
                Button {
                    withAnimation {
                        state.setSize(for: config.id, size: size)
                    }
                } label: {
                    Label(size.title, systemImage: size.systemImage)
                    if config.size == size {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }

        Button {
            Task {
                await state.refresh(widget: config.type, pocketbase: pocketbase)
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }

        Divider()

        Button(role: .destructive) {
            withAnimation {
                state.toggleVisibility(for: config.id)
            }
        } label: {
            Label("Hide", systemImage: "eye.slash")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
    }
    .pocketbase(.localhost)
}
