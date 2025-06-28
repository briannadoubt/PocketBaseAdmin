//
//  PocketBaseAdminApp.swift
//  PocketBaseAdmin
//
//  Created by Brianna Zamora on 3/16/25.
//

import SwiftUI
import PocketBaseUI
import PocketBase
import PocketBaseAdmin
import SDWebImageSwiftUI

@main
struct PocketBaseAdminApp: App {
    let createUser: CreateUser<Superuser> = { username, email in
        Superuser(
            username: username,
            email: email,
            verified: false,
            emailVisibility: false
        )
    }
    
    var body: some Scene {
        WindowGroup("PocketBase Admin") {
            ContentView()
                .authenticated(newUser: createUser)
//                .pocketbase(.localhost)
                .pocketbase(.localNetwork(ip: "10.0.0.185"))
        }
        
        #if os(macOS) || os(visionOS)
        WindowGroup("Authentication", id: "auth") {
            AuthenticationContentView(createUser: createUser)
        }
        .pocketbase(.localhost)
        .windowIdealSize(.fitToContent)
        #endif // os(macOS) || os(visionOS)
    }
}

struct AuthenticationContentView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.pocketbase) private var pocketbase
    
    @State private var authState: AuthState = .signedOut
    
    let createUser: CreateUser<Superuser>
    
    var body: some View {
        switch authState {
        case .loading:
            ProgressView()
        case .signedIn:
            ContentUnavailableView {
                Label("You've authenticated successfully!", systemImage: "party.popper.fill")
            } description: {
                Text("You can close this window and return to the app.")
            } actions: {
                Button("Let's go!") {
                    dismissWindow(id: "auth")
                }
                .buttonStyle(.borderedProminent)
            }
        case .signedOut:
            SignedOutView(
                collection: pocketbase.collection(Superuser.self),
                authState: $authState,
                newUser: createUser
            )
        }
    }
}
