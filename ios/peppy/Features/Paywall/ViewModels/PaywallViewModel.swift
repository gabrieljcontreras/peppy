import Foundation
import Observation

@MainActor
@Observable
final class PaywallViewModel {
    enum PaywallState: Equatable {
        case loading
        case ready
        case purchasing
        case loadFailed(String)
    }

    private(set) var state: PaywallState = .loading
    private(set) var products: [PremiumProduct] = []
    private(set) var selectedPlan: PremiumPlan = .yearly
    private(set) var errorMessage: String?
    /// Flips true once the user is entitled, by purchase or restore. The view
    /// observes this to dismiss.
    private(set) var didPurchase = false

    private let service: SubscriptionServicing
    private let entitlements: EntitlementStore

    init(service: SubscriptionServicing, entitlements: EntitlementStore) {
        self.service = service
        self.entitlements = entitlements
    }

    var selectedProduct: PremiumProduct? {
        products.first { $0.plan == selectedPlan }
    }

    /// "Cancel Anytime" would be untrue under a one-time Lifetime purchase.
    var showsCancelAnytime: Bool {
        selectedPlan.isRecurring
    }

    var isPurchasing: Bool {
        state == .purchasing
    }

    func load() async {
        state = .loading
        errorMessage = nil
        do {
            products = try await service.loadProducts()
            guard !products.isEmpty else {
                state = .loadFailed("Plans are unavailable right now.")
                return
            }
            if !products.contains(where: { $0.plan == selectedPlan }) {
                selectedPlan = products[0].plan
            }
            state = .ready
        } catch {
            products = []
            state = .loadFailed("We couldn't load plans. Check your connection and try again.")
        }
    }

    func select(_ plan: PremiumPlan) {
        guard state != .purchasing else { return }
        selectedPlan = plan
        errorMessage = nil
    }

    func purchase() async {
        guard state == .ready else { return }
        state = .purchasing
        errorMessage = nil

        do {
            let outcome = try await entitlements.purchase(selectedPlan)
            state = .ready
            switch outcome {
            case .success:
                didPurchase = true
            case .pending:
                errorMessage =
                    "Waiting for approval. You'll get Premium as soon as it's approved."
            case .userCancelled:
                // The user chose to back out. Saying anything would be noise.
                break
            }
        } catch {
            state = .ready
            errorMessage = "That purchase didn't go through. Please try again."
        }
    }

    func restore() async {
        guard state == .ready else { return }
        state = .purchasing
        errorMessage = nil

        let restored = await entitlements.restore()
        state = .ready

        if restored {
            didPurchase = true
        } else {
            errorMessage = "No previous purchase found to restore."
        }
    }
}
