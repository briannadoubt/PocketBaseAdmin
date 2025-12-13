//
//  ErrorHandling.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

@Observable @MainActor
final class ErrorHandler {
    var currentError: ErrorInfo?
    var showingError = false
    
    func handle(_ error: Error, context: String = "") {
        let errorInfo = ErrorInfo(
            error: error,
            context: context,
            timestamp: Date()
        )
        currentError = errorInfo
        showingError = true
    }
    
    func clearError() {
        currentError = nil
        showingError = false
    }
}

struct ErrorInfo {
    let error: Error
    let context: String
    let timestamp: Date
    
    var title: String {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return "Authentication Required"
            case .notFound:
                return "Not Found"
            case .invalidRequest:
                return "Invalid Request"
            case .invalidResponse:
                return "Invalid Response"
            case .invalidFilter:
                return "Invalid Filter"
            case .unknownResponse:
                return "Unknown Response"
            }
        }
        return "Error"
    }
    
    var description: String {
        if context.isEmpty {
            return String(describing: error)
        } else {
            return "\(context): \(String(describing: error))"
        }
    }
}

struct ErrorHandlerModifier: ViewModifier {
    @Environment(ErrorHandler.self) private var errorHandler
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: Binding(
                get: { errorHandler.showingError },
                set: { _ in errorHandler.clearError() }
            )) {
                Button("OK") {
                    errorHandler.clearError()
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(error.description)
                }
            }
    }
}

extension View {
    func errorHandling() -> some View {
        modifier(ErrorHandlerModifier())
    }
}
