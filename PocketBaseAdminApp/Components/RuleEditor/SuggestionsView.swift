//
//  SuggestionsView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// A view that displays autocomplete suggestions for the rule editor.
struct SuggestionsView: View {
    let suggestions: [RuleSuggestion]
    let onSelect: (RuleSuggestion) -> Void
    @Binding var selectedIndex: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: selectedIndex == index
                        ) {
                            onSelect(suggestion)
                        }
                        .id(index)
                    }
                }
            }
            .onChange(of: selectedIndex) { _, newIndex in
                if let index = newIndex {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
        .frame(maxHeight: 200)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

/// A single row in the suggestions list.
struct SuggestionRow: View {
    let suggestion: RuleSuggestion
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.displayText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)

                    if let description = suggestion.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(suggestion.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(suggestion.category.color.opacity(0.2))
                    .foregroundStyle(suggestion.category.color)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SuggestionsView(
        suggestions: RuleSuggestion.allStaticSuggestions,
        onSelect: { _ in },
        selectedIndex: .constant(0)
    )
    .frame(width: 400)
    .padding()
}
