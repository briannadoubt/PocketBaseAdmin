//
//  BackgroundTaskManager.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import UserNotifications
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
#if canImport(PocketBaseIntents)
import PocketBaseIntents
#endif

/// Manages background tasks and notifications for the PocketBase admin app
@MainActor
public final class BackgroundTaskManager {
    public static let shared = BackgroundTaskManager()

    private let logger = Logger(subsystem: "PocketBaseAdminApp", category: "BackgroundTaskManager")

    // Task identifiers
    private let healthCheckTaskIdentifier = "com.briannadoubt.PocketBaseAdmin.healthcheck"
    private let backupReminderTaskIdentifier = "com.briannadoubt.PocketBaseAdmin.backupreminder"

    // Notification identifiers
    public enum NotificationCategory: String {
        case serverDown = "SERVER_DOWN"
        case serverRecovered = "SERVER_RECOVERED"
        case backupReminder = "BACKUP_REMINDER"
        case errorAlert = "ERROR_ALERT"
    }

    public enum NotificationAction: String {
        case checkNow = "CHECK_NOW"
        case createBackup = "CREATE_BACKUP"
        case viewLogs = "VIEW_LOGS"
        case dismiss = "DISMISS"
    }

    // Last known state
    private var lastKnownOnlineStatus: Bool?
    private var lastBackupDate: Date?

    private init() {}

    // MARK: - Setup

    /// Register background tasks - call this on app launch
    public func registerBackgroundTasks() {
        #if canImport(BackgroundTasks) && !os(macOS)
        // Register health check task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: healthCheckTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                guard let refreshTask = task as? BGAppRefreshTask else {
                    self.logger.error("Health check task received unexpected task type")
                    task.setTaskCompleted(success: false)
                    return
                }
                await self.handleHealthCheckTask(refreshTask)
            }
        }

        // Register backup reminder task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backupReminderTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                guard let refreshTask = task as? BGAppRefreshTask else {
                    self.logger.error("Backup reminder task received unexpected task type")
                    task.setTaskCompleted(success: false)
                    return
                }
                await self.handleBackupReminderTask(refreshTask)
            }
        }

        // Schedule initial tasks
        scheduleHealthCheck()
        scheduleBackupReminder()
        #endif
    }

    /// Request notification permissions and register categories
    public func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await registerNotificationCategories()
            }
        } catch {
            logger.error("Notification permission error: \(error.localizedDescription)")
        }
    }

    private func registerNotificationCategories() async {
        let center = UNUserNotificationCenter.current()

        // Server Down category
        let checkNowAction = UNNotificationAction(
            identifier: NotificationAction.checkNow.rawValue,
            title: "Check Again",
            options: .foreground
        )
        let serverDownCategory = UNNotificationCategory(
            identifier: NotificationCategory.serverDown.rawValue,
            actions: [checkNowAction],
            intentIdentifiers: [],
            options: []
        )

        // Backup Reminder category
        let createBackupAction = UNNotificationAction(
            identifier: NotificationAction.createBackup.rawValue,
            title: "Create Backup",
            options: .foreground
        )
        let backupReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.backupReminder.rawValue,
            actions: [createBackupAction],
            intentIdentifiers: [],
            options: []
        )

        // Error Alert category
        let viewLogsAction = UNNotificationAction(
            identifier: NotificationAction.viewLogs.rawValue,
            title: "View Logs",
            options: .foreground
        )
        let errorAlertCategory = UNNotificationCategory(
            identifier: NotificationCategory.errorAlert.rawValue,
            actions: [viewLogsAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            serverDownCategory,
            backupReminderCategory,
            errorAlertCategory
        ])
    }

    // MARK: - Background Tasks

    #if canImport(BackgroundTasks) && !os(macOS)
    private func handleHealthCheckTask(_ task: BGAppRefreshTask) async {
        // Schedule the next health check
        scheduleHealthCheck()

        // Set up expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Perform health check
        do {
            #if canImport(PocketBaseIntents)
            let client = try await ServerConfiguration.shared.getClient()
            let health = try await client.admin.health.check()
            let isOnline = health.code == 200

            // Check for status change
            if let lastStatus = lastKnownOnlineStatus {
                if !isOnline && lastStatus {
                    // Server went down
                    await sendServerDownNotification()
                } else if isOnline && !lastStatus {
                    // Server recovered
                    await sendServerRecoveredNotification()
                }
            }

            lastKnownOnlineStatus = isOnline

            // Refresh widgets
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif

            task.setTaskCompleted(success: true)
            #else
            task.setTaskCompleted(success: true)
            #endif
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    private func handleBackupReminderTask(_ task: BGAppRefreshTask) async {
        // Schedule the next reminder
        scheduleBackupReminder()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Check last backup date
        do {
            #if canImport(PocketBaseIntents)
            let client = try await ServerConfiguration.shared.getClient()
            let backups = try await client.admin.backups.list()

            if let latestBackup = backups.sorted(by: { $0.modified > $1.modified }).first {
                let hoursSinceBackup = Date().timeIntervalSince(latestBackup.modified) / 3600

                // Send reminder if no backup in 72 hours
                if hoursSinceBackup > 72 {
                    await sendBackupReminderNotification(lastBackup: latestBackup.modified)
                }
            } else {
                // No backups at all
                await sendBackupReminderNotification(lastBackup: nil)
            }

            task.setTaskCompleted(success: true)
            #else
            task.setTaskCompleted(success: true)
            #endif
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    /// Schedule the next health check background task
    public func scheduleHealthCheck() {
        let request = BGAppRefreshTaskRequest(identifier: healthCheckTaskIdentifier)
        // Check every 15 minutes
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule health check: \(error.localizedDescription)")
        }
    }

    /// Schedule the next backup reminder background task
    public func scheduleBackupReminder() {
        let request = BGAppRefreshTaskRequest(identifier: backupReminderTaskIdentifier)
        // Check every 24 hours
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule backup reminder: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Notifications

    /// Send a notification that the server is down
    public func sendServerDownNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "PocketBase Server Down"
        content.body = "Your PocketBase server is not responding. Tap to check again."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.serverDown.rawValue

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to send server down notification: \(error.localizedDescription)")
        }
    }

    /// Send a notification that the server has recovered
    public func sendServerRecoveredNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "PocketBase Server Online"
        content.body = "Your PocketBase server is back online."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.serverRecovered.rawValue

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to send server recovered notification: \(error.localizedDescription)")
        }
    }

    /// Send a backup reminder notification
    public func sendBackupReminderNotification(lastBackup: Date?) async {
        let content = UNMutableNotificationContent()
        content.title = "Backup Reminder"

        if let lastBackup {
            let formatter = RelativeDateTimeFormatter()
            let timeAgo = formatter.localizedString(for: lastBackup, relativeTo: Date())
            content.body = "Your last backup was \(timeAgo). Consider creating a new backup."
        } else {
            content.body = "You haven't created any backups yet. Consider creating one now."
        }

        content.sound = .default
        content.categoryIdentifier = NotificationCategory.backupReminder.rawValue

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to send backup reminder notification: \(error.localizedDescription)")
        }
    }

    /// Send an error alert notification
    public func sendErrorAlertNotification(errorCount: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "PocketBase Errors Detected"
        content.body = "\(errorCount) errors in the last 24 hours. Tap to view logs."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.errorAlert.rawValue
        content.badge = NSNumber(value: errorCount)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to send error alert notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Manual Triggers

    /// Manually trigger a health check and update widgets
    public func performHealthCheckNow() async {
        do {
            #if canImport(PocketBaseIntents)
            let client = try await ServerConfiguration.shared.getClient()
            let health = try await client.admin.health.check()
            lastKnownOnlineStatus = health.code == 200
            #endif

            // Refresh widgets
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            lastKnownOnlineStatus = false
        }
    }

    /// Clear the app badge
    public func clearBadge() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

// MARK: - Notification Delegate Extension

extension BackgroundTaskManager {
    /// Handle notification action responses
    public func handleNotificationAction(_ action: NotificationAction) async {
        switch action {
        case .checkNow:
            await performHealthCheckNow()
        case .createBackup:
            #if canImport(PocketBaseIntents)
            do {
                let intent = CreateBackupIntent()
                _ = try await intent.perform()
            } catch {
                logger.error("Failed to create backup from notification: \(error.localizedDescription)")
            }
            #endif
        case .viewLogs:
            // This will be handled by the app's deep linking
            break
        case .dismiss:
            break
        }
    }
}
