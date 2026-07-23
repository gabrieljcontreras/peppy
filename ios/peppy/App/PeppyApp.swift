import SwiftUI

@main
struct PeppyApp: App {
    @UIApplicationDelegateAdaptor(PeppyAppDelegate.self)
    private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies: Dependencies
    private let showsProfileSettingsVisualQA: Bool
    private let showsNotificationSettingsVisualQA: Bool

    init() {
        #if DEBUG
        let showsProfileSettingsVisualQA = ProcessInfo.processInfo.arguments.contains(
            "-profile-settings-visual-qa"
        )
        let showsNotificationSettingsVisualQA = ProcessInfo.processInfo.arguments.contains(
            "-notification-settings-visual-qa"
        )
        #else
        let showsProfileSettingsVisualQA = false
        let showsNotificationSettingsVisualQA = false
        #endif

        self.showsProfileSettingsVisualQA = showsProfileSettingsVisualQA
        self.showsNotificationSettingsVisualQA = showsNotificationSettingsVisualQA
        _dependencies = State(
            initialValue: (showsProfileSettingsVisualQA || showsNotificationSettingsVisualQA)
                ? .mock()
                : .live()
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if showsProfileSettingsVisualQA {
                    ProfileSettingsVisualQAHost(dependencies: dependencies)
                } else if showsNotificationSettingsVisualQA {
                    NotificationSettingsVisualQAHost(
                        dependencies: dependencies
                    )
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
                .withDependencies(dependencies)
                .preferredColorScheme(.light)
                .task {
                    appDelegate.pushRegistrationCoordinator =
                        dependencies.pushRegistrationCoordinator
                }
                .task(id: dependencies.appState.currentUser?.id) {
                    guard dependencies.appState.isAuthenticated else { return }
                    await dependencies.notificationReconciliation.startSession()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active,
                          dependencies.appState.isAuthenticated else {
                        return
                    }
                    Task {
                        await dependencies.notificationReconciliation.reconcile()
                    }
                }
                .onChange(of: dependencies.protocolStore.revision) {
                    guard dependencies.appState.isAuthenticated else { return }
                    Task {
                        await dependencies.notificationReconciliation.reconcile()
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSNotification.Name.NSSystemTimeZoneDidChange
                    )
                ) { _ in
                    guard dependencies.appState.isAuthenticated else { return }
                    Task {
                        await dependencies.notificationReconciliation.reconcile()
                    }
                }
        }
    }
}

#if DEBUG
/// Deterministic simulator entry point used only for same-viewport Figma QA.
/// Release builds cannot select or compile this route.
private struct ProfileSettingsVisualQAHost: View {
    let dependencies: Dependencies

    var body: some View {
        TabView(selection: .constant(Tab.profile)) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Group {
                    if tab == .profile {
                        NavigationStack {
                            ProfileSettingsView(
                                visualQAStore: dependencies.settingsStore,
                                weightUnitPreferences: dependencies.weightUnitPreferences,
                                now: { APIDateOnly.date(from: "2026-07-22")! }
                            )
                        }
                    } else {
                        Color.pepBackground
                    }
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .tint(.pepPrimary)
    }
}

private struct NotificationSettingsVisualQAHost: View {
    let dependencies: Dependencies

    var body: some View {
        TabView(selection: .constant(Tab.profile)) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Group {
                    if tab == .profile {
                        NavigationStack {
                            NotificationSettingsView(
                                visualQAStore: dependencies.settingsStore,
                                protocolStore: dependencies.protocolStore,
                                permissionService: dependencies.notifications,
                                scheduler: dependencies.localNotificationScheduler
                            )
                        }
                    } else {
                        Color.pepBackground
                    }
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .tint(.pepPrimary)
    }
}
#endif
