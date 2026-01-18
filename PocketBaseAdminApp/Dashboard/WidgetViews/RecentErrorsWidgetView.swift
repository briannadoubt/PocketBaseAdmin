//
//  RecentErrorsWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI

/// Recent errors widget showing a list of recent error logs
struct RecentErrorsWidgetView: View {
    let data: RecentErrorsData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Errors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(data.errors.count)")
                        .font(.title2.bold())
                }
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
            }

            // Error list
            if data.errors.isEmpty {
                ContentUnavailableView {
                    Label("No Errors", systemImage: "checkmark.circle")
                } description: {
                    Text("No recent errors found")
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(data.errors.prefix(5)) { error in
                        ErrorRow(error: error)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ErrorRow: View {
    let error: RecentErrorsData.ErrorEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.message)
                    .font(.caption)
                    .lineLimit(2)

                Text(error.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    RecentErrorsWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
