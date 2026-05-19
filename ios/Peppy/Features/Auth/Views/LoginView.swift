import SwiftUI

struct LoginView: View {
    @Environment(\.dependencies) var deps
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.sm) {
                    Text("Welcome Back")
                        .pepTitle()

                    Text("Sign in to continue")
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
                        placeholder: "Enter your password",
                        text: $password,
                        isSecure: true
                    )
                }
                .padding(.top, Spacing.lg)

                PepButton(
                    title: "Sign In",
                    style: .primary,
                    isLoading: isLoading,
                    isDisabled: !isFormValid
                ) {
                    Task { await login() }
                }
                .padding(.top, Spacing.lg)

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
        }
        .background(Color.pepBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    private func login() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let auth: AuthResponse = try await deps.api.execute(
                .login(email: email, password: password)
            )

            try deps.keychain.save(auth.accessToken, for: KeychainKeys.accessToken)
            try deps.keychain.save(auth.refreshToken, for: KeychainKeys.refreshToken)

            let user: User = try await deps.api.execute(.me)
            deps.appState.login(user: user)
        } catch let error as APIError {
            deps.appState.showError(error)
        } catch {
            deps.appState.showError(.unknown(error.localizedDescription))
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .withDependencies(.mock())
}
