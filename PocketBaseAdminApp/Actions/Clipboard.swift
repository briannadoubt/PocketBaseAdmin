//
//  Clipboard.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform clipboard utilities
enum Clipboard {
    /// Copy a string to the system clipboard
    static func copy(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif os(iOS) || os(visionOS)
        UIPasteboard.general.string = string
        #endif
    }

    /// Copy data as JSON to the clipboard
    static func copyJSON<T: Encodable>(_ value: T, prettyPrinted: Bool = true) {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return
        }

        copy(string)
    }

    /// Get the current clipboard string content
    static func getString() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #elseif os(iOS) || os(visionOS)
        return UIPasteboard.general.string
        #else
        return nil
        #endif
    }
}
