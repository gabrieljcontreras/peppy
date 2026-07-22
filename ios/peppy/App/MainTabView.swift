import SwiftUI

enum Tab: String, CaseIterable {
    case home = "Home"
    case checkin = "Check-in"
    case protocols = "Protocols"
    case insights = "Insights"
    case profile = "More"

    var icon: String {
        switch self {
        case .home: return "house"
        case .checkin: return "checkmark.circle"
        case .protocols: return "cross.case"
        case .insights: return "chart.bar"
        case .profile: return "ellipsis"
        }
    }
}

/// Shared cross-tab navigation intent for the Check-in, Protocols, and
/// Insights stacks. The Dashboard (and any other tab) routes into them through
/// `showCheckin`/`show`/`showInsight`, which switch the selected tab before
/// replacing the stack so the route lands on a visible screen.
@MainActor
@Observable
final class ProtocolNavigationCoordinator {
    var selectedTab: Tab = .home
    var path: [ProtocolRoute] = []
    var insightsPath: [InsightRoute] = []
    var checkinPath: [CheckinRoute] = []

    func show(_ route: ProtocolRoute) {
        selectedTab = .protocols
        path = [route]
    }

    func showInsight(_ route: InsightRoute) {
        selectedTab = .insights
        insightsPath = [route]
    }

    func showInsightsTab() {
        selectedTab = .insights
        insightsPath = []
    }

    func showCheckin(_ route: CheckinRoute) {
        selectedTab = .checkin
        checkinPath = [route]
    }

    func showCheckinHub() {
        selectedTab = .checkin
        checkinPath = []
    }

    func resetCheckinNavigation() {
        checkinPath = []
        if selectedTab == .checkin {
            selectedTab = .home
        }
    }
}

struct MainTabView: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        @Bindable var navigation = deps.protocolNavigation
        TabView(selection: $navigation.selectedTab) {
            HomeTab()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            CheckinTab()
                .tabItem {
                    Label(Tab.checkin.rawValue, systemImage: Tab.checkin.icon)
                }
                .tag(Tab.checkin)

            ProtocolsTab()
                .tabItem {
                    Label(Tab.protocols.rawValue, systemImage: Tab.protocols.icon)
                }
                .tag(Tab.protocols)

            InsightsTab()
                .tabItem {
                    Label(Tab.insights.rawValue, systemImage: Tab.insights.icon)
                }
                .badge(deps.insightsStore.unreadCount)
                .tag(Tab.insights)

            ProfileTab()
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(.pepPrimary)
    }
}

// MARK: - Tab Views

struct HomeTab: View {
    var body: some View {
        DashboardView()
    }
}

struct CheckinTab: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        CheckinHubView(
            store: deps.checkinStore,
            preferences: deps.weightUnitPreferences,
            navigation: deps.protocolNavigation
        )
    }
}

struct ProtocolsTab: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        ProtocolsRootView(store: deps.protocolStore, navigation: deps.protocolNavigation)
    }
}

struct InsightsTab: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        InsightsListView(store: deps.insightsStore, navigation: deps.protocolNavigation)
    }
}

struct ProfileTab: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        SettingsRootView(store: deps.settingsStore) {
            deps.flow.logout()
        }
    }
}

#Preview {
    let dependencies = Dependencies.mock()
    if let api = dependencies.api as? MockAPIClient {
        api.setMockResponse(
            [
                Checkin(
                    id: UUID(),
                    userId: nil,
                    date: Date(),
                    weightKg: 74.8,
                    energyLevel: 7,
                    sleepQuality: 6,
                    appetiteLevel: 4,
                    mood: 6,
                    nausea: 0,
                    injectionSiteReaction: 2,
                    fatigue: 0,
                    headache: 0,
                    giIssues: 4,
                    notes: "Felt good overall.",
                    createdAt: nil,
                    updatedAt: nil
                ),
            ],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
    }
    return MainTabView()
        .withDependencies(dependencies)
}
