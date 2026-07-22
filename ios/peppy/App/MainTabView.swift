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

/// Compact bottom navigation measured from the approved 853 × 1844 Settings
/// frames. Its 29-point content region plus the iPhone home-indicator inset
/// produces the 63-point visible bar in the reference.
enum PeppyTabBarFigmaLayout {
    static let visibleHeight: CGFloat = 63
    static let contentHeight: CGFloat = 29
    static let minimumTapTarget: CGFloat = 44
    static let iconSize: CGFloat = 15
    static let labelSize: CGFloat = 7
}

enum PeppyTabBarPresentation {
    static func badgeText(for unreadCount: Int) -> String? {
        guard unreadCount > 0 else { return nil }
        return unreadCount > 99 ? "99+" : String(unreadCount)
    }

    static func accessibilityLabel(for tab: Tab, unreadInsightsCount: Int) -> String {
        guard tab == .insights, unreadInsightsCount > 0 else { return tab.rawValue }
        return "Insights, \(unreadInsightsCount) unread"
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
                .tag(Tab.insights)

            ProfileTab()
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(.pepPrimary)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PeppyTabBar(
                selection: $navigation.selectedTab,
                unreadInsightsCount: deps.insightsStore.unreadCount
            )
        }
    }
}

struct PeppyTabBar: View {
    @Binding var selection: Tab
    var unreadInsightsCount = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 1) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: PeppyTabBarFigmaLayout.iconSize, weight: .regular))
                                .frame(width: 20, height: 17)

                            if tab == .insights,
                               let badgeText = PeppyTabBarPresentation.badgeText(
                                   for: unreadInsightsCount
                               ) {
                                Text(badgeText)
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 3)
                                    .frame(minWidth: 11, minHeight: 11)
                                    .background(Color.pepPrimary)
                                    .clipShape(Capsule())
                                    .offset(x: 6, y: -4)
                            }
                        }

                        Text(tab.rawValue)
                            .font(.system(size: PeppyTabBarFigmaLayout.labelSize, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? Color.pepPrimary : Color.pepTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: PeppyTabBarFigmaLayout.minimumTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    PeppyTabBarPresentation.accessibilityLabel(
                        for: tab,
                        unreadInsightsCount: unreadInsightsCount
                    )
                )
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .frame(height: PeppyTabBarFigmaLayout.contentHeight)
        .background(Color.pepSurface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.pepBorderLight)
                .frame(height: 1)
        }
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
