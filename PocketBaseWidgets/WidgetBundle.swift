//
//  WidgetBundle.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI

@main
struct PocketBaseWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Small widgets
        ServerStatusWidget()
        ErrorCountWidget()
        BackupStatusWidget()

        // Medium widgets
        StatsWidget()
        QuickActionsWidget()

        // Large widgets
        RecentLogsWidget()
        CollectionsListWidget()
    }
}
