//
//  TokenOptionsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBaseAdmin

struct TokenOptionsView: View {
    @Environment(Admin.Settings.self) private var settings
    
    var body: some View {
        Form {
            Section("Admin Tokens") {
                if let adminAuthToken = settings.adminAuthToken {
                    LabeledContent("Auth Token Duration") {
                        Text("\(adminAuthToken.duration) seconds")
                    }
                }
                
                if let adminPasswordResetToken = settings.adminPasswordResetToken {
                    LabeledContent("Password Reset Duration") {
                        Text("\(adminPasswordResetToken.duration) seconds")
                    }
                }
                
                if let adminFileToken = settings.adminFileToken {
                    LabeledContent("File Token Duration") {
                        Text("\(adminFileToken.duration) seconds")
                    }
                }
            }
            
            Section("Record Tokens") {
                if let recordAuthToken = settings.recordAuthToken {
                    LabeledContent("Auth Token Duration") {
                        Text("\(recordAuthToken.duration) seconds")
                    }
                }
                
                if let recordPasswordResetToken = settings.recordPasswordResetToken {
                    LabeledContent("Password Reset Duration") {
                        Text("\(recordPasswordResetToken.duration) seconds")
                    }
                }
                
                if let recordEmailChangeToken = settings.recordEmailChangeToken {
                    LabeledContent("Email Change Duration") {
                        Text("\(recordEmailChangeToken.duration) seconds")
                    }
                }
                
                if let recordVerificationToken = settings.recordVerificationToken {
                    LabeledContent("Verification Duration") {
                        Text("\(recordVerificationToken.duration) seconds")
                    }
                }
                
                if let recordFileToken = settings.recordFileToken {
                    LabeledContent("File Token Duration") {
                        Text("\(recordFileToken.duration) seconds")
                    }
                }
            }
        }
        .navigationTitle("Token Options")
    }
}
