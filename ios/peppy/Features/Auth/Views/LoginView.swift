import SwiftUI

struct LoginView: View {
    static let backButtonAccessibilityLabel = "Back"
    static let backButtonTapTarget: CGFloat = 44
    static let bottomSafeAreaPadding: CGFloat = 28

    @Environment(\.dependencies) var deps

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        if deps.flow.shouldShowAuthenticationBackButton {
                            backButton
                        }
                        Spacer()
                    }
                    .padding(.top, 12)

                    PeppyLogo(size: 72)
                        .padding(.top, 30)

                    Text("Welcome back")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundColor(.pepTextPrimary)
                        .padding(.top, 26)

                    Text("Sign in to continue to your protocol.")
                        .font(.system(size: 14))
                        .foregroundColor(.pepTextSecondary)
                        .padding(.top, 10)

                    VStack(spacing: 27) {
                        PepTextFieldWithLabel(
                            label: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            keyboardType: .emailAddress
                        )

                        VStack(alignment: .trailing, spacing: 10) {
                            PepTextFieldWithLabel(
                                label: "Password",
                                placeholder: "Enter your password",
                                text: $password,
                                isSecure: true
                            )

                            Button("Forgot password?") {}
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.pepPrimary)
                                .frame(minHeight: Self.backButtonTapTarget)
                        }
                    }
                    .padding(.top, 39)

                    PepButton(
                        title: "Sign in",
                        style: .primary,
                        isLoading: isLoading,
                        isDisabled: !isFormValid
                    ) {
                        Task { await login() }
                    }
                    .padding(.top, 27)

                    HStack(spacing: 14) {
                        Rectangle().fill(Color.pepBorder).frame(height: 1)
                        Text("or")
                            .font(.system(size: 14))
                            .foregroundColor(.pepTextSecondary)
                        Rectangle().fill(Color.pepBorder).frame(height: 1)
                    }
                    .padding(.vertical, 30)

                    Button(action: {}) {
                        Label("Sign in with Apple", systemImage: "apple.logo")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.pepTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(Capsule().stroke(Color.pepTextTertiary, lineWidth: 0.8))
                    }

                    HStack(spacing: 3) {
                        Text("New here?")
                            .foregroundColor(.pepTextSecondary)
                        Button("Create account.") {
                            deps.flow.showRegistration()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.pepPrimary)
                        .frame(minHeight: Self.backButtonTapTarget)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(.top, 34)

                    Spacer(minLength: 32)

                    Label(
                        "Your health data stays private and encrypted.",
                        systemImage: "lock"
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.pepTextSecondary)
                    .padding(.bottom, Self.bottomSafeAreaPadding)
                }
                .padding(.horizontal, 30)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom, Self.bottomSafeAreaPadding)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var backButton: some View {
        Button {
            deps.flow.goBackFromAuthentication()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.pepTextPrimary)
                .frame(width: 34, height: 34)
                .background(Color.pepSurface)
                .clipShape(Circle())
                .pepCardShadow()
        }
        .frame(width: Self.backButtonTapTarget, height: Self.backButtonTapTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(Self.backButtonAccessibilityLabel)
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
            await Self.completeLogin(user: user, deps: deps)
        } catch let error as APIError {
            deps.appState.showError(error)
        } catch {
            deps.appState.showError(.unknown(error.localizedDescription))
        }
    }

    @MainActor
    static func completeLogin(user: User, deps: Dependencies) async {
        await deps.flow.didAuthenticate(user: user)
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .withDependencies(.mock())
}
