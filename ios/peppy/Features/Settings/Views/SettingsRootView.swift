import SwiftUI

struct SettingsRootView: View {
    @Bindable var store: SettingsStore
    let version: SettingsAppVersion
    let logout: () -> Void

    @State private var path: [SettingsRoute] = []
    @State private var showsLogoutConfirmation = false

    init(
        store: SettingsStore,
        version: SettingsAppVersion = SettingsAppVersion(),
        logout: @escaping () -> Void
    ) {
        self.store = store
        self.version = version
        self.logout = logout
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SettingsHeader()

                    if let refreshError = store.refreshError {
                        SettingsRefreshBanner(message: refreshError.userMessage) {
                            Task { await store.refresh() }
                        }
                    }

                    SettingsProfileCard(user: store.user)

                    SettingsSectionCard(
                        title: "My data",
                        rows: SettingsRootViewModel.myDataRows
                    )

                    SettingsSectionCard(
                        title: "Account & app",
                        rows: SettingsRootViewModel.accountAndAppRows
                    )

                    footer
                        .padding(.top, -8)
                }
                .padding(.horizontal, SettingsFigmaLayout.horizontalPadding)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .refreshable {
                await store.refresh()
            }
            .task {
                await store.refresh()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsRoute.self) { route in
                SettingsDestinationScaffold(route: route)
            }
        }
        .confirmationDialog(
            "Log out of Peppy?",
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive, action: logout)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll need to sign in again to access your account.")
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Text(version.displayText)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.pepTextTertiary)

            Button {
                showsLogoutConfirmation = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .accessibilityHidden(true)
                    Text("Log Out")
                }
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.pepError)
                .frame(maxWidth: .infinity)
                .frame(minHeight: SettingsFigmaLayout.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Asks for confirmation before logging out")
        }
        .frame(maxWidth: .infinity)
    }
}

/// Task 9 establishes every navigation boundary. The destination views are
/// replaced by their complete Figma-backed implementations in Tasks 10–15.
private struct SettingsDestinationScaffold: View {
    let route: SettingsRoute

    var body: some View {
        VStack(spacing: Spacing.md) {
            PeppyLogo(size: 42)

            Text(route.title)
                .pepTitle2()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#Preview {
    let dependencies = Dependencies.mock()
    return SettingsRootView(
        store: dependencies.settingsStore,
        version: SettingsAppVersion(shortVersion: "1.2.0", build: "123"),
        logout: {}
    )
    .withDependencies(dependencies)
}
