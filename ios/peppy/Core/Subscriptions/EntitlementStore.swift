import Foundation
import Observation

/// The app's single answer to "may this account use premium features?".
///
/// StoreKit is the client's source of truth so the UI unlocks instantly and
/// works offline. The backend is the authority for data access, and a 402 from
/// any endpoint downgrades this store — that is the self-healing path when the
/// two disagree.
@MainActor
@Observable
final class EntitlementStore {
    private(set) var entitlement: PremiumEntitlement = .unknown

    var isPremium: Bool { entitlement.isPremium }

    /// A purchase StoreKit completed but the backend has not acknowledged.
    /// Retried on next refresh so a network blip never costs a purchase.
    private(set) var hasUnsyncedPurchase = false

    private let service: SubscriptionServicing
    private let api: APIClientProtocol
    private var pendingTransaction: String?
    /// Not observation-tracked: `@Observable` would make this a computed
    /// property, which `deinit` (nonisolated) may not touch.
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(service: SubscriptionServicing, api: APIClientProtocol) {
        self.service = service
        self.api = api
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Begins listening for renewals, Ask-to-Buy approvals, and purchases made
    /// on other devices. Called once at app launch; lives for the process.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let stream = self?.service.transactionUpdates() else { return }
            for await purchase in stream {
                await self?.adopt(purchase)
            }
        }
    }

    func refresh() async {
        if hasUnsyncedPurchase, let pendingTransaction {
            await sync(signedTransaction: pendingTransaction)
        }

        let storeKit = await service.currentEntitlement()
        if storeKit.isPremium {
            entitlement = storeKit
            return
        }

        // StoreKit sees nothing on this device. The server may still know
        // about a purchase made elsewhere, so ask before declaring free.
        do {
            let response: SubscriptionResponse = try await api.execute(.getSubscription)
            entitlement = response.entitlement
        } catch {
            entitlement = storeKit.isResolved ? storeKit : .free
        }
    }

    /// Returns the raw outcome so callers can distinguish a cancellation
    /// (say nothing) from an Ask-to-Buy deferral (explain the wait).
    @discardableResult
    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        let outcome = try await service.purchase(plan)

        if case .success(let purchase) = outcome {
            await adopt(purchase)
        }
        return outcome
    }

    @discardableResult
    func restore() async -> Bool {
        do {
            let restored = try await service.restore()
            entitlement = restored
            return restored.isPremium
        } catch {
            return false
        }
    }

    /// Called when any endpoint answers 402. The server is authoritative for
    /// access, so trust it over the local StoreKit cache.
    func markFreeFromServer() {
        entitlement = .free
    }

    func resetSession() {
        entitlement = .unknown
        hasUnsyncedPurchase = false
        pendingTransaction = nil
    }

    private func adopt(_ purchase: VerifiedPurchase) async {
        entitlement = .premium(plan: purchase.plan, expires: purchase.expiresAt)
        await sync(signedTransaction: purchase.signedTransaction)
    }

    private func sync(signedTransaction: String) async {
        do {
            let response: SubscriptionResponse = try await api.execute(
                .syncAppleTransaction(
                    AppleTransactionRequest(signedTransaction: signedTransaction)
                )
            )
            entitlement = response.entitlement
            hasUnsyncedPurchase = false
            pendingTransaction = nil
        } catch {
            // Keep the local grant. StoreKit already finished the transaction.
            hasUnsyncedPurchase = true
            pendingTransaction = signedTransaction
        }
    }
}
