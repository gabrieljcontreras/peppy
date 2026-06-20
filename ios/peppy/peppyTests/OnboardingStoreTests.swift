import XCTest
@testable import peppy

final class OnboardingStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: UserDefaultsOnboardingStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "OnboardingStoreTests")!
        defaults.removePersistentDomain(forName: "OnboardingStoreTests")
        store = UserDefaultsOnboardingStore(defaults: defaults)
    }

    func testAnonymousDraftRoundTrips() {
        var draft = OnboardingDraft()
        draft.age = 32
        store.saveAnonymousDraft(draft)
        XCTAssertEqual(store.loadAnonymousDraft()?.age, 32)
    }

    func testAssociatingDraftMovesItToUserID() {
        var draft = OnboardingDraft()
        draft.selectedPeptides = ["Retatrutide"]
        store.saveAnonymousDraft(draft)

        let userID = UUID()
        store.associateAnonymousDraft(with: userID)

        XCTAssertNil(store.loadAnonymousDraft())
        XCTAssertEqual(store.loadDraft(for: userID)?.selectedPeptides, ["Retatrutide"])
        XCTAssertTrue(store.hasKnownAccount)
    }

    func testMalformedDraftIsClearedWithoutCrashing() {
        defaults.set(Data("broken".utf8), forKey: "peppy.onboarding.anonymous")
        XCTAssertNil(store.loadAnonymousDraft())
        XCTAssertNil(defaults.data(forKey: "peppy.onboarding.anonymous"))
    }
}
