//
//  StatusView.swift
//  PocketBase Watch App
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import WatchKit
import PocketBaseIntents

struct StatusView: View {
    @State private var isOnline = true
    @State private var latency: TimeInterval?
    @State private var lastChecked = Date()
    @State private var isRefreshing = false
    @State private var collectionsCount = 0
    @State private var errorsCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Status indicator
                statusCard

                // Quick stats
                statsRow

                // Last checked
                Text("Updated \(lastChecked, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Status")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .task {
            await refresh()
        }
    }

    private var statusCard: some View {
        VStack(spacing: 8) {
            Image(systemName: isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(isOnline ? .green : .red)

            Text(isOnline ? "Online" : "Offline")
                .font(.headline)

            if let latency {
                Text("\(Int(latency * 1000))ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatBadge(value: collectionsCount, label: "Collections", icon: "rectangle.stack")
            StatBadge(value: errorsCount, label: "Errors", icon: "exclamationmark.circle", color: errorsCount > 0 ? .red : .green)
        }
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Haptic feedback
        WKInterfaceDevice.current().play(.start)

        // Fetch stats using IntentHelpers
        let stats = await IntentHelpers.fetchStats()

        isOnline = stats.serverStatus.isOnline
        latency = stats.serverStatus.latency
        lastChecked = stats.serverStatus.checkedAt
        collectionsCount = stats.collectionsCount
        errorsCount = stats.errorCount

        // Success haptic
        WKInterfaceDevice.current().play(.success)
    }
}

struct StatBadge: View {
    let value: Int
    let label: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

#Preview {
    NavigationStack {
        StatusView()
    }
}
