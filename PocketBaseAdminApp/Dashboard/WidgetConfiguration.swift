//
//  WidgetConfiguration.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import SwiftUI

// MARK: - Dashboard Widget Type

/// Types of widgets available on the dashboard
enum DashboardWidgetType: String, Codable, Identifiable {
    case serverStatus
    case requestVolume
    case errorRate
    case errorDistribution
    case latency
    case collections
    case storage
    case recentErrors
    case quickActions
    // New widgets (temporarily excluded from allCases)
    case topEndpoints
    case responseCodes
    case settingsStatus
    case logsStream

    /// Only include original widgets in default layout for now
    static var allCases: [DashboardWidgetType] {
        [.serverStatus, .requestVolume, .errorRate, .errorDistribution, .latency, .collections, .storage, .recentErrors, .quickActions, .topEndpoints, .responseCodes, .settingsStatus, .logsStream]
    }

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .serverStatus: "Server Status"
        case .requestVolume: "Request Volume"
        case .errorRate: "Error Rate"
        case .errorDistribution: "Error Distribution"
        case .latency: "Latency"
        case .collections: "Collections"
        case .storage: "Storage"
        case .recentErrors: "Recent Errors"
        case .quickActions: "Quick Actions"
        case .topEndpoints: "Top Endpoints"
        case .responseCodes: "Response Codes"
        case .settingsStatus: "Settings"
        case .logsStream: "Live Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .serverStatus: "server.rack"
        case .requestVolume: "chart.line.uptrend.xyaxis"
        case .errorRate: "exclamationmark.triangle"
        case .errorDistribution: "chart.pie"
        case .latency: "gauge.with.needle"
        case .collections: "rectangle.stack"
        case .storage: "internaldrive"
        case .recentErrors: "xmark.circle"
        case .quickActions: "bolt"
        case .topEndpoints: "arrow.up.arrow.down"
        case .responseCodes: "number.circle"
        case .settingsStatus: "gearshape.2"
        case .logsStream: "text.line.first.and.arrowtriangle.forward"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .serverStatus: "Monitor server health and uptime"
        case .requestVolume: "Track request volume over time"
        case .errorRate: "Monitor error trends"
        case .errorDistribution: "Error breakdown by type"
        case .latency: "Check response times"
        case .collections: "View collection record counts"
        case .storage: "Monitor backup storage usage"
        case .recentErrors: "View recent error logs"
        case .quickActions: "Quick access to common actions"
        case .topEndpoints: "Most accessed API endpoints"
        case .responseCodes: "HTTP response code breakdown"
        case .settingsStatus: "Server configuration status"
        case .logsStream: "Live stream of all logs"
        }
    }

    /// Suggested default size for this widget type
    var suggestedSize: WidgetSize {
        switch self {
        case .serverStatus: .small
        case .requestVolume: .medium
        case .errorRate: .medium
        case .errorDistribution: .small
        case .latency: .small
        case .collections: .medium
        case .storage: .small
        case .recentErrors: .large
        case .quickActions: .small
        case .topEndpoints: .medium
        case .responseCodes: .small
        case .settingsStatus: .small
        case .logsStream: .large
        }
    }
}

// MARK: - Widget Size

/// Size options for dashboard widgets
enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case small   // 1 column
    case medium  // 2 columns
    case large   // 3 columns (full width)

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    /// Number of grid columns this widget spans
    var columnSpan: Int {
        switch self {
        case .small: 1
        case .medium: 2
        case .large: 3
        }
    }

    var systemImage: String {
        switch self {
        case .small: "square"
        case .medium: "rectangle"
        case .large: "rectangle.fill"
        }
    }
}

// MARK: - Widget Configuration

/// Configuration for a single dashboard widget
struct WidgetConfig: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var type: DashboardWidgetType
    var size: WidgetSize
    var position: Int
    var isVisible: Bool

    init(
        id: UUID = UUID(),
        type: DashboardWidgetType,
        size: WidgetSize? = nil,
        position: Int,
        isVisible: Bool = true
    ) {
        self.id = id
        self.type = type
        self.size = size ?? type.suggestedSize
        self.position = position
        self.isVisible = isVisible
    }
}

// MARK: - Dashboard Layout

/// Complete dashboard layout configuration
struct DashboardLayout: Equatable {
    var widgets: [WidgetConfig]

    /// Default layout with all widgets visible
    static var `default`: DashboardLayout {
        DashboardLayout(widgets: DashboardWidgetType.allCases.enumerated().map { index, type in
            WidgetConfig(type: type, position: index)
        })
    }

    /// Visible widgets sorted by position
    var visibleWidgets: [WidgetConfig] {
        widgets
            .filter { $0.isVisible }
            .sorted { $0.position < $1.position }
    }

    /// Hidden widgets
    var hiddenWidgets: [WidgetConfig] {
        widgets.filter { !$0.isVisible }
    }

    /// Update widget visibility
    mutating func setVisibility(for widgetId: UUID, isVisible: Bool) {
        if let index = widgets.firstIndex(where: { $0.id == widgetId }) {
            widgets[index].isVisible = isVisible
        }
    }

    /// Update widget size
    mutating func setSize(for widgetId: UUID, size: WidgetSize) {
        if let index = widgets.firstIndex(where: { $0.id == widgetId }) {
            widgets[index].size = size
        }
    }

    /// Move widget to new position
    mutating func move(from source: IndexSet, to destination: Int) {
        var visible = visibleWidgets
        visible.move(fromOffsets: source, toOffset: destination)

        // Update positions
        for (index, widget) in visible.enumerated() {
            if let widgetIndex = widgets.firstIndex(where: { $0.id == widget.id }) {
                widgets[widgetIndex].position = index
            }
        }
    }
}

// MARK: - Codable for DashboardLayout
// Explicit Codable implementation to avoid infinite recursion with RawRepresentable

extension DashboardLayout: Codable {
    private enum CodingKeys: String, CodingKey {
        case widgets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        widgets = try container.decode([WidgetConfig].self, forKey: .widgets)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(widgets, forKey: .widgets)
    }
}

// MARK: - RawRepresentable for @AppStorage

extension DashboardLayout: RawRepresentable {
    public init(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let layout = try? JSONDecoder().decode(DashboardLayout.self, from: data) else {
            self = .default
            return
        }
        self = layout
    }

    public var rawValue: String {
        (try? JSONEncoder().encode(self))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

// MARK: - Widget Data Models (for shared views)

/// Data model for server status widget
struct ServerStatusData: Equatable {
    var isOnline: Bool
    var latencyMs: Double?
    var version: String?
    var lastChecked: Date

    static var placeholder: ServerStatusData {
        ServerStatusData(isOnline: true, latencyMs: 42, version: "0.24.0", lastChecked: Date())
    }
}

/// Data model for request volume widget
struct RequestVolumeData: Equatable {
    var dataPoints: [DataPoint]
    var totalRequests: Int

    struct DataPoint: Identifiable, Equatable {
        var date: Date
        var count: Int

        var id: Date { date }
    }

    static let placeholder: RequestVolumeData = {
        let now = Date()
        let counts = [45, 62, 78, 55, 30, 25, 18, 12, 15, 22, 38, 52, 68, 85, 72, 58, 42, 35, 28, 20, 15, 18, 25, 32]
        let points = counts.enumerated().map { hour, count in
            DataPoint(
                date: Calendar.current.date(byAdding: .hour, value: -hour, to: now) ?? now,
                count: count
            )
        }
        return RequestVolumeData(dataPoints: points, totalRequests: points.reduce(0) { $0 + $1.count })
    }()
}

/// Data model for error rate widget
struct ErrorRateData: Equatable {
    var dataPoints: [DataPoint]
    var totalErrors: Int
    var errorRate: Double // percentage

    struct DataPoint: Identifiable, Equatable {
        var date: Date
        var count: Int

        var id: Date { date }
    }

    static let placeholder: ErrorRateData = {
        let now = Date()
        let counts = [2, 1, 0, 3, 1, 0, 0, 1, 2, 0, 1, 0, 2, 3, 1, 0, 1, 0, 0, 1, 2, 1, 0, 1]
        let points = counts.enumerated().map { hour, count in
            DataPoint(
                date: Calendar.current.date(byAdding: .hour, value: -hour, to: now) ?? now,
                count: count
            )
        }
        return ErrorRateData(
            dataPoints: points,
            totalErrors: points.reduce(0) { $0 + $1.count },
            errorRate: 2.5
        )
    }()
}

/// Data model for latency widget
struct LatencyData: Equatable {
    var currentMs: Double
    var averageMs: Double
    var minMs: Double
    var maxMs: Double
    var history: [DataPoint]

    struct DataPoint: Identifiable, Equatable {
        var date: Date
        var latencyMs: Double

        var id: Date { date }
    }

    init(currentMs: Double, averageMs: Double, minMs: Double, maxMs: Double, history: [DataPoint] = []) {
        self.currentMs = currentMs
        self.averageMs = averageMs
        self.minMs = minMs
        self.maxMs = maxMs
        self.history = history
    }

    static let placeholder: LatencyData = {
        let now = Date()
        let latencies: [Double] = [42, 38, 45, 52, 48, 35, 40, 55, 62, 48, 42, 38]
        let history = latencies.enumerated().map { i, latency in
            DataPoint(
                date: Calendar.current.date(byAdding: .minute, value: -i * 5, to: now) ?? now,
                latencyMs: latency
            )
        }.reversed()
        return LatencyData(
            currentMs: 42,
            averageMs: 50,
            minMs: 15,
            maxMs: 120,
            history: Array(history)
        )
    }()

    /// Latency health status based on current value
    var status: LatencyStatus {
        switch currentMs {
        case 0..<50: .excellent
        case 50..<100: .good
        case 100..<200: .fair
        default: .poor
        }
    }

    enum LatencyStatus {
        case excellent, good, fair, poor

        var color: Color {
            switch self {
            case .excellent: .green
            case .good: .blue
            case .fair: .orange
            case .poor: .red
            }
        }

        var label: LocalizedStringKey {
            switch self {
            case .excellent: "Excellent"
            case .good: "Good"
            case .fair: "Fair"
            case .poor: "Poor"
            }
        }
    }
}

/// Data model for collections widget
struct CollectionsData: Equatable {
    var collections: [CollectionCount]

    struct CollectionCount: Identifiable, Equatable {
        var name: String
        var count: Int
        var isSystem: Bool

        var id: String { name }
    }

    static var placeholder: CollectionsData {
        CollectionsData(collections: [
            CollectionCount(name: "users", count: 1234, isSystem: false),
            CollectionCount(name: "posts", count: 5678, isSystem: false),
            CollectionCount(name: "comments", count: 9012, isSystem: false),
            CollectionCount(name: "_superusers", count: 2, isSystem: true)
        ])
    }

    var totalRecords: Int {
        collections.reduce(0) { $0 + $1.count }
    }
}

/// Data model for storage widget
struct StorageData: Equatable {
    var backupCount: Int
    var totalSizeBytes: Int64
    var lastBackupDate: Date?

    static var placeholder: StorageData {
        StorageData(
            backupCount: 5,
            totalSizeBytes: 1024 * 1024 * 150, // 150 MB
            lastBackupDate: Date().addingTimeInterval(-86400)
        )
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
}

/// Data model for recent errors widget
struct RecentErrorsData: Equatable {
    var errors: [ErrorEntry]

    struct ErrorEntry: Identifiable, Equatable {
        let id: String
        var message: String
        var timestamp: Date
        var level: Int
    }

    static var placeholder: RecentErrorsData {
        RecentErrorsData(errors: [
            ErrorEntry(id: "1", message: "Connection timeout", timestamp: Date(), level: 8),
            ErrorEntry(id: "2", message: "Invalid request", timestamp: Date().addingTimeInterval(-3600), level: 8)
        ])
    }
}

/// Data model for error distribution widget (pie chart)
struct ErrorDistributionData: Equatable {
    var categories: [ErrorCategory]

    struct ErrorCategory: Identifiable, Equatable {
        var name: String
        var count: Int
        var color: Color

        var id: String { name }

        static func == (lhs: ErrorCategory, rhs: ErrorCategory) -> Bool {
            lhs.name == rhs.name && lhs.count == rhs.count
        }
    }

    var totalErrors: Int {
        categories.reduce(0) { $0 + $1.count }
    }

    static var placeholder: ErrorDistributionData {
        ErrorDistributionData(categories: [
            ErrorCategory(name: "Network", count: 12, color: .red),
            ErrorCategory(name: "Auth", count: 8, color: .orange),
            ErrorCategory(name: "Validation", count: 5, color: .yellow),
            ErrorCategory(name: "Server", count: 3, color: .purple)
        ])
    }
}

/// Data model for top endpoints widget (bar chart)
struct TopEndpointsData: Equatable {
    var endpoints: [EndpointStat]

    struct EndpointStat: Identifiable, Equatable {
        var method: String
        var path: String
        var count: Int

        var id: String { "\(method):\(path)" }

        var displayName: String {
            "\(method) \(path)"
        }
    }

    var totalRequests: Int {
        endpoints.reduce(0) { $0 + $1.count }
    }

    static let placeholder = TopEndpointsData(endpoints: [
        EndpointStat(method: "GET", path: "/api/collections/users/records", count: 245),
        EndpointStat(method: "POST", path: "/api/collections/posts/records", count: 128),
        EndpointStat(method: "GET", path: "/api/collections/posts/records", count: 98),
        EndpointStat(method: "PATCH", path: "/api/collections/users/records", count: 45),
        EndpointStat(method: "DELETE", path: "/api/collections/posts/records", count: 12)
    ])
}

/// Data model for response codes widget (pie chart)
struct ResponseCodesData: Equatable {
    var codes: [CodeStat]

    struct CodeStat: Identifiable, Equatable {
        var statusGroup: String // "2xx", "3xx", "4xx", "5xx"
        var count: Int
        var color: Color

        var id: String { statusGroup }

        static func == (lhs: CodeStat, rhs: CodeStat) -> Bool {
            lhs.statusGroup == rhs.statusGroup && lhs.count == rhs.count
        }
    }

    var totalRequests: Int {
        codes.reduce(0) { $0 + $1.count }
    }

    static let placeholder = ResponseCodesData(codes: [
        CodeStat(statusGroup: "2xx", count: 850, color: .green),
        CodeStat(statusGroup: "3xx", count: 45, color: .blue),
        CodeStat(statusGroup: "4xx", count: 80, color: .orange),
        CodeStat(statusGroup: "5xx", count: 25, color: .red)
    ])
}

/// Data model for settings status widget
struct SettingsStatusData: Equatable {
    var smtpEnabled: Bool
    var s3Enabled: Bool
    var backupsEnabled: Bool
    var backupCron: String?
    var appName: String?
    var appUrl: String?

    static let placeholder = SettingsStatusData(
        smtpEnabled: true,
        s3Enabled: false,
        backupsEnabled: true,
        backupCron: "0 0 * * *",
        appName: "My App",
        appUrl: "https://example.com"
    )
}

/// Data model for logs stream widget
struct LogsStreamData: Equatable {
    var logs: [LogEntry]

    struct LogEntry: Identifiable, Equatable {
        let id: String
        var message: String
        var timestamp: Date
        var level: Int
        var method: String?
        var url: String?
        var status: Int?

        var levelColor: Color {
            switch level {
            case ..<0: .gray      // DEBUG
            case 0..<4: .blue     // INFO
            case 4..<8: .orange   // WARN
            default: .red         // ERROR
            }
        }

        var levelName: String {
            switch level {
            case ..<0: "DEBUG"
            case 0..<4: "INFO"
            case 4..<8: "WARN"
            default: "ERROR"
            }
        }
    }

    static let placeholder = LogsStreamData(logs: [
        LogEntry(id: "1", message: "GET /api/collections/users/records", timestamp: Date(), level: 0, method: "GET", url: "/api/collections/users/records", status: 200),
        LogEntry(id: "2", message: "POST /api/collections/posts/records", timestamp: Date().addingTimeInterval(-60), level: 0, method: "POST", url: "/api/collections/posts/records", status: 200),
        LogEntry(id: "3", message: "Authentication failed", timestamp: Date().addingTimeInterval(-120), level: 4, method: "POST", url: "/api/collections/users/auth-with-password", status: 401),
        LogEntry(id: "4", message: "GET /api/health", timestamp: Date().addingTimeInterval(-180), level: 0, method: "GET", url: "/api/health", status: 200)
    ])
}
