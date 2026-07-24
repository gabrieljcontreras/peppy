import XCTest
@testable import peppy

final class HelpAboutTests: XCTestCase {
    func testWebDestinationsUseOnlyApprovedURLs() {
        XCTAssertEqual(
            PeppyWebDestination.allCases.map(\.url.absoluteString),
            [
                "https://get-peppy.com/help",
                "https://get-peppy.com/contact",
                "https://get-peppy.com/feedback/bug",
                "https://get-peppy.com/feedback/feature",
                "https://get-peppy.com/about",
                "https://get-peppy.com/terms",
                "https://get-peppy.com/privacy"
            ]
        )
    }

    func testEveryDestinationIsHTTPSAndUsesPeppyHost() {
        for destination in PeppyWebDestination.allCases {
            XCTAssertEqual(destination.url.scheme, "https")
            XCTAssertEqual(destination.url.host, "get-peppy.com")
        }
    }

    func testMedicalDisclaimerMatchesApprovedNativeCopy() {
        XCTAssertEqual(
            HelpAboutContent.medicalDisclaimer,
            """
            Peppy provides informational health tracking and AI-assisted insights. It does not diagnose, treat, prevent, or cure any condition and is not a substitute for professional medical advice. Consult a qualified healthcare professional before starting, stopping, or changing a peptide, medication, or treatment. Contact local emergency services for urgent help.
            """
        )
    }

    func testFooterUsesDynamicVersionAndYear() {
        let version = SettingsAppVersion(
            shortVersion: "1.2.0",
            build: "123"
        )

        XCTAssertEqual(version.displayText, "App version 1.2.0 (123)")
        XCTAssertEqual(
            HelpAboutContent.copyrightText(year: 2026),
            "© 2026 Peppy. All rights reserved."
        )
    }
}
