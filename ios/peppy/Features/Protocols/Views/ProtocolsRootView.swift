import SwiftUI

struct ProtocolsRootView: View {
    private let store: ProtocolStore
    private let api: APIClientProtocol
    @State private var path: [ProtocolRoute] = []
    @State private var listModel: ProtocolListViewModel

    init(store: ProtocolStore, api: APIClientProtocol) {
        self.store = store
        self.api = api
        _listModel = State(initialValue: ProtocolListViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ProtocolListView(model: listModel) { route in
                path.append(route)
            }
            .navigationDestination(for: ProtocolRoute.self) { route in
                destination(for: route)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: ProtocolRoute) -> some View {
        switch route {
        case .detail(let id):
            ProtocolRoutePlaceholderView(
                title: title(for: id) ?? "Protocol",
                systemImage: "list.bullet.rectangle"
            )
        case .create:
            ProtocolRoutePlaceholderView(title: "New protocol", systemImage: "plus.circle")
        case .edit:
            ProtocolRoutePlaceholderView(title: "Edit protocol", systemImage: "pencil")
        case .addCompound:
            ProtocolRoutePlaceholderView(title: "Add compound", systemImage: "plus.circle")
        case .editCompound:
            ProtocolRoutePlaceholderView(title: "Edit compound", systemImage: "pencil")
        case .logDose:
            ProtocolRoutePlaceholderView(title: "Log dose", systemImage: "calendar.badge.plus")
        case .starterSetup(let protocolID, let compounds):
            StarterProtocolSetupView(
                protocolID: protocolID,
                compounds: compounds,
                api: api,
                embedsInNavigationStack: false
            ) {
                Task { await store.loadProtocols(force: true) }
            }
        }
    }

    private func title(for id: UUID) -> String? {
        if let listedProtocol = store.protocols.first(where: { $0.id == id }) {
            return listedProtocol.name
        }
        if let selectedProtocol = store.selectedProtocol, selectedProtocol.id == id {
            return selectedProtocol.name
        }
        return nil
    }
}

private struct ProtocolRoutePlaceholderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
                .frame(width: 72, height: 72)
                .background(Color.pepPrimaryMuted)
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let dependencies = Dependencies.mock()
    ProtocolsRootView(store: dependencies.protocolStore, api: dependencies.api)
}
