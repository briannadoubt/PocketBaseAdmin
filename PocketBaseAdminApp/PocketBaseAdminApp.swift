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

@main
struct PocketBaseAdminApp: App {
    @Environment(\.dismissWindow) private var dismissWindow

    let createUser: CreateUser<Superuser> = { username, email in
        Superuser(
            username: username,
            email: email,
            verified: false,
            emailVisibility: false
        )
    }
    
    var body: some Scene {
        WindowGroup("PocketBase Admin", id: "main") {
            ContentView()
                .authenticated(newUser: createUser)
#if targetEnvironment(simulator) || os(macOS)
                .pocketbase(.localhost)
#elseif DEBUG
                .pocketbase(.localNetwork(ip: "10.0.0.185"))
#else
                .pocketbase(url: URL(string: "https://api.pocketbase.app")!)
#endif
        }
        .commands {
            InspectorCommands()
            SidebarCommands()
            ToolbarCommands()
            TextEditingCommands()
            TextFormattingCommands()
        }
        
        #if os(macOS) || os(visionOS)
        WindowGroup("Authentication", id: "auth") {
            AuthenticationContentView(createUser: createUser)
                .onAppear {
                    dismissWindow(id: "main")
                }
        }
        .pocketbase(.localhost)
        .windowIdealSize(.fitToContent)
        #endif // os(macOS) || os(visionOS)
    }
}

struct AuthenticationContentView: View {
    #if os(macOS) || os(visionOS)
    @Environment(\.dismissWindow) private var dismissWindow
    #endif
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
                #if os(macOS) || os(visionOS)
                Button("Let's go!") {
                    dismissWindow(id: "auth")
                }
                .buttonStyle(.borderedProminent)
                #endif
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
