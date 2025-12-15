//
//  BackupResultView.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// Visual snippet view for backup operations shown in Siri/Shortcuts
public struct BackupResultView: View {
    public let backup: BackupEntity

    public init(backup: BackupEntity) {
        self.backup = backup
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(backup.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(backup.created.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

/// Visual snippet view for backup list shown in Siri/Shortcuts
public struct BackupListView: View {
    public let backups: [BackupEntity]

    public init(backups: [BackupEntity]) {
        self.backups = backups
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .foregroundStyle(.blue)
                Text("\(backups.count) Backups")
                    .font(.headline)
                Spacer()
            }

            if backups.isEmpty {
                Text("No backups found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(backups.prefix(5), id: \.id) { backup in
                    HStack {
                        Text(backup.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if backups.count > 5 {
                    Text("+ \(backups.count - 5) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}
