//
//  SuperuserSetupView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

/// First-time setup wizard for creating the initial admin account
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
struct SuperuserSetupView: View {
    let pocketbase: PocketBase
    let onComplete: () -> Void

    @State private var step: SetupStep = .welcome
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isCreating = false
    @State private var error: String?

    enum SetupStep: CaseIterable {
        case welcome
        case credentials
        case confirmation
        case creating
        case success
        case error
    }

    var body: some View {
        VStack {
            // Progress indicator
            if step != .welcome && step != .success && step != .error {
                progressIndicator
            }

            Spacer()

            // Step content
            Group {
                switch step {
                case .welcome:
                    welcomeStep
                case .credentials:
                    credentialsStep
                case .confirmation:
                    confirmationStep
                case .creating:
                    creatingStep
                case .success:
                    successStep
                case .error:
                    errorStep
                }
            }
            .frame(maxWidth: 500)

            Spacer()

            // Navigation buttons
            if step != .creating {
                navigationButtons
            }
        }
        .padding(40)
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 20) {
            ForEach(Array(SetupStep.allCases.filter { $0 != .success && $0 != .error }.enumerated()), id: \.offset) { index, progressStep in
                Circle()
                    .fill(stepIndex(for: step) >= index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.top, 20)
    }

    private func stepIndex(for step: SetupStep) -> Int {
        switch step {
        case .welcome: return 0
        case .credentials: return 1
        case .confirmation: return 2
        case .creating: return 3
        case .success, .error: return 4
        }
    }

    // MARK: - Step Views

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text("Welcome to PocketBase")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("This instance needs to be configured with an admin account before you can start using it.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("You'll create a superuser account that has full access to manage collections, records, and settings.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var credentialsStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.fill.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Create Admin Account")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 350)

            // Password requirements
            VStack(alignment: .leading, spacing: 8) {
                Text("Password Requirements:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(PasswordValidator.requirements, id: \.self) { requirement in
                    HStack(spacing: 8) {
                        Image(systemName: requirement.isMet(by: password) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(requirement.isMet(by: password) ? .green : .secondary)
                        Text(requirement.description)
                            .font(.caption)
                            .foregroundStyle(requirement.isMet(by: password) ? .primary : .secondary)
                    }
                }
            }
            .frame(maxWidth: 350, alignment: .leading)

            // Email validation
            if !email.isEmpty && !isValidEmail(email) {
                Label("Please enter a valid email address", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // Password match
            if !confirmPassword.isEmpty && password != confirmPassword {
                Label("Passwords do not match", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var confirmationStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Confirm Setup")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Please review your admin account details:")
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Text("Email:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(email)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Password:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(repeating: "•", count: password.count))
                        .fontWeight(.medium)
                }

                Divider()

                Text("This account will have full administrative access to your PocketBase instance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 400)
        }
    }

    private var creatingStep: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)

            Text("Creating Admin Account...")
                .font(.title2)
                .fontWeight(.medium)

            Text("Please wait while we set up your account.")
                .foregroundStyle(.secondary)
        }
    }

    private var successStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Setup Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your admin account has been created successfully. You can now log in to manage your PocketBase instance.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var errorStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("Setup Failed")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let error {
                Text(error)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if step != .welcome && step != .success && step != .error {
                Button("Back") {
                    withAnimation {
                        goBack()
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            switch step {
            case .welcome:
                Button("Get Started") {
                    withAnimation {
                        step = .credentials
                    }
                }
                .buttonStyle(.borderedProminent)

            case .credentials:
                Button("Continue") {
                    withAnimation {
                        step = .confirmation
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isCredentialsValid)

            case .confirmation:
                Button("Create Account") {
                    createAccount()
                }
                .buttonStyle(.borderedProminent)

            case .success:
                Button("Continue to App") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)

            case .error:
                Button("Try Again") {
                    withAnimation {
                        step = .credentials
                        error = nil
                    }
                }
                .buttonStyle(.borderedProminent)

            case .creating:
                EmptyView()
            }
        }
    }

    private func goBack() {
        switch step {
        case .credentials:
            step = .welcome
        case .confirmation:
            step = .credentials
        case .error:
            step = .confirmation
        default:
            break
        }
    }

    // MARK: - Validation

    private var isCredentialsValid: Bool {
        isValidEmail(email) &&
        PasswordValidator.isValid(password) &&
        password == confirmPassword
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    // MARK: - Account Creation

    private func createAccount() {
        step = .creating
        isCreating = true

        Task {
            do {
                // Create the admin account using the Superuser collection
                let collection = pocketbase.collection(Superuser.self)

                let newAdmin = Superuser(
                    email: email,
                    verified: true,
                    emailVisibility: false
                )

                _ = try await collection.create(
                    newAdmin,
                    password: password,
                    passwordConfirm: confirmPassword
                )

                // Auto-login after creating
                _ = try await collection.authWithPassword(email, password: password)

                withAnimation {
                    step = .success
                }
            } catch {
                self.error = error.localizedDescription
                withAnimation {
                    step = .error
                }
            }
            isCreating = false
        }
    }
}

// MARK: - Password Validator

struct PasswordValidator {
    enum Requirement: Hashable, CaseIterable {
        case minLength
        case hasUppercase
        case hasLowercase
        case hasNumber

        var description: String {
            switch self {
            case .minLength: return "At least 10 characters"
            case .hasUppercase: return "At least one uppercase letter"
            case .hasLowercase: return "At least one lowercase letter"
            case .hasNumber: return "At least one number"
            }
        }

        func isMet(by password: String) -> Bool {
            switch self {
            case .minLength: return password.count >= 10
            case .hasUppercase: return password.contains(where: \.isUppercase)
            case .hasLowercase: return password.contains(where: \.isLowercase)
            case .hasNumber: return password.contains(where: \.isNumber)
            }
        }
    }

    static var requirements: [Requirement] {
        Requirement.allCases
    }

    static func validate(_ password: String) -> [Requirement] {
        requirements.filter { !$0.isMet(by: password) }
    }

    static func isValid(_ password: String) -> Bool {
        validate(password).isEmpty
    }
}

// MARK: - Previews

#if DEBUG
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
#Preview("Welcome") {
    SuperuserSetupView(pocketbase: PocketBase(url: URL(string: "http://localhost:8090")!)) {}
}
#endif
