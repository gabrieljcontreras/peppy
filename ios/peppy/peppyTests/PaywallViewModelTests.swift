import XCTest
@testable import peppy

@MainActor
final class PaywallViewModelTests: XCTestCase {
    private func makeModel(
        service: MockSubscriptionService = MockSubscriptionService()
    ) -> (PaywallViewModel, MockSubscriptionService, EntitlementStore) {
        let store = EntitlementStore(service: service, api: MockAPIClient())
        return (PaywallViewModel(service: service, entitlements: store), service, store)
    }

    func testYearlyIsPreselected() {
        let (model, _, _) = makeModel()
        XCTAssertEqual(model.selectedPlan, .yearly)
    }

    func testLoadPopulatesProductsInDisplayOrder() async {
        let (model, _, _) = makeModel()

        await model.load()

        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.products.map(\.plan), [.yearly, .monthly, .lifetime])
    }

    func testLoadFailureSurfacesRetryableState() async {
        let service = MockSubscriptionService()
        service.loadProductsError = SubscriptionError.productUnavailable
        let (model, _, _) = makeModel(service: service)

        await model.load()

        guard case .loadFailed = model.state else {
            return XCTFail("Expected loadFailed, got \(model.state)")
        }
        XCTAssertTrue(model.products.isEmpty)
    }

    func testSelectedProductFollowsSelection() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.select(.lifetime)

        XCTAssertEqual(model.selectedPlan, .lifetime)
        XCTAssertEqual(model.selectedProduct?.displayPrice, "$139.99")
    }

    func testCancelAnytimeHiddenForLifetime() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.select(.yearly)
        XCTAssertTrue(model.showsCancelAnytime)

        model.select(.lifetime)
        XCTAssertFalse(model.showsCancelAnytime)
    }

    func testSuccessfulPurchaseSetsDidPurchase() async {
        let (model, service, store) = makeModel()
        await model.load()

        await model.purchase()

        XCTAssertTrue(model.didPurchase)
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(service.recordedPurchases, [.yearly])
        XCTAssertEqual(model.state, .ready)
    }

    func testCancelledPurchaseIsSilent() async {
        let service = MockSubscriptionService()
        service.purchaseResult = .userCancelled
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.purchase()

        XCTAssertFalse(model.didPurchase)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.state, .ready)
    }

    func testPendingPurchaseExplainsTheWait() async {
        let service = MockSubscriptionService()
        service.purchaseResult = .pending
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.purchase()

        XCTAssertFalse(model.didPurchase)
        XCTAssertEqual(
            model.errorMessage,
            "Waiting for approval. You'll get Premium as soon as it's approved."
        )
    }

    func testFailedPurchaseShowsErrorAndStaysInteractive() async {
        let service = MockSubscriptionService()
        service.purchaseError = SubscriptionError.failed("Card declined")
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.purchase()

        XCTAssertFalse(model.didPurchase)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.state, .ready)
    }

    func testRestoreWithPurchaseSetsDidPurchase() async {
        let service = MockSubscriptionService()
        service.restoreResult = .premium(plan: .lifetime, expires: nil)
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.restore()

        XCTAssertTrue(model.didPurchase)
    }

    func testRestoreWithoutPurchaseExplainsWhy() async {
        let service = MockSubscriptionService()
        service.restoreResult = .free
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.restore()

        XCTAssertFalse(model.didPurchase)
        XCTAssertEqual(model.errorMessage, "No previous purchase found to restore.")
    }
}
