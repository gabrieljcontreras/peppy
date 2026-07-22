import SwiftUI

@main
struct PeppyApp: App {
    @State private var dependencies: Dependencies
    private let showsProfileSettingsVisualQA: Bool

    init() {
        #if DEBUG
        let showsProfileSettingsVisualQA = ProcessInfo.processInfo.arguments.contains(
            "-profile-settings-visual-qa"
        )
        #else
        let showsProfileSettingsVisualQA = false
        #endif

        self.showsProfileSettingsVisualQA = showsProfileSettingsVisualQA
        _dependencies = State(
            initialValue: showsProfileSettingsVisualQA ? .mock() : .live()
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if showsProfileSettingsVisualQA {
                    ProfileSettingsVisualQAHost(dependencies: dependencies)
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
                .withDependencies(dependencies)
                .preferredColorScheme(.light)
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
#endif
