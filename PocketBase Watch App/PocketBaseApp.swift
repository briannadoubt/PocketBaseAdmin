//
//  PocketBaseApp.swift
//  PocketBase Watch App
//
//  Created by Brianna Zamora on 7/2/25.
//

import SwiftUI
import WatchKit
import UserNotifications
import PocketBaseIntents

@main
struct PocketBaseApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - App Delegate for Background Tasks

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Schedule background refresh
        scheduleBackgroundRefresh()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                // Perform background health check
                Task {
                    await performBackgroundHealthCheck()
                    scheduleBackgroundRefresh()
                    refreshTask.setTaskCompletedWithSnapshot(false)
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: .distantFuture, userInfo: nil)

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    private func scheduleBackgroundRefresh() {
        // Schedule next refresh in 30 minutes
        let targetDate = Date().addingTimeInterval(30 * 60)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: targetDate, userInfo: nil) { error in
            if let error {
                print("Failed to schedule background refresh: \(error)")
            }
        }
    }

    @MainActor
    private func performBackgroundHealthCheck() async {
        // Check server status
        let status = await IntentHelpers.fetchServerStatus()

        // Get the previous status from UserDefaults
        let wasOnline = UserDefaults.standard.bool(forKey: "lastServerStatus")
        UserDefaults.standard.set(status.isOnline, forKey: "lastServerStatus")

        // If status changed, send local notification
        if wasOnline != status.isOnline {
            let content = UNMutableNotificationContent()
            if status.isOnline {
                content.title = "PocketBase Online"
                content.body = "Your server is back online"
            } else {
                content.title = "PocketBase Offline"
                content.body = "Your server is not responding"
            }
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
