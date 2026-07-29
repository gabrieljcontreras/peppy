import Foundation

/// Deterministic `SubscriptionServicing` for previews and tests. Every
/// outcome the paywall must handle is scriptable without a store connection.
final class MockSubscriptionService: SubscriptionServicing, @unchecked Sendable {
    var products: [PremiumProduct] = [
        PremiumProduct(plan: .yearly, displayPrice: "$24.99", originalDisplayPrice: "$49.99"),
        PremiumProduct(plan: .monthly, displayPrice: "$7.99", originalDisplayPrice: nil),
        PremiumProduct(plan: .lifetime, displayPrice: "$139.99", originalDisplayPrice: nil)
    ]
    var loadProductsError: Error?
    var purchaseError: Error?
    var purchaseResult: PurchaseOutcome?
    var restoreResult: PremiumEntitlement = .free
    var entitlement: PremiumEntitlement = .free

    private(set) var recordedPurchases: [PremiumPlan] = []
    private(set) var restoreCallCount = 0

    private var updatesContinuation: AsyncStream<VerifiedPurchase>.Continuation?

    func loadProducts() async throws -> [PremiumProduct] {
        if let loadProductsError { throw loadProductsError }
        return products
    }

    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        recordedPurchases.append(plan)
        if let purchaseError { throw purchaseError }
        if let purchaseResult { return purchaseResult }
        return .success(
            VerifiedPurchase(
                plan: plan,
                signedTransaction: "mock.jws.\(plan.rawValue)",
                expiresAt: plan.isRecurring ? Date().addingTimeInterval(31_536_000) : nil
            )
        )
    }

    func restore() async throws -> PremiumEntitlement {
        restoreCallCount += 1
        return restoreResult
    }

    func currentEntitlement() async -> PremiumEntitlement {
        entitlement
    }

    func transactionUpdates() -> AsyncStream<VerifiedPurchase> {
        AsyncStream { continuation in
            self.updatesContinuation = continuation
        }
    }

    /// Drives the renewal / Ask-to-Buy path from a test.
    func emit(_ purchase: VerifiedPurchase) {
        updatesContinuation?.yield(purchase)
    }
}
