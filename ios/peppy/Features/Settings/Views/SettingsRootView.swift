import SwiftUI

struct SettingsRootView: View {
    @Environment(\.dependencies) private var dependencies
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
                destination(for: route)
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

    @ViewBuilder
    private func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .profile:
            ProfileSettingsView(
                store: store,
                weightUnitPreferences: dependencies.weightUnitPreferences
            )
        case .notifications:
            NotificationSettingsView(
                store: store,
                protocolStore: dependencies.protocolStore,
                permissionService: dependencies.notifications,
                scheduler: dependencies.localNotificationScheduler,
                registerForRemoteNotifications: {
                    dependencies.remoteNotificationRegistrar
                        .registerForRemoteNotifications()
                },
                showProtocols: {
                    dependencies.protocolNavigation.showProtocolsTab()
                }
            )
        case .dataExport:
            DataExportView(
                api: dependencies.api,
                fileService: dependencies.exportFileService
            )
        case .security:
            let userID =
                store.user?.id ?? dependencies.appState.currentUser?.id
            SecurityPrivacyView(
                api: dependencies.api,
                appLock: dependencies.appLock,
                userID: userID,
                finishSignedOutSession: {
                    await dependencies.flow.finishSignedOutSession()
                },
                removeDeviceSettings: {
                    guard let userID else { return }
                    dependencies.appLock.removePreference(for: userID)
                    dependencies.weightUnitPreferences.removePreference(
                        for: userID
                    )
                    dependencies.onboardingStore.removeDraft(for: userID)
                }
            )
        case .help:
            HelpAboutView(version: version)
        case .about:
            SettingsBrowserRouteView(destination: .about)
        case .legal:
            HelpAboutView(
                version: version,
                startSection: .importantInformation
            )
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

#Preview {
    let dependencies = Dependencies.mock()
    return SettingsRootView(
        store: dependencies.settingsStore,
        version: SettingsAppVersion(shortVersion: "1.2.0", build: "123"),
        logout: {}
    )
    .withDependencies(dependencies)
}
