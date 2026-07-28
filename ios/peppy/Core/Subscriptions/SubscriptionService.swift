import Foundation
import StoreKit

/// A product as the paywall needs it: which plan, and what to print.
/// Prices always come from StoreKit so they are correct in every storefront.
struct PremiumProduct: Equatable, Sendable {
    let plan: PremiumPlan
    let displayPrice: String
    /// The struck-through "was" price, when the plan advertises a discount.
    let originalDisplayPrice: String?
}

/// A StoreKit-verified purchase, reduced to what the rest of the app needs:
/// the plan, and the signed payload the backend verifies.
struct VerifiedPurchase: Equatable, Sendable {
    let plan: PremiumPlan
    let signedTransaction: String
    let expiresAt: Date?
}

enum PurchaseOutcome: Equatable, Sendable {
    case success(VerifiedPurchase)
    case userCancelled
    /// Ask-to-Buy or another deferred approval. Entitlement arrives later
    /// through `transactionUpdates()`.
    case pending
}

enum SubscriptionError: Error, Equatable {
    case productUnavailable
    case unverifiedTransaction
    case failed(String)
}

protocol SubscriptionServicing: Sendable {
    func loadProducts() async throws -> [PremiumProduct]
    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome
    func restore() async throws -> PremiumEntitlement
    func currentEntitlement() async -> PremiumEntitlement
    /// Renewals, Ask-to-Buy approvals, and purchases made on other devices.
    func transactionUpdates() -> AsyncStream<VerifiedPurchase>
}

final class StoreKitSubscriptionService: SubscriptionServicing {
    private let cache = ProductCache()

    func loadProducts() async throws -> [PremiumProduct] {
        let identifiers = PremiumPlan.allCases.map(\.productID)
        let products = try await Product.products(for: identifiers)
        await cache.store(products)

        // Preserve PremiumPlan.allCases order rather than StoreKit's.
        return PremiumPlan.allCases.compactMap { plan in
            guard let product = products.first(where: { $0.id == plan.productID }) else {
                return nil
            }
            return PremiumProduct(
                plan: plan,
                displayPrice: product.displayPrice,
                originalDisplayPrice: Self.originalDisplayPrice(for: plan, product: product)
            )
        }
    }

    /// The advertised "was" price. Derived from the live product price and
    /// formatted in the product's own currency, so the discount claim stays
    /// truthful in every storefront instead of hardcoding "$49.99".
    private static func originalDisplayPrice(
        for plan: PremiumPlan,
        product: Product
    ) -> String? {
        guard plan == .yearly else { return nil }
        return product.priceFormatStyle.format(product.price * 2)
    }

    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        guard let product = await cache.product(for: plan.productID) else {
            throw SubscriptionError.productUnavailable
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            return .success(Self.purchase(from: transaction, jws: verification.jwsRepresentation))
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            throw SubscriptionError.failed("Unrecognized purchase result")
        }
    }

    func restore() async throws -> PremiumEntitlement {
        try await AppStore.sync()
        return await currentEntitlement()
    }

    func currentEntitlement() async -> PremiumEntitlement {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result),
                  let plan = PremiumPlan.plan(forProductID: transaction.productID) else {
                continue
            }
            if let revocation = transaction.revocationDate, revocation <= Date() {
                continue
            }
            if let expiry = transaction.expirationDate, expiry <= Date() {
                continue
            }
            return .premium(plan: plan, expires: transaction.expirationDate)
        }
        return .free
    }

    func transactionUpdates() -> AsyncStream<VerifiedPurchase> {
        AsyncStream { continuation in
            let task = Task.detached {
                for await result in Transaction.updates {
                    guard let transaction = try? Self.checkVerified(result) else { continue }
                    await transaction.finish()
                    continuation.yield(
                        Self.purchase(from: transaction, jws: result.jwsRepresentation)
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            // Never grant entitlement on a transaction StoreKit could not verify.
            throw SubscriptionError.unverifiedTransaction
        }
    }

    private static func purchase(
        from transaction: StoreKit.Transaction,
        jws: String
    ) -> VerifiedPurchase {
        VerifiedPurchase(
            plan: PremiumPlan.plan(forProductID: transaction.productID) ?? .yearly,
            signedTransaction: jws,
            expiresAt: transaction.expirationDate
        )
    }
}

/// Products loaded once and reused, so `purchase` never refetches.
private actor ProductCache {
    private var products: [String: Product] = [:]

    func store(_ loaded: [Product]) {
        for product in loaded {
            products[product.id] = product
        }
    }

    func product(for identifier: String) -> Product? {
        products[identifier]
    }
}
