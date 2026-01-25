//
//  AddConnectionView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// View for adding a new PocketBase connection
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
struct AddConnectionView: View {
    @Environment(ConnectionHub.self) private var hub
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var port = ""
    @State private var useTLS = false
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("My PocketBase Server"))
                    TextField("Host", text: $host, prompt: Text("example.com or https://example.com"))
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                        .onChange(of: host) { _, newValue in
                            parseHostInput(newValue)
                        }
                    TextField("Port", text: $port, prompt: Text("Optional (defaults to 443/80)"))
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Toggle("Use TLS (HTTPS)", isOn: $useTLS)
                } header: {
                    Text("Connection Details")
                } footer: {
                    if let url = previewURL {
                        Text("URL: \(url.absoluteString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            if isLoading {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Connection")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addConnection()
                    }
                    .disabled(!isValid || isLoading)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !cleanHost.isEmpty &&
        (port.isEmpty || Int(port) != nil)
    }

    private var cleanHost: String {
        host.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    private var effectivePort: Int {
        if let portInt = Int(port), !port.isEmpty {
            return portInt
        }
        return useTLS ? 443 : 80
    }

    private var previewURL: URL? {
        guard isValid else { return nil }
        let scheme = useTLS ? "https" : "http"
        let portInt = effectivePort

        // Don't show default ports in URL
        if (useTLS && portInt == 443) || (!useTLS && portInt == 80) {
            return URL(string: "\(scheme)://\(cleanHost)")
        }
        return URL(string: "\(scheme)://\(cleanHost):\(portInt)")
    }

    // MARK: - Actions

    private func parseHostInput(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Try to parse as URL if it contains ://
        if trimmed.contains("://"), let url = URL(string: trimmed) {
            // Extract host (remove protocol)
            if let urlHost = url.host {
                host = urlHost
            }

            // Auto-detect TLS from protocol
            if url.scheme == "https" {
                useTLS = true
            } else if url.scheme == "http" {
                useTLS = false
            }

            // Extract port if specified
            if let urlPort = url.port {
                port = String(urlPort)
            } else {
                // Clear port to use default
                port = ""
            }
        }
    }

    private func testConnection() {
        guard let url = previewURL else { return }

        isLoading = true
        error = nil

        Task {
            do {
                // Try to fetch the health endpoint
                var healthURL = url
                healthURL.append(path: "api/health")

                let (_, response) = try await URLSession.shared.data(from: healthURL)

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        error = nil
                    } else {
                        error = "Server returned status \(httpResponse.statusCode)"
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func addConnection() {
        guard isValid else { return }

        let connection = Connection(
            name: name.trimmingCharacters(in: .whitespaces),
            host: cleanHost,
            port: effectivePort,
            useTLS: useTLS
        )

        Task {
            do {
                try await hub.add(connection)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
#Preview {
    AddConnectionView()
        .environment(ConnectionHub())
}
#endif
