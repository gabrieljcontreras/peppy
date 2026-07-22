import SwiftUI
import XCTest
@testable import peppy

@MainActor
final class SettingsNavigationTests: XCTestCase {
    func testMoreRowsContainOnlyReleaseDestinations() {
        XCTAssertEqual(SettingsRootViewModel.releaseRows.map(\.route), [
            .notifications,
            .dataExport,
            .security,
            .help,
            .about,
            .legal
        ])
    }

    func testMoreRowsPreserveFigmaSectionOrderAndCopy() {
        XCTAssertEqual(
            SettingsRootViewModel.myDataRows.map(\.title),
            ["Notifications", "Data export"]
        )
        XCTAssertEqual(
            SettingsRootViewModel.accountAndAppRows.map(\.title),
            ["Security", "Help and support", "About peppy", "Legal"]
        )
        XCTAssertEqual(
            SettingsRootViewModel.releaseRows.map(\.subtitle),
            [
                "Manage your alerts and reminders",
                "Export your data",
                "Password, biometrics, and privacy",
                "FAQs and contact support",
                "Learn about our mission",
                "Terms of service and privacy policy"
            ]
        )
    }

    func testDeferredFigmaRowsAreNotExposed() {
        let visibleTitles = Set(SettingsRootViewModel.releaseRows.map(\.title))

        XCTAssertTrue(visibleTitles.isDisjoint(with: ["Labs", "Connected data", "Timeline"]))
    }

    func testProfileSummaryUsesDedicatedProfileRoute() {
        XCTAssertEqual(SettingsRootViewModel.profileRoute, .profile)
        XCTAssertFalse(SettingsRootViewModel.releaseRows.map(\.route).contains(.profile))
    }

    func testSettingsVersionUsesBundleShortVersionAndBuild() {
        let version = SettingsAppVersion(shortVersion: "1.2.0", build: "123")

        XCTAssertEqual(version.displayText, "App version 1.2.0 (123)")
    }

    func testSettingsRoutesRemainHashableForNavigationStackPath() {
        let routes: Set<SettingsRoute> = [
            .profile,
            .notifications,
            .dataExport,
            .security,
            .help,
            .about,
            .legal
        ]

        XCTAssertEqual(routes.count, 7)
    }

    func testSettingsRootPreservesExtractedFigmaGeometryAndAccessibleTapTargets() {
        XCTAssertEqual(SettingsFigmaLayout.referenceCanvasWidth, 853)
        XCTAssertEqual(SettingsFigmaLayout.referenceCanvasHeight, 1_844)
        XCTAssertEqual(SettingsFigmaLayout.horizontalPadding, 22)
        XCTAssertGreaterThanOrEqual(SettingsFigmaLayout.minimumTapTarget, 44)
    }

    func testProfilePresentationUsesConfirmedCachedIdentityAndFallbacks() {
        let user = User(
            id: UUID(),
            email: "alex.morgan@example.com",
            displayName: "Alex Morgan"
        )
        let unnamedUser = User(
            id: UUID(),
            email: "new@example.com",
            displayName: "  \n"
        )

        XCTAssertEqual(SettingsProfilePresentation.displayName(for: user), "Alex Morgan")
        XCTAssertEqual(SettingsProfilePresentation.email(for: user), "alex.morgan@example.com")
        XCTAssertEqual(SettingsProfilePresentation.displayName(for: unnamedUser), "Your profile")
        XCTAssertEqual(
            SettingsProfilePresentation.email(for: nil),
            "Complete your account details"
        )
    }

    func testProfileIdentityExpandsAtAccessibilityDynamicTypeSizes() {
        XCTAssertEqual(SettingsProfileLayout.identityLineLimit(for: .large), 1)
        XCTAssertNil(SettingsProfileLayout.identityLineLimit(for: .accessibility1))
    }
}
