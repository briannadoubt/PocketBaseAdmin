//
//  ViewQueryEditorView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// A view for editing the SQL query of a View collection.
struct ViewQueryEditorView: View {
    @Binding var query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Query editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Select query")
                        .fontWeight(.medium)
                    Text("*")
                        .foregroundStyle(.red)
                }

                TextEditor(text: $query)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Group {
                            if query.isEmpty {
                                Text("eg. SELECT id, name from posts")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            }

            // Help text
            VStack(alignment: .leading, spacing: 8) {
                QueryHelpItem(
                    bullet: "Wildcard columns (",
                    code: "*",
                    suffix: ") are not supported."
                )

                QueryHelpItem(
                    bullet: "The query must have a unique ",
                    code: "id",
                    suffix: " column."
                )

                Text("If your query doesn't have a suitable one, you can use the universal ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                +
                Text("(ROW_NUMBER() OVER()) as id")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                +
                Text(".")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                QueryHelpItem(
                    bullet: "Expressions must be aliased with a valid formatted field name, e.g. ",
                    code: "MAX(balance) as maxBalance",
                    suffix: "."
                )

                QueryHelpItem(
                    bullet: "Combined/multi-spaced expressions must be wrapped in parenthesis, e.g. ",
                    code: "(MAX(balance) + 1) as maxBalance",
                    suffix: "."
                )
            }
            .padding(.leading, 4)
        }
    }
}

/// A help item with a bullet point, inline code, and suffix text.
private struct QueryHelpItem: View {
    let bullet: String
    let code: String
    let suffix: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text("•")
                .font(.caption)
                .foregroundStyle(.secondary)

            (
                Text(bullet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                +
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                +
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            )
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var query = ""

        var body: some View {
            Form {
                Section {
                    ViewQueryEditorView(query: $query)
                }
            }
            .frame(width: 600, height: 400)
        }
    }

    return PreviewWrapper()
}
