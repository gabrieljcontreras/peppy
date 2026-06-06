import SwiftUI

struct RootView: View {
    @Environment(\.dependencies) var deps

    var body: some View {
        Group {
            if deps.appState.isAuthenticated {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .pepToast($deps.appState.toast)
        .task {
            await checkExistingSession()
        }
    }

    private func checkExistingSession() async {
        guard deps.keychain.get(KeychainKeys.accessToken) != nil else {
            return
        }

        do {
            let user: User = try await deps.api.execute(.me)
            deps.appState.login(user: user)
        } catch {
            deps.keychain.delete(KeychainKeys.accessToken)
            deps.keychain.delete(KeychainKeys.refreshToken)
        }
    }
}

#Preview {
    RootView()
        .withDependencies(.mock())
}
