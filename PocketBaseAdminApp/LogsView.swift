//
//  LogsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI
import PocketBaseAdmin
import PocketBase
import OSLog
import Foundation
import Charts

@Observable @MainActor
final class LogsState: Identifiable {
    var logs: [LogModel] = []
    var page: Int = 1
    var isLoading: Bool = false
    var searchQuery: String = ""
    var selectedLogLevels: Set<LogLevel> = Set(LogLevel.allCases)
    var includeAdminRequests: Bool = true
    var maxDaysRetention: Int = 5
    var minLogLevel: Int = 0
    var enableIPLogging: Bool = true
    
    var logger = Logger(subsystem: "PocketBaseAdminApp", category: "LogsState")
    
    var retryCount: Int = 0
    var maxRetryCount: Int = 5
    
    // Chart data
    var chartData: [LogStat] = []
    var selectedDateRange: ClosedRange<Date>?
    
    @concurrent
    func load(with pocketbase: PocketBase) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let logs = try await pocketbase.admin.logs.list(page: 1).items

            let chartData = try await generateChartData(pocketbase: pocketbase)
            await MainActor.run {
                self.logs = logs
                self.chartData = chartData
                isLoading = false
                retryCount = 0
            }
        } catch {
            await MainActor.run {
                isLoading = false
                retryCount += 1
                logger.error("Failed to load logs: \(String(describing: error))")
            }
        }
    }
    
    func generateChartData(pocketbase: PocketBase) async throws -> [LogStat] {
        let stats = try await pocketbase.admin.logs.stats()
        return stats
    }
}

struct LogsView: View {
    @State private var state = LogsState()
    @State private var selectedLogs: Set<LogModel.ID> = []
    @State private var showingLogSettings = false
    
    @State private var isInspectorPresented = false
    @State private var inspectedLog: LogModel? = nil
    
    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    
    var body: some View {
        VStack(spacing: 0) {
            ChartSection(state: state)
            LogsTableSection(state: state, selectedLogs: $selectedLogs, horizontalSizeClass: horizontalSizeClass)
        }
        .onAppear {
            Task {
                await state.load(with: pocketbase)
            }
        }
        .navigationTitle("Logs")
        .searchable(text: $state.searchQuery)
        .onChange(of: selectedLogs) { _, newSelection in
            if let firstId = newSelection.first, let log = state.logs.first(where: { $0.id == firstId }) {
                inspectedLog = log
                isInspectorPresented = true
            } else {
                inspectedLog = nil
                isInspectorPresented = false
            }
        }
        .inspector(isPresented: $isInspectorPresented) {
            if let log = inspectedLog {
                LogInspectorView(log: log)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if !selectedLogs.isEmpty {
                    LogsSelectionToolbarView(
                        selectedCount: selectedLogs.count,
                        onReset: {
                            selectedLogs.removeAll()
                        },
                        onDownload: {
                            // Handle log download as JSON
                            selectedLogs.removeAll()
                        }
                    )
                }
            }
            
            ToolbarItem(placement: .navigation) {
                Toggle(
                    "Include requests by admins",
                    systemImage: "person.crop.circle.badge.checkmark",
                    isOn: $state.includeAdminRequests
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelStyle(.iconOnly)
                .padding(.horizontal, 4)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button("Logs settings", systemImage: "gearshape") {
                    showingLogSettings = true
                }
                .labelStyle(.iconOnly)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        await state.load(with: pocketbase)
                    }
                }
                .labelStyle(.iconOnly)
            }
        }
        .sheet(isPresented: $showingLogSettings) {
            LogsSettingsView(state: state)
        }
    }
}

struct CompactLogRow: View {
    let log: LogModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.level.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(log.level.color.opacity(0.2))
                    .foregroundColor(log.level.color)
                    .cornerRadius(4)
                
                Spacer()
                
                Text(log.created, format: .dateTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 2)
    }
}

struct LogInspectorView: View {
    let log: LogModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Request log")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                LogDetailRow(label: "id", value: log.id)
                LogDetailRow(label: "level", value: log.level.displayName, valueColor: log.level.color)
                LogDetailRow(label: "created", value: log.created.formatted())
                
                if let execTime = log.data.execTime {
                    LogDetailRow(label: "data.execTime", value: "\(execTime)ms")
                }
                
                if let type = log.data.type {
                    LogDetailRow(label: "data.type", value: type)
                }
                
                if let auth = log.data.auth {
                    LogDetailRow(label: "data.auth", value: auth)
                }
                
                if let status = log.data.status {
                    LogDetailRow(label: "data.status", value: "\(status)")
                }
                
                if let method = log.data.method {
                    LogDetailRow(label: "data.method", value: method)
                }
                
                if let url = log.data.url {
                    LogDetailRow(label: "data.url", value: url)
                }
                
                if let referer = log.data.referer {
                    LogDetailRow(label: "data.referer", value: referer)
                } else {
                    LogDetailRow(label: "data.referer", value: "N/A")
                }
                
                if let remoteIp = log.data.remoteIp {
                    LogDetailRow(label: "data.remoteIp", value: remoteIp)
                }
                
                if let userIp = log.data.userIp {
                    LogDetailRow(label: "data.userIp", value: userIp)
                }
                
                if let userAgent = log.data.userAgent {
                    LogDetailRow(label: "data.userAgent", value: userAgent)
                }
            }
            
            Spacer()
            
            HStack {
                Button("Close") {
                    // Handle close
                }
                
                Spacer()
                
                Button("Download as JSON") {
                    // Handle JSON download
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct LogDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .foregroundColor(valueColor)
                .textSelection(.enabled)
        }
    }
}

struct LogsSettingsView: View {
    @Bindable var state: LogsState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Logs settings")
                    .font(.headline)
                
                Spacer()
                
                Button("✕") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Max days retention")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("", value: $state.maxDaysRetention, format: .number)
                    .textFieldStyle(.roundedBorder)
                
                Text("Set to 0 to disable logs persistence.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Min log level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("", value: $state.minLogLevel, format: .number)
                    .textFieldStyle(.roundedBorder)
                
                Text("Logs with level below the minimum will be ignored.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Default log levels:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(LogLevel.allCases) { level in
                        Text("\(level.numericValue):\(level.displayName)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(level.color.opacity(0.2))
                            .foregroundColor(level.color)
                            .cornerRadius(4)
                    }
                }
            }
            
            Toggle("Enable IP logging", isOn: $state.enableIPLogging)
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Save changes") {
                    // Handle saving settings
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(false) // Add validation logic here
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

struct LogsSelectionToolbarView: View {
    let selectedCount: Int
    let onReset: () -> Void
    let onDownload: () -> Void
    
    var body: some View {
        HStack {
            Text("Selected \(selectedCount) logs")
                .font(.headline)
            
            Button("Reset") {
                onReset()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Download as JSON") {
                onDownload()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

private struct ChartSection: View {
    let state: LogsState
    var body: some View {
        if !state.chartData.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Chart(state.chartData) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Count", point.total)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Count", point.total)
                    )
                    .foregroundStyle(.red.opacity(0.2))
                }
                .frame(height: 120)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .padding()
            }
#if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
#else
            .background(Color(.systemBackground))
#endif
            Divider()
        }
    }
}

private struct LogLevelFilterPills: View {
    @Bindable var state: LogsState
    var body: some View {
        HStack {
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
#if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
#else
        .background(Color(.systemBackground))
#endif
        Divider()
    }
}

private struct LogsTableSection: View {
    @Bindable var state: LogsState
    @Binding var selectedLogs: Set<LogModel.ID>
    var horizontalSizeClass: UserInterfaceSizeClass?
    
    var body: some View {
        if horizontalSizeClass == .compact {
            // Use List for compact layouts (mobile)
            List(state.logs, selection: $selectedLogs) { log in
                CompactLogRow(log: log)
            }
        } else {
            // Use Table for regular layouts (desktop/tablet)
            Table(state.logs, selection: $selectedLogs) {
                TableColumn("Level") { log in
                    Text(log.level.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(log.level.color.opacity(0.2))
                        .foregroundColor(log.level.color)
                        .cornerRadius(4)
                }
                .width(min: 80, ideal: 100, max: 120)
                
                TableColumn("Message") { log in
                    Text(log.message)
                        .lineLimit(2)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 200, ideal: 400)
                
                TableColumn("Created") { log in
                    Text(log.created, format: .dateTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .width(min: 140, ideal: 160, max: 180)
            }
        }
    }
}

