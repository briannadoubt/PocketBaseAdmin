//
//  FilesSettingsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI

struct FilesSettingsView: View {
    @State private var useS3Storage = false
    
    @State private var endpoint = ""
    @State private var bucket = ""
    @State private var region = ""
    @State private var accessKey = ""
    @State private var secret = ""
    
    @State private var forcePathStyleAddressing = false
    
    var body: some View {
        ScrollView {
            Form {
                Text("By default PocketBase uses the local file system to store uploaded files.")
                    .listRowSeparator(.hidden)
                Text("If you have limited disk space, you could optionally connect to an S3 compatible storage.")
                    .listRowSeparator(.hidden)
                Section {
                    Toggle("Use S3 storage", isOn: $useS3Storage)
                }
                if useS3Storage {
                    Section {
                        HStack {
                            Text("If you have existing uploaded files, you'll have to migrate them manually from the local file system to the S3 storage.")
                            Text("There are numerous command line tools that can help you, such as: [rclone](https://github.com/rclone/rclone), [s5cmd](https://github.com/peak/s5cmd), etc.")
                        }
                        .listRowBackground(Color.orange)
                    }
                    Section {
                        TextField("Endpoint", text: $endpoint)
                        TextField("Bucket", text: $bucket)
                        TextField("Region", text: $region)
                        TextField("Access key", text: $accessKey)
                        TextField("Secret", text: $secret)
                    }
                    Section {
                        Toggle(isOn: $forcePathStyleAddressing) {
                            Text("Force path-style addressing")
                        }
                    }
                }
            }
        }
        .navigationTitle("Files storage")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Reset") {
                    
                }
                Button("Save") {
                    
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
            }
        }
    }
}
