//
//  LogActions.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Actions that can be performed on logs
enum LogAction: Identifiable {
    case copyID(LogModel)
    case copyAsJSON(LogModel)
    case copyMessage(LogModel)
    case copyURL(LogModel)
    case copyIP(LogModel)
    case filterByLevel(LogModel)
    case filterByURL(LogModel)

    var id: String {
        switch self {
        case .copyID(let l): return "copyID-\(l.id)"
        case .copyAsJSON(let l): return "copyAsJSON-\(l.id)"
        case .copyMessage(let l): return "copyMessage-\(l.id)"
        case .copyURL(let l): return "copyURL-\(l.id)"
        case .copyIP(let l): return "copyIP-\(l.id)"
        case .filterByLevel(let l): return "filterByLevel-\(l.id)"
        case .filterByURL(let l): return "filterByURL-\(l.id)"
        }
    }
}

/// Reusable menu content for log context menus
struct LogMenuContent: View {
    let log: LogModel
    let onFilterByLevel: ((LogLevel) -> Void)?
    let onFilterByURL: ((String) -> Void)?

    init(
        log: LogModel,
        onFilterByLevel: ((LogLevel) -> Void)? = nil,
        onFilterByURL: ((String) -> Void)? = nil
    ) {
        self.log = log
        self.onFilterByLevel = onFilterByLevel
        self.onFilterByURL = onFilterByURL
    }

    var body: some View {
        Button {
            Clipboard.copy(log.id)
        } label: {
            Label("Copy Log ID", systemImage: "doc.on.doc")
        }

        Button {
            copyAsJSON()
        } label: {
            Label("Copy as JSON", systemImage: "curlybraces")
        }

        Button {
            Clipboard.copy(log.message)
        } label: {
            Label("Copy Message", systemImage: "text.quote")
        }

        if let url = log.data.url {
            Button {
                Clipboard.copy(url)
            } label: {
                Label("Copy URL", systemImage: "link")
            }
        }

        if let ip = log.data.remoteIp ?? log.data.userIp {
            Button {
                Clipboard.copy(ip)
            } label: {
                Label("Copy IP Address", systemImage: "network")
            }
        }

        Divider()

        if let onFilterByLevel {
            Button {
                onFilterByLevel(log.level)
            } label: {
                Label("Filter by Level: \(log.level.displayName)", systemImage: "line.3.horizontal.decrease.circle")
            }
        }

        if let onFilterByURL, let url = log.data.url {
            Button {
                onFilterByURL(url)
            } label: {
                Label("Filter by URL", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private func copyAsJSON() {
        var dict: [String: Any] = [
            "id": log.id,
            "level": log.level.numericValue,
            "message": log.message,
            "created": ISO8601DateFormatter().string(from: log.created)
        ]

        // Add data fields
        var dataDict: [String: Any] = [:]
        if let execTime = log.data.execTime { dataDict["execTime"] = execTime }
        if let type = log.data.type { dataDict["type"] = type }
        if let auth = log.data.auth { dataDict["auth"] = auth }
        if let status = log.data.status { dataDict["status"] = status }
        if let method = log.data.method { dataDict["method"] = method }
        if let url = log.data.url { dataDict["url"] = url }
        if let referer = log.data.referer { dataDict["referer"] = referer }
        if let remoteIp = log.data.remoteIp { dataDict["remoteIp"] = remoteIp }
        if let userIp = log.data.userIp { dataDict["userIp"] = userIp }
        if let userAgent = log.data.userAgent { dataDict["userAgent"] = userAgent }

        if !dataDict.isEmpty {
            dict["data"] = dataDict
        }

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            Clipboard.copy(string)
        }
    }
}
