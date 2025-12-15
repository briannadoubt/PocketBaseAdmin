//
//  ImportCollectionsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin
import UniformTypeIdentifiers

struct ImportCollectionsView: View {
    @State private var jsonText = ""
    @State private var parsedCollections: [CollectionModel] = []
    @State private var parseError: String?
    @State private var deleteMissing = false

    @State private var isImporting = false
    @State private var importError: String?
    @State private var importSuccess = false

    @State private var showFilePicker = false

    @Environment(\.pocketbase) private var pocketbase
    @Environment(CollectionsState.self) private var collectionsState

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let importError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(importError)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                }

                if importSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Collections imported successfully!")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }

                // Import options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Import Collection Schemas")
                        .font(.headline)

                    Text("Paste JSON or import from a file to sync collection schemas.")
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Import from File") {
                            showFilePicker = true
                        }
                        .buttonStyle(.bordered)

                        Button("Clear") {
                            jsonText = ""
                            parsedCollections = []
                            parseError = nil
                        }
                        .buttonStyle(.bordered)
                        .disabled(jsonText.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.05))
                )

                // JSON input
                VStack(alignment: .leading, spacing: 8) {
                    Text("JSON Schema")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextEditor(text: $jsonText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: jsonText) { _, newValue in
                            parseJSON(newValue)
                        }

                    if let parseError {
                        Text(parseError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Preview
                if !parsedCollections.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview (\(parsedCollections.count) collections)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ForEach(parsedCollections) { collection in
                            HStack {
                                Image(collection.type.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: iconSize, height: iconSize)
                                Text(collection.name)
                                Spacer()
                                Text("\(collection.schema?.count ?? 0) fields")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.05))
                    )

                    // Options
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Delete missing collections", isOn: $deleteMissing)

                        if deleteMissing {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Collections not in the import will be deleted!")
                                    .font(.callout)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.05))
                    )

                    // Import button
                    Button {
                        Task {
                            await performImport()
                        }
                    } label: {
                        if isImporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Import \(parsedCollections.count) Collections")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImporting || parsedCollections.isEmpty)
                }
            }
            .padding()
        }
        .navigationTitle("Import Collections")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func parseJSON(_ text: String) {
        guard !text.isEmpty else {
            parsedCollections = []
            parseError = nil
            return
        }

        do {
            let data = Data(text.utf8)
            let decoder = JSONDecoder()

            // Try parsing as array first
            if let collections = try? decoder.decode([CollectionModel].self, from: data) {
                parsedCollections = collections
                parseError = nil
                return
            }

            // Try parsing as object with "collections" key
            if let wrapper = try? decoder.decode(CollectionsWrapper.self, from: data) {
                parsedCollections = wrapper.collections
                parseError = nil
                return
            }

            // Try parsing as single collection
            let single = try decoder.decode(CollectionModel.self, from: data)
            parsedCollections = [single]
            parseError = nil
        } catch {
            parsedCollections = []
            parseError = "Invalid JSON: \(error.localizedDescription)"
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let data = try Data(contentsOf: url)
                jsonText = String(data: data, encoding: .utf8) ?? ""
            } catch {
                importError = "Failed to read file: \(error.localizedDescription)"
            }

        case .failure(let error):
            importError = "Failed to open file: \(error.localizedDescription)"
        }
    }

    private func performImport() async {
        isImporting = true
        importError = nil
        importSuccess = false
        defer { isImporting = false }

        do {
            try await pocketbase.admin.collections.import(parsedCollections, deleteMissing: deleteMissing)
            importSuccess = true

            // Refresh collections list
            await collectionsState.load(from: pocketbase)

            // Clear form after success
            jsonText = ""
            parsedCollections = []
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct CollectionsWrapper: Decodable {
    let collections: [CollectionModel]
}
