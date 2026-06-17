import SwiftUI

struct RootView: View {
    @Environment(\.dependencies) var deps

    var body: some View {
        @Bindable var appState = deps.appState
        Group {
            switch Self.destination(for: deps) {
            case .launching:
                LaunchResolutionView(
                    error: deps.flow.launchError,
                    retry: {
                        Task { await deps.flow.resolveLaunch() }
                    }
                )
            case .onboarding:
                OnboardingFlowView()
            case .readySummary:
                ReadySummaryView(
                    draft: deps.onboardingStore.loadAnonymousDraft() ?? OnboardingDraft(),
                    continueAction: deps.flow.continueFromReadySummary,
                    signInAction: deps.flow.showSignIn
                )
            case .futurePaywall:
                Color.pepBackground
                    .ignoresSafeArea()
                    .task {
                        deps.flow.advancePastFuturePaywall()
                    }
            case .authentication(let mode):
                NavigationStack {
                    switch mode {
                    case .register:
                        RegisterView()
                    case .signIn:
                        LoginView()
                    }
                }
                .tint(.pepTextPrimary)
            case .dashboard:
                MainTabView()
            }
        }
        .pepToast($appState.toast)
        .task {
            if Self.shouldResolveLaunch(for: deps) {
                await deps.flow.resolveLaunch()
            }
        }
    }

    static func destination(for dependencies: Dependencies) -> AppRoute {
        dependencies.flow.route
    }

    static func shouldResolveLaunch(for dependencies: Dependencies) -> Bool {
        dependencies.flow.route == .launching
    }
}

struct LaunchResolutionView: View {
    let error: APIError?
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color.pepBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                PeppyLogo(size: 88)

                if let error {
                    Text(error.userMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.pepTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)

                    PepButton(title: "Retry", style: .secondary, action: retry)
                        .frame(maxWidth: 220)
                } else {
                    ProgressView()
                        .tint(.pepPrimary)
                        .accessibilityLabel("Loading Peppy")
                }
            }
        }
    }
}

#Preview {
    RootView()
        .withDependencies(.mock())
}
