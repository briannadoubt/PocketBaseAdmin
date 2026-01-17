//
//  main.swift
//  PocketBaseServerHelper
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation

/// XPC Service delegate for handling connections
class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: PocketBaseServerProtocol.self)

        // Create the exported object
        let exportedObject = PocketBaseServerService()
        newConnection.exportedObject = exportedObject

        // Set up invalidation handler
        newConnection.invalidationHandler = {
            // Clean up if needed
        }

        // Set up interruption handler
        newConnection.interruptionHandler = {
            // Handle interruption
        }

        // Resume the connection
        newConnection.resume()

        return true
    }
}

// Create the listener and delegate
let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate

// Start the service (this never returns)
listener.resume()
RunLoop.main.run()
