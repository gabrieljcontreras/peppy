import SwiftUI

struct RegisterView: View {
    @Environment(\.dependencies) var deps
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.sm) {
                    Text("Create Account")
                        .pepTitle()

                    Text("Start tracking your protocols")
                        .pepSubheadline()
                }
                .padding(.top, Spacing.xl)

                VStack(spacing: Spacing.md) {
                    PepTextFieldWithLabel(
                        label: "Email",
                        placeholder: "you@example.com",
                        text: $email,
                        keyboardType: .emailAddress
                    )

                    PepTextFieldWithLabel(
                        label: "Password",
                        placeholder: "Create a password",
                        text: $password,
                        isSecure: true,
                        errorMessage: passwordError
                    )

                    PepTextFieldWithLabel(
                        label: "Confirm Password",
                        placeholder: "Confirm your password",
                        text: $confirmPassword,
                        isSecure: true,
                        errorMessage: confirmPasswordError
                    )
                }
                .padding(.top, Spacing.lg)

                PepButton(
                    title: "Create Account",
                    style: .primary,
                    isLoading: isLoading,
                    isDisabled: !isFormValid
                ) {
                    Task { await register() }
                }
                .padding(.top, Spacing.lg)

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
        }
        .background(Color.pepBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var passwordError: String? {
        guard !password.isEmpty else { return nil }
        if password.count < 8 {
            return "Password must be at least 8 characters"
        }
        return nil
    }

    private var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        if password != confirmPassword {
            return "Passwords don't match"
        }
        return nil
    }

    private var isFormValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword
    }

    private func register() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let auth: AuthResponse = try await deps.api.execute(
                .register(email: email, password: password)
            )

            try deps.keychain.save(auth.accessToken, for: KeychainKeys.accessToken)
            try deps.keychain.save(auth.refreshToken, for: KeychainKeys.refreshToken)

            let user: User = try await deps.api.execute(.me)
            deps.appState.login(user: user)

            deps.appState.showSuccess("Welcome to Peppy!")
        } catch let error as APIError {
            deps.appState.showError(error)
        } catch {
            deps.appState.showError(.unknown(error.localizedDescription))
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
    .withDependencies(.mock())
}
