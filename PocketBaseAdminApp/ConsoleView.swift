//
//  ConsoleView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

#if os(macOS)
import SwiftUI
import AppKit

/// Console view displaying PocketBase server logs with full text selection
@available(macOS 15.0, *)
struct ConsoleView: View {
    @Environment(\.serverManager) private var serverManager

    private var logs: [PocketBaseServerManager.LogEntry] {
        serverManager?.logs ?? []
    }

    var body: some View {
        Group {
            if logs.isEmpty {
                emptyState
            } else {
                ConsoleTextView(logs: logs)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Logs", systemImage: "text.alignleft")
        } description: {
            Text("Start the server to see logs")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// NSTextView wrapper for console output with multi-line selection
@available(macOS 15.0, *)
struct ConsoleTextView: NSViewRepresentable {
    let logs: [PocketBaseServerManager.LogEntry]

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Configure text view for console-like appearance
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        // Allow horizontal scrolling for long lines
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Check if we should auto-scroll (if already at bottom)
        let wasAtBottom = isScrolledToBottom(scrollView)

        // Build attributed string with colored output
        let attributedString = buildAttributedString(from: logs)

        // Update text
        textView.textStorage?.setAttributedString(attributedString)

        // Auto-scroll to bottom if we were already there
        if wasAtBottom {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func isScrolledToBottom(_ scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else { return true }
        let visibleRect = scrollView.contentView.bounds
        let documentHeight = documentView.frame.height
        // Consider "at bottom" if within 50 points of the bottom
        return visibleRect.maxY >= documentHeight - 50
    }

    private func buildAttributedString(from logs: [PocketBaseServerManager.LogEntry]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let timestampAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]

        let errorAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.systemRed
        ]

        for (index, entry) in logs.enumerated() {
            // Add timestamp
            let timestamp = NSAttributedString(
                string: entry.formattedTimestamp + "  ",
                attributes: timestampAttributes
            )
            result.append(timestamp)

            // Add message with appropriate color
            let message = NSAttributedString(
                string: entry.message,
                attributes: entry.isError ? errorAttributes : normalAttributes
            )
            result.append(message)

            // Add newline (except for last entry)
            if index < logs.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }
}

@available(macOS 15.0, *)
#Preview {
    ConsoleView()
        .frame(height: 300)
}
#endif
