//
//  AdminTab.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI

enum AdminTab: String, CaseIterable, Identifiable {
    case collections
    case logs
    case settings
    
    var id: String { rawValue }
    
    var title: LocalizedStringKey {
        switch self {
        case .collections:
            "Collections"
        case .logs:
            "Logs"
        case .settings:
            "Settings"
        }
    }
    
    var image: ImageResource {
        switch self {
        case .collections:
            .collections
        case .logs:
            .logs
        case .settings:
            .settings
        }
    }
    
    @ViewBuilder var label: some View {
        Label {
            Text(title)
        } icon: {
            Image(image)
                .resizable()
                .scaledToFit()
        }
    }
}
