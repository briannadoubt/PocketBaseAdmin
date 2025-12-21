//
//  DashboardState.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin
import OSLog

/// Observable state for the dashboard, managing layout and data loading
@Observable
@MainActor
final class DashboardState {
    // MARK: - Layout

    /// Dashboard layout configuration (persisted separately via @AppStorage)
    var layout: DashboardLayout = .default

    /// Whether the dashboard is in edit mode
    var isEditMode: Bool = false

    // MARK: - Loading States

    var isLoading: Bool = false
    var lastRefresh: Date?
    var error: String?

    // MARK: - Widget Data

    var serverStatus: ServerStatusData?
    var requestVolume: RequestVolumeData?
    var errorRate: ErrorRateData?
    var errorDistribution: ErrorDistributionData?
    var latency: LatencyData?
    var latencyHistory: [LatencyData.DataPoint] = []
    var collections: CollectionsData?
    var storage: StorageData?
    var recentErrors: RecentErrorsData?
    // New widget data
    var topEndpoints: TopEndpointsData?
    var responseCodes: ResponseCodesData?
    var settingsStatus: SettingsStatusData?
    var logsStream: LogsStreamData?

    // MARK: - Private

    private let logger = Logger(subsystem: "PocketBaseAdminApp", category: "DashboardState")

    // MARK: - Initialization

    init(layout: DashboardLayout = .default) {
        self.layout = layout
    }

    // MARK: - Data Loading

    /// Load all dashboard data from PocketBase
    func loadAllData(pocketbase: PocketBase) async {
        isLoading = true
        error = nil

        // Load all data concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadServerStatus(pocketbase: pocketbase) }
            group.addTask { await self.loadRequestVolume(pocketbase: pocketbase) }
            group.addTask { await self.loadErrorRate(pocketbase: pocketbase) }
            group.addTask { await self.loadErrorDistribution(pocketbase: pocketbase) }
            group.addTask { await self.loadCollections(pocketbase: pocketbase) }
            group.addTask { await self.loadStorage(pocketbase: pocketbase) }
            group.addTask { await self.loadRecentErrors(pocketbase: pocketbase) }
            // New widgets
            group.addTask { await self.loadTopEndpoints(pocketbase: pocketbase) }
            group.addTask { await self.loadResponseCodes(pocketbase: pocketbase) }
            group.addTask { await self.loadSettingsStatus(pocketbase: pocketbase) }
            group.addTask { await self.loadLogsStream(pocketbase: pocketbase) }
        }

        lastRefresh = Date()
        isLoading = false
    }

    /// Refresh a specific widget's data
    func refresh(widget: DashboardWidgetType, pocketbase: PocketBase) async {
        switch widget {
        case .serverStatus:
            await loadServerStatus(pocketbase: pocketbase)
        case .requestVolume:
            await loadRequestVolume(pocketbase: pocketbase)
        case .errorRate:
            await loadErrorRate(pocketbase: pocketbase)
        case .errorDistribution:
            await loadErrorDistribution(pocketbase: pocketbase)
        case .latency:
            await loadServerStatus(pocketbase: pocketbase) // Latency comes from health check
        case .collections:
            await loadCollections(pocketbase: pocketbase)
        case .storage:
            await loadStorage(pocketbase: pocketbase)
        case .recentErrors:
            await loadRecentErrors(pocketbase: pocketbase)
        case .quickActions:
            break // No data to load for quick actions
        case .topEndpoints:
            await loadTopEndpoints(pocketbase: pocketbase)
        case .responseCodes:
            await loadResponseCodes(pocketbase: pocketbase)
        case .settingsStatus:
            await loadSettingsStatus(pocketbase: pocketbase)
        case .logsStream:
            await loadLogsStream(pocketbase: pocketbase)
        }
    }

    // MARK: - Individual Data Loaders

    private func loadServerStatus(pocketbase: PocketBase) async {
        let startTime = Date()
        do {
            let health = try await pocketbase.admin.health.check()
            let latencyMs = Date().timeIntervalSince(startTime) * 1000

            serverStatus = ServerStatusData(
                isOnline: health.code == 200,
                latencyMs: latencyMs,
                version: health.data.version,
                lastChecked: Date()
            )

            // Add to latency history (keep last 12 data points)
            let newPoint = LatencyData.DataPoint(date: Date(), latencyMs: latencyMs)
            latencyHistory.append(newPoint)
            if latencyHistory.count > 12 {
                latencyHistory.removeFirst()
            }

            // Calculate stats from history
            let historyValues = latencyHistory.map(\.latencyMs)
            let avgMs = historyValues.reduce(0, +) / Double(max(historyValues.count, 1))
            let minMs = historyValues.min() ?? latencyMs
            let maxMs = historyValues.max() ?? latencyMs

            latency = LatencyData(
                currentMs: latencyMs,
                averageMs: avgMs,
                minMs: minMs,
                maxMs: maxMs,
                history: latencyHistory
            )
        } catch {
            logger.error("Failed to load server status: \(error.localizedDescription)")
            serverStatus = ServerStatusData(
                isOnline: false,
                latencyMs: nil,
                version: nil,
                lastChecked: Date()
            )
        }
    }

    private func loadRequestVolume(pocketbase: PocketBase) async {
        do {
            let stats = try await pocketbase.admin.logs.stats()
            let dataPoints = stats.map { stat in
                RequestVolumeData.DataPoint(date: stat.date, count: stat.total)
            }
            requestVolume = RequestVolumeData(
                dataPoints: dataPoints,
                totalRequests: dataPoints.reduce(0) { $0 + $1.count }
            )
        } catch {
            logger.error("Failed to load request volume: \(error.localizedDescription)")
        }
    }

    private func loadErrorRate(pocketbase: PocketBase) async {
        do {
            // Fetch error logs (level >= 8 indicates errors)
            let errorLogs = try await pocketbase.admin.logs.list(
                page: 1,
                perPage: 100,
                filter: "level >= 8"
            ).items

            // Group errors by hour for the chart
            let calendar = Calendar.current
            var hourlyErrors: [Date: Int] = [:]

            for log in errorLogs {
                let hour = calendar.startOfHour(for: log.created)
                hourlyErrors[hour, default: 0] += 1
            }

            let dataPoints = hourlyErrors.map { date, count in
                ErrorRateData.DataPoint(date: date, count: count)
            }.sorted { $0.date < $1.date }

            // Calculate error rate (errors per total requests)
            let totalErrors = errorLogs.count
            let totalRequests = requestVolume?.totalRequests ?? 1
            let rate = Double(totalErrors) / Double(max(totalRequests, 1)) * 100

            errorRate = ErrorRateData(
                dataPoints: dataPoints,
                totalErrors: totalErrors,
                errorRate: rate
            )
        } catch {
            logger.error("Failed to load error rate: \(error.localizedDescription)")
        }
    }

    private func loadErrorDistribution(pocketbase: PocketBase) async {
        do {
            let errorLogs = try await pocketbase.admin.logs.list(
                page: 1,
                perPage: 200,
                filter: "level >= 8"
            ).items

            // Group errors by message type/category
            var categoryMap: [String: Int] = [:]
            for log in errorLogs {
                let category = categorizeError(message: log.message)
                categoryMap[category, default: 0] += 1
            }

            // Convert to categories with colors
            let colors: [Color] = [.red, .orange, .yellow, .purple, .pink, .indigo]
            let categories = categoryMap.sorted { $0.value > $1.value }
                .prefix(6) // Top 6 categories
                .enumerated()
                .map { index, item in
                    ErrorDistributionData.ErrorCategory(
                        name: item.key,
                        count: item.value,
                        color: colors[index % colors.count]
                    )
                }

            errorDistribution = ErrorDistributionData(categories: categories)
        } catch {
            logger.error("Failed to load error distribution: \(error.localizedDescription)")
        }
    }

    /// Categorize an error message into a high-level category
    private func categorizeError(message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("timeout") || lowercased.contains("connection") || lowercased.contains("network") {
            return "Network"
        } else if lowercased.contains("auth") || lowercased.contains("unauthorized") || lowercased.contains("forbidden") {
            return "Auth"
        } else if lowercased.contains("valid") || lowercased.contains("required") || lowercased.contains("missing") {
            return "Validation"
        } else if lowercased.contains("not found") || lowercased.contains("404") {
            return "Not Found"
        } else if lowercased.contains("server") || lowercased.contains("internal") || lowercased.contains("500") {
            return "Server"
        } else {
            return "Other"
        }
    }

    private func loadCollections(pocketbase: PocketBase) async {
        do {
            let collectionsList = try await pocketbase.admin.collections.list().items

            // Get record counts for each collection
            var collectionCounts: [CollectionsData.CollectionCount] = []

            for collection in collectionsList {
                do {
                    // Use the admin records API to get count
                    let result = try await pocketbase.admin
                        .records(collection.name)
                        .list(page: 1, perPage: 1)
                    collectionCounts.append(CollectionsData.CollectionCount(
                        name: collection.name,
                        count: result.totalItems,
                        isSystem: collection.system
                    ))
                } catch {
                    // If we can't get the count, still include the collection with 0
                    collectionCounts.append(CollectionsData.CollectionCount(
                        name: collection.name,
                        count: 0,
                        isSystem: collection.system
                    ))
                }
            }

            collections = CollectionsData(collections: collectionCounts.sorted { $0.count > $1.count })
        } catch {
            logger.error("Failed to load collections: \(error.localizedDescription)")
        }
    }

    private func loadStorage(pocketbase: PocketBase) async {
        do {
            let backups = try await pocketbase.admin.backups.list()

            let totalSize = backups.reduce(Int64(0)) { $0 + Int64($1.size) }
            let lastBackup = backups.max(by: { $0.modified < $1.modified })

            storage = StorageData(
                backupCount: backups.count,
                totalSizeBytes: totalSize,
                lastBackupDate: lastBackup?.modified
            )
        } catch {
            logger.error("Failed to load storage: \(error.localizedDescription)")
        }
    }

    private func loadRecentErrors(pocketbase: PocketBase) async {
        do {
            // Logs are returned in descending order by default (newest first)
            let errorLogs = try await pocketbase.admin.logs.list(
                page: 1,
                perPage: 10,
                filter: "level >= 8"
            ).items

            let errors = errorLogs.map { log in
                RecentErrorsData.ErrorEntry(
                    id: log.id,
                    message: log.message,
                    timestamp: log.created,
                    level: log.level.numericValue
                )
            }

            recentErrors = RecentErrorsData(errors: errors)
        } catch {
            logger.error("Failed to load recent errors: \(error.localizedDescription)")
        }
    }

    private func loadTopEndpoints(pocketbase: PocketBase) async {
        do {
            // Fetch recent logs to aggregate by endpoint
            let logs = try await pocketbase.admin.logs.list(
                page: 1,
                perPage: 500
            ).items

            // Aggregate by method + URL
            var endpointCounts: [String: (method: String, path: String, count: Int)] = [:]
            for log in logs {
                guard let method = log.data.method,
                      let url = log.data.url else { continue }

                // Simplify URL to path pattern (remove query params and IDs)
                let path = simplifyPath(url)
                let key = "\(method) \(path)"

                if var existing = endpointCounts[key] {
                    existing.count += 1
                    endpointCounts[key] = existing
                } else {
                    endpointCounts[key] = (method: method, path: path, count: 1)
                }
            }

            // Sort by count and take top 5
            let sorted = endpointCounts.values
                .sorted { $0.count > $1.count }
                .prefix(5)
                .map { TopEndpointsData.EndpointStat(method: $0.method, path: $0.path, count: $0.count) }

            topEndpoints = TopEndpointsData(endpoints: Array(sorted))
        } catch {
            logger.error("Failed to load top endpoints: \(error.localizedDescription)")
        }
    }

    /// Simplify URL path by removing specific IDs
    private func simplifyPath(_ url: String) -> String {
        // Remove query parameters
        let path = url.components(separatedBy: "?").first ?? url
        // Replace UUIDs and numeric IDs with placeholder
        let pattern = try? NSRegularExpression(pattern: "[a-f0-9]{15,}|\\d{10,}", options: .caseInsensitive)
        let range = NSRange(path.startIndex..., in: path)
        return pattern?.stringByReplacingMatches(in: path, options: [], range: range, withTemplate: ":id") ?? path
    }

    private func loadResponseCodes(pocketbase: PocketBase) async {
        do {
            let logs = try await pocketbase.admin.logs.list(
                page: 1,
                perPage: 500
            ).items

            // Aggregate by status code group
            var codeCounts: [String: Int] = ["2xx": 0, "3xx": 0, "4xx": 0, "5xx": 0]
            for log in logs {
                guard let status = log.data.status else { continue }
                let group: String
                switch status {
                case 200..<300: group = "2xx"
                case 300..<400: group = "3xx"
                case 400..<500: group = "4xx"
                case 500..<600: group = "5xx"
                default: continue
                }
                codeCounts[group, default: 0] += 1
            }

            let colors: [String: Color] = ["2xx": .green, "3xx": .blue, "4xx": .orange, "5xx": .red]
            let codes = codeCounts
                .filter { $0.value > 0 }
                .map { ResponseCodesData.CodeStat(statusGroup: $0.key, count: $0.value, color: colors[$0.key] ?? .gray) }
                .sorted { $0.statusGroup < $1.statusGroup }

            responseCodes = ResponseCodesData(codes: codes)
        } catch {
            logger.error("Failed to load response codes: \(error.localizedDescription)")
        }
    }

    private func loadSettingsStatus(pocketbase: PocketBase) async {
        do {
            let settings = try await pocketbase.admin.settings.get()

            settingsStatus = SettingsStatusData(
                smtpEnabled: settings.smtp?.enabled ?? false,
                s3Enabled: settings.s3?.enabled ?? false,
                backupsEnabled: !(settings.backups?.cron?.isEmpty ?? true),
                backupCron: settings.backups?.cron,
                appName: settings.meta?.appName,
                appUrl: settings.meta?.appUrl
            )
        } catch {
            logger.error("Failed to load settings status: \(error.localizedDescription)")
        }
    }

    private func loadLogsStream(pocketbase: PocketBase) async {
        do {
            // Fetch all recent logs (not just errors)
            let logs = try await pocketbase.admin.logs.list(
                page: 1,
                perPage: 20
            ).items

            let entries = logs.map { log in
                LogsStreamData.LogEntry(
                    id: log.id,
                    message: log.message,
                    timestamp: log.created,
                    level: log.level.numericValue,
                    method: log.data.method,
                    url: log.data.url,
                    status: log.data.status
                )
            }

            logsStream = LogsStreamData(logs: entries)
        } catch {
            logger.error("Failed to load logs stream: \(error.localizedDescription)")
        }
    }

    // MARK: - Layout Management

    func toggleVisibility(for widgetId: UUID) {
        layout.setVisibility(
            for: widgetId,
            isVisible: !(layout.widgets.first { $0.id == widgetId }?.isVisible ?? true)
        )
    }

    func setSize(for widgetId: UUID, size: WidgetSize) {
        layout.setSize(for: widgetId, size: size)
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        layout.move(from: source, to: destination)
    }

    func resetToDefault() {
        layout = .default
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
    }
}
