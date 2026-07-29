import XCTest
@testable import peppy

@MainActor
final class EntitlementStoreTests: XCTestCase {
    private func makeStore(
        service: MockSubscriptionService = MockSubscriptionService(),
        api: MockAPIClient = MockAPIClient()
    ) -> (EntitlementStore, MockSubscriptionService, MockAPIClient) {
        (EntitlementStore(service: service, api: api), service, api)
    }

    func testStartsUnknown() {
        let (store, _, _) = makeStore()
        XCTAssertEqual(store.entitlement, .unknown)
        XCTAssertFalse(store.isPremium)
    }

    func testRefreshAdoptsStoreKitPremium() async {
        let service = MockSubscriptionService()
        service.entitlement = .premium(plan: .yearly, expires: nil)
        let (store, _, _) = makeStore(service: service)

        await store.refresh()

        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(store.entitlement.plan, .yearly)
    }

    func testRefreshFallsBackToServerWhenStoreKitHasNothing() async {
        let service = MockSubscriptionService()
        service.entitlement = .free
        let api = MockAPIClient()
        api.setMockResponse(
            SubscriptionResponse(
                tier: "premium",
                productID: PremiumPlan.monthly.productID,
                expiresAt: Date().addingTimeInterval(86_400),
                isPremium: true
            ),
            for: Endpoint.getSubscription
        )
        let (store, _, _) = makeStore(service: service, api: api)

        await store.refresh()

        // A subscription bought on another device is honored even before this
        // device's StoreKit cache catches up.
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(store.entitlement.plan, .monthly)
    }

    func testPurchaseGrantsPremiumAndSyncsToBackend() async throws {
        let service = MockSubscriptionService()
        let (store, _, _) = makeStore(service: service)

        let outcome = try await store.purchase(.yearly)

        guard case .success = outcome else {
            return XCTFail("Expected success, got \(outcome)")
        }
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(service.recordedPurchases, [.yearly])
    }

    func testCancelledPurchaseLeavesEntitlementUnchanged() async throws {
        let service = MockSubscriptionService()
        service.purchaseResult = .userCancelled
        let (store, _, _) = makeStore(service: service)
        await store.refresh()

        let outcome = try await store.purchase(.monthly)

        XCTAssertEqual(outcome, .userCancelled)
        XCTAssertFalse(store.isPremium)
    }

    func testPendingPurchaseIsDistinctFromCancellation() async throws {
        let service = MockSubscriptionService()
        service.purchaseResult = .pending
        let (store, _, _) = makeStore(service: service)
        await store.refresh()

        let outcome = try await store.purchase(.monthly)

        // Ask-to-Buy. Entitlement arrives later via transactionUpdates().
        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(store.isPremium)
    }

    func testPurchaseStaysPremiumWhenBackendSyncFails() async throws {
        let service = MockSubscriptionService()
        let api = MockAPIClient()
        api.setMockError(APIError.networkUnavailable, for: Endpoint.syncAppleTransaction(
            AppleTransactionRequest(signedTransaction: "mock.jws.yearly")
        ))
        let (store, _, _) = makeStore(service: service, api: api)

        let outcome = try await store.purchase(.yearly)

        // StoreKit already took the money and finished the transaction; a
        // failed sync must never cost the user their purchase.
        guard case .success = outcome else {
            return XCTFail("Expected success, got \(outcome)")
        }
        XCTAssertTrue(store.isPremium)
        XCTAssertTrue(store.hasUnsyncedPurchase)
    }

    func testMarkFreeFromServerDowngrades() async {
        let service = MockSubscriptionService()
        service.entitlement = .premium(plan: .yearly, expires: nil)
        let (store, _, _) = makeStore(service: service)
        await store.refresh()
        XCTAssertTrue(store.isPremium)

        store.markFreeFromServer()

        XCTAssertEqual(store.entitlement, .free)
    }

    func testResetSessionReturnsToUnknown() async {
        let service = MockSubscriptionService()
        service.entitlement = .premium(plan: .lifetime, expires: nil)
        let (store, _, _) = makeStore(service: service)
        await store.refresh()

        store.resetSession()

        XCTAssertEqual(store.entitlement, .unknown)
    }

    func testRestoreAdoptsRestoredEntitlement() async {
        let service = MockSubscriptionService()
        service.restoreResult = .premium(plan: .lifetime, expires: nil)
        let (store, _, _) = makeStore(service: service)

        let restored = await store.restore()

        XCTAssertTrue(restored)
        XCTAssertEqual(store.entitlement.plan, .lifetime)
    }

    func testRestoreWithoutPriorPurchaseReportsFalse() async {
        let service = MockSubscriptionService()
        service.restoreResult = .free
        let (store, _, _) = makeStore(service: service)

        let restored = await store.restore()

        XCTAssertFalse(restored)
        XCTAssertEqual(store.entitlement, .free)
    }
}
