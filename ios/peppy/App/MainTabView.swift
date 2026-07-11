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

/// Shared navigation intent for the Protocols stack. The Dashboard (and any
/// other tab) routes into Protocols through `show`, which switches the selected
/// tab before replacing the stack so the route lands on a visible screen.
@MainActor
@Observable
final class ProtocolNavigationCoordinator {
    var selectedTab: Tab = .home
    var path: [ProtocolRoute] = []

    func show(_ route: ProtocolRoute) {
        selectedTab = .protocols
        path = [route]
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
    }
}

// MARK: - Placeholder Tab Views

struct HomeTab: View {
    var body: some View {
        DashboardView()
    }
}

struct CheckinTab: View {
    var body: some View {
        CheckinView()
    }
}

struct ProtocolsTab: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        ProtocolsRootView(store: deps.protocolStore, navigation: deps.protocolNavigation)
    }
}

struct InsightsTab: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(title: "AI Insights", icon: "lightbulb.fill")
                .navigationTitle("Insights")
        }
    }
}

struct ProfileTab: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(title: "Settings", icon: "ellipsis.circle")
                .navigationTitle("More")
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.pepPrimary)

            Text(title)
                .pepTitle2()

            Text("Coming soon...")
                .pepSubheadline()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pepBackground)
    }
}

#Preview {
    MainTabView()
        .withDependencies(.mock())
}
