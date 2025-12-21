//
//  ServerStatusWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI

/// Server status widget showing health indicator and version info
struct ServerStatusWidgetView: View {
    let data: ServerStatusData

    var body: some View {
        VStack(spacing: 12) {
            // Status icon
            Image(systemName: data.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(data.isOnline ? .green : .red)

            // Status text
            Text(data.isOnline ? "Online" : "Offline")
                .font(.headline)
                .foregroundStyle(data.isOnline ? .green : .red)

            // Details
            VStack(spacing: 4) {
                if let latency = data.latencyMs {
                    Text("\(Int(latency))ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let version = data.version {
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(data.lastChecked, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ServerStatusWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
