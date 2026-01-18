//
//  AdminTab.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI

enum AdminTab: String, CaseIterable, Identifiable {
    case dashboard
    case collections
    case logs
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard:
            "Dashboard"
        case .collections:
            "Collections"
        case .logs:
            "Logs"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "gauge.with.dots.needle.33percent"
        case .collections:
            "rectangle.stack"
        case .logs:
            "doc.text.magnifyingglass"
        case .settings:
            "gearshape"
        }
    }

    var image: ImageResource {
        switch self {
        case .dashboard:
            .collections // Use collections as fallback since no custom asset yet
        case .collections:
            .collections
        case .logs:
            .logs
        case .settings:
            .settings
        }
    }

    @ViewBuilder var label: some View {
        switch self {
        case .dashboard:
            // Use SF Symbol for dashboard
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
        default:
            Label {
                Text(title)
            } icon: {
                Image(image)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
