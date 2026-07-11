import SwiftUI

struct ProtocolsRootView: View {
    private let store: ProtocolStore
    @State private var path: [ProtocolRoute] = []
    @State private var listModel: ProtocolListViewModel

    init(store: ProtocolStore) {
        self.store = store
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
            ProtocolDetailView(protocolID: id, store: store) { route in
                path.append(route)
            }
        case .create:
            ProtocolEditorView(mode: .create, store: store) { savedID in
                path.removeLast()
                path.append(.detail(savedID))
            }
        case .edit(let id):
            if let protocolValue = protocolValue(for: id) {
                ProtocolEditorView(mode: .edit(protocolValue), store: store) { _ in
                    path.removeLast()
                }
            } else {
                ProtocolRoutePlaceholderView(title: "Edit protocol", systemImage: "pencil")
            }
        case .addCompound(let protocolID):
            CompoundEditorView(
                mode: .create,
                screenTitle: "Add compound",
                submitTitle: "Add compound"
            ) { draft in
                guard let request = draft.createRequest else {
                    return "Complete every required compound field."
                }
                let added = await store.addCompound(protocolID: protocolID, request: request)
                return added == nil ? (store.errorMessage ?? "Something went wrong. Please try again.") : nil
            }
        case .editCompound(let protocolID, let compoundID):
            if let compound = compound(id: compoundID, protocolID: protocolID) {
                CompoundEditorView(
                    mode: .edit(CompoundDraft(compound: compound)),
                    screenTitle: "Edit compound",
                    subtitle: "Update this compound's details.",
                    submitTitle: "Save compound"
                ) { draft in
                    guard let request = draft.updateRequest else {
                        return "Complete every required compound field."
                    }
                    let updated = await store.updateCompound(id: compoundID, request: request)
                    return updated == nil ? (store.errorMessage ?? "Something went wrong. Please try again.") : nil
                }
            } else {
                ProtocolRoutePlaceholderView(title: "Edit compound", systemImage: "pencil")
            }
        case .logDose(let protocolID, let compoundID):
            if let protocolValue = protocolValue(for: protocolID),
               let compound = Self.doseLogCompound(in: protocolValue, compoundID: compoundID) {
                DoseLogView(
                    protocol: protocolValue,
                    compound: compound,
                    store: store
                ) {
                    Task {
                        await store.select(protocolID)
                        await store.loadDoseLogs(protocolID: protocolID)
                    }
                }
            } else {
                ProtocolRoutePlaceholderView(title: "Log dose", systemImage: "calendar.badge.plus")
            }
        case .starterSetup(let protocolID, let compounds):
            StarterProtocolSetupView(
                protocolID: protocolID,
                compounds: compounds,
                store: store,
                embedsInNavigationStack: false
            )
        }
    }

    private func protocolValue(for id: UUID) -> ProtocolModel? {
        if let selected = store.selectedProtocol, selected.id == id {
            return selected
        }
        return store.protocols.first { $0.id == id }
    }

    private func compound(id: UUID, protocolID: UUID) -> Compound? {
        protocolValue(for: protocolID)?.compounds.first { $0.id == id }
    }

    static func doseLogCompound(in protocolValue: ProtocolModel, compoundID: UUID?) -> Compound? {
        if let compoundID {
            return protocolValue.compounds.first { $0.id == compoundID }
        }
        return protocolValue.compounds.first
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
    ProtocolsRootView(store: dependencies.protocolStore)
}
