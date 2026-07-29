import SwiftUI

struct RootView: View {
    @Environment(\.dependencies) var deps

    var body: some View {
        @Bindable var appState = deps.appState
        let route = Self.destination(for: deps)

        ZStack {
            Group {
                switch route {
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

            if Self.shouldPresentAppLockCover(
                route: route,
                isCoverVisible: deps.appLock.isPrivacyCoverVisible
            ) {
                AppLockCoverView(coordinator: deps.appLock)
                    .zIndex(100)
            }
        }
        .pepToast($appState.toast)
        .task {
            deps.entitlements.start()
            if Self.shouldResolveLaunch(for: deps) {
                await deps.flow.resolveLaunch()
            }
        }
        .task(id: deps.appState.currentUser?.id) {
            guard route == .dashboard,
                  let userID = deps.appState.currentUser?.id else {
                return
            }
            await deps.appLock.authenticatedSessionBecameVisible(userID: userID)
        }
    }

    static func destination(for dependencies: Dependencies) -> AppRoute {
        dependencies.flow.route
    }

    static func shouldResolveLaunch(for dependencies: Dependencies) -> Bool {
        dependencies.flow.route == .launching
    }

    static func shouldPresentAppLockCover(
        route: AppRoute,
        isCoverVisible: Bool
    ) -> Bool {
        route == .dashboard && isCoverVisible
    }
}

struct LaunchResolutionView: View {
    static let logoFrameLength: CGFloat = 128

    let error: APIError?
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(
                    width: Self.logoFrameLength,
                    height: Self.logoFrameLength
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Peppy")

            if let error {
                VStack(spacing: 18) {
                    Text(error.userMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.pepTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)

                    PepButton(title: "Retry", style: .secondary, action: retry)
                        .frame(maxWidth: 220)
                }
                .offset(y: Self.logoFrameLength)
            } else {
                ProgressView()
                    .tint(.pepPrimary)
                    .offset(y: Self.logoFrameLength / 2 + 32)
                    .accessibilityLabel("Loading Peppy")
            }
        }
    }
}

#Preview {
    RootView()
        .withDependencies(.mock())
}
