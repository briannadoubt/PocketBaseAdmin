//
//  ServerStatusSnippetView.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// Visual snippet view for server status shown in Siri/Shortcuts
public struct ServerStatusSnippetView: View {
    public let status: ServerStatusEntity

    public init(status: ServerStatusEntity) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title)
                .foregroundStyle(status.isOnline ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.isOnline ? "Server Online" : "Server Offline")
                    .font(.headline)

                if let latency = status.latency {
                    Text("\(Int(latency * 1000))ms response time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let version = status.version {
                    Text(version)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}
