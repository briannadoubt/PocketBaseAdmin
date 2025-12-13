//
//  BackupsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct BackupsView: View {
    @State private var showOptions = false
    @State private var autoBackupEnabled = false
    @State private var s3StorageEnabled = false
    @State private var showNewBackupSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                Text("Backup and restore your PocketBase data")
                    .font(.title2).fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Backups Card
                VStack(spacing: 0) {
                    Text("No backups yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                        .padding(.vertical, 12)
                    Divider()
                    Button(action: { showNewBackupSheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle")
                                .font(.title2)
                            Text("Initialize new backup")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }.buttonStyle(.plain)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.gray.opacity(0.25), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.secondary.opacity(0.15))
                        )
                )
                .padding(.horizontal)
                
                Divider().padding(.horizontal)
                
                // Options Section
                VStack(alignment: .leading, spacing: 20) {
                    DisclosureGroup(isExpanded: $showOptions) {
                        VStack(alignment: .leading, spacing: 24) {
                            Toggle(isOn: $autoBackupEnabled) {
                                Text("Enable auto backups")
                            }
                            Toggle(isOn: $s3StorageEnabled) {
                                Text("Store backups in S3 storage")
                            }
                            HStack {
                                Spacer()
                                Button("Save changes") {}
                                    .disabled(true)
                                    .padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(.secondary.opacity(0.15))
                                    .foregroundColor(.gray)
                                    .cornerRadius(7)
                            }
                        }
                        .padding(.top, 16)
                    } label: {
                        Text("Backups options")
                            .font(.headline)
                            .padding(.vertical, 10)
                    }
                    .accentColor(.primary)
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.secondary.opacity(0.15))
                    )
                }
                .padding(.horizontal)
                Spacer(minLength: 24)
            }
            .padding(.vertical, 32)
        }
        .navigationTitle("Backups")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {/* refresh action */}) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                Button(action: {/* upload action */}) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showNewBackupSheet) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Initialize new backup")
                        .font(.title2).fontWeight(.semibold)
                    Spacer()
                    Button(action: { showNewBackupSheet = false }) {
                        Image(systemName: "xmark")
                            .padding(8)
                    }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Please note that during the backup other concurrent write requests may fail since the database will be temporary \"locked\" (this usually happens only during the ZIP generation).\n\n**If you are using S3 storage for the collections file upload, you'll have to backup them separately since they are not locally stored and will not be included in the final backup!**")
                            .font(.callout)
                            .foregroundColor(.primary)
                    }
                    .padding(12)
                    .background(.secondary.opacity(0.10))
                    .cornerRadius(8)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showNewBackupSheet = false
                    }
                    .padding(.trailing, 16)
                    Button("Start backup") {}
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
            .presentationDetents([.medium, .large])
        }
    }
}

