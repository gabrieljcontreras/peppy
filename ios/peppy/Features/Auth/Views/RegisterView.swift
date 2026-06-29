import SwiftUI

struct RegisterView: View {
    static let backButtonAccessibilityLabel = "Back"
    static let backButtonTapTarget: CGFloat = 44
    static let bottomSafeAreaPadding: CGFloat = 28

    @Environment(\.dependencies) var deps

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var acceptedTerms = true
    @State private var isLoading = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        HStack {
                            if deps.flow.shouldShowAuthenticationBackButton {
                                backButton
                            }
                            Spacer()
                        }
                        PeppyLogo(size: 35, showsWordmark: true)
                    }
                    .padding(.top, 12)

                    (Text("Create your ")
                        .foregroundColor(.pepTextPrimary)
                        + Text("account")
                        .foregroundColor(.pepPrimary)
                        .font(.system(size: 31, weight: .semibold, design: .serif))
                        .italic())
                        .font(.system(size: 31, weight: .bold))
                        .padding(.top, 35)

                    VStack(spacing: 22) {
                        PepTextFieldWithLabel(
                            label: "Full name",
                            placeholder: "Enter your full name",
                            text: $fullName
                        )

                        PepTextFieldWithLabel(
                            label: "Email",
                            placeholder: "Enter your email",
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

                        VStack(alignment: .leading, spacing: 10) {
                            PepTextFieldWithLabel(
                                label: "Confirm password",
                                placeholder: "Confirm your password",
                                text: $confirmPassword,
                                isSecure: true,
                                errorMessage: confirmPasswordError
                            )

                            Text("Use at least 8 characters with a mix of letters, numbers,\nand symbols.")
                                .font(.system(size: 11))
                                .foregroundColor(.pepTextSecondary)
                                .lineSpacing(3)
                        }
                    }
                    .padding(.top, 36)

                    termsButton
                        .padding(.top, 26)

                    PepButton(
                        title: "Create account",
                        style: .primary,
                        isLoading: isLoading,
                        isDisabled: !isFormValid
                    ) {
                        Task { await register() }
                    }
                    .padding(.top, 22)

                    HStack(spacing: 3) {
                        Text("Already have an account?")
                            .foregroundColor(.pepTextSecondary)
                        Button("Sign in.") {
                            deps.flow.showSignIn()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.pepPrimary)
                        .frame(minHeight: Self.backButtonTapTarget)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(.top, 27)
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

    private var termsButton: some View {
        Button {
            acceptedTerms.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: acceptedTerms ? "checkmark" : "")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 23, height: 23)
                    .background(acceptedTerms ? Color.pepPrimary : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(acceptedTerms ? Color.pepPrimary : Color.pepBorder)
                    )

                (Text("I agree to the ")
                    .foregroundColor(.pepTextPrimary)
                    + Text("Terms of Service")
                    .foregroundColor(.pepPrimary)
                    + Text(" and ")
                    .foregroundColor(.pepTextPrimary)
                    + Text("Privacy Policy.")
                    .foregroundColor(.pepPrimary))
                    .font(.system(size: 10))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(Color.pepBorder, lineWidth: 0.8)
            )
        }
    }

    private var passwordError: String? {
        guard !password.isEmpty, password.count < 8 else { return nil }
        return "Password must be at least 8 characters"
    }

    private var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty, password != confirmPassword else { return nil }
        return "Passwords don't match"
    }

    private var isFormValid: Bool {
        !fullName.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword &&
        acceptedTerms
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
            Self.completeRegistration(user: user, deps: deps)
        } catch let error as APIError {
            deps.appState.showError(error)
        } catch {
            deps.appState.showError(.unknown(error.localizedDescription))
        }
    }

    @MainActor
    static func completeRegistration(user: User, deps: Dependencies) {
        deps.flow.didAuthenticate(user: user)
        deps.appState.showSuccess("Welcome to Peppy!")
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
    .withDependencies(.mock())
}
