import Foundation
import XCTest
@testable import peppy

final class SettingsAPIContractTests: XCTestCase {
    func testSettingsEndpointsUseApprovedContracts() {
        XCTAssertEqual(Endpoint.getProfile.path, "/profile/onboarding")
        XCTAssertEqual(Endpoint.getProfile.method, .get)
        XCTAssertEqual(
            Endpoint.updateProfile(makeProfileUpdateRequest()).requestID,
            "PATCH /profile/onboarding"
        )
        XCTAssertEqual(
            Endpoint.updateCurrentUser(.init(displayName: "Alex", timezone: nil)).requestID,
            "PATCH /auth/me"
        )
        XCTAssertEqual(
            Endpoint.changePassword(
                .init(currentPassword: "old-pass-1", newPassword: "new-pass-2")
            ).path,
            "/auth/change-password"
        )
        XCTAssertEqual(
            Endpoint.deleteAccount(.init(currentPassword: "old-pass-1")).requestID,
            "DELETE /auth/account"
        )
        XCTAssertEqual(
            Endpoint.createDataExport(makeExportRequest()).requestID,
            "POST /profile/export"
        )
    }

    func testProfileUpdateEncodesSnakeCaseDateAndNullClearedSelections() throws {
        let request = makeProfileUpdateRequest(secondaryGoal: nil, focusArea: nil)

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )

        XCTAssertEqual(json["schema_version"] as? Int, 1)
        XCTAssertEqual(json["preferred_height_unit"] as? String, "cm")
        XCTAssertEqual(json["preferred_weight_unit"] as? String, "kg")
        XCTAssertEqual(json["baseline_date"] as? String, "2026-07-20")
        XCTAssertEqual(json["primary_goal"] as? String, "track_protocols")
        XCTAssertTrue(json["secondary_goal"] is NSNull)
        XCTAssertTrue(json["focus_area"] is NSNull)
    }

    func testAccountAndSecurityRequestsEncodeExactBackendKeys() throws {
        let userJSON = try jsonObject(
            UpdateCurrentUserRequest(displayName: "Alex", timezone: nil)
        )
        XCTAssertEqual(userJSON["display_name"] as? String, "Alex")
        XCTAssertNil(userJSON["displayName"])
        XCTAssertNil(userJSON["timezone"])

        let passwordJSON = try jsonObject(
            ChangePasswordRequest(
                currentPassword: "old-pass-1",
                newPassword: "new-pass-2"
            )
        )
        XCTAssertEqual(passwordJSON["current_password"] as? String, "old-pass-1")
        XCTAssertEqual(passwordJSON["new_password"] as? String, "new-pass-2")

        let deletionJSON = try jsonObject(
            DeleteAccountRequest(currentPassword: "old-pass-1")
        )
        XCTAssertEqual(deletionJSON["current_password"] as? String, "old-pass-1")
    }

    func testAccountProfileDecodesSettingsFieldsAndDateOnlyBaseline() throws {
        let data = Data(
            """
            {
              "id": "5D7E4AB8-A410-4F82-943F-AE20F1F4E378",
              "schema_version": 1,
              "height_cm": 180.5,
              "preferred_height_unit": "cm",
              "weight_kg": 82.25,
              "preferred_weight_unit": "kg",
              "baseline_date": "2026-07-20",
              "primary_goal": "track_protocols",
              "secondary_goal": null,
              "focus_area": "understand_body"
            }
            """.utf8
        )

        let profile = try JSONDecoder().decode(AccountProfile.self, from: data)

        XCTAssertEqual(profile.schemaVersion, 1)
        XCTAssertEqual(profile.heightCm, 180.5)
        XCTAssertEqual(profile.preferredHeightUnit, "cm")
        XCTAssertEqual(profile.weightKg, 82.25)
        XCTAssertEqual(profile.preferredWeightUnit, "kg")
        let baselineDate = try XCTUnwrap(profile.baselineDate)
        XCTAssertEqual(APIDateOnly.string(from: baselineDate), "2026-07-20")
        XCTAssertEqual(profile.primaryGoal, "track_protocols")
        XCTAssertNil(profile.secondaryGoal)
        XCTAssertEqual(profile.focusArea, "understand_body")
    }

    func testAccountProfileSupportsDeterministicCachedFixtures() throws {
        let baselineDate = try XCTUnwrap(APIDateOnly.date(from: "2026-07-20"))

        let profile = AccountProfile(
            id: UUID(uuidString: "5D7E4AB8-A410-4F82-943F-AE20F1F4E378")!,
            schemaVersion: 1,
            heightCm: 180.5,
            preferredHeightUnit: "cm",
            weightKg: 82.25,
            preferredWeightUnit: "kg",
            baselineDate: baselineDate,
            primaryGoal: "track_protocols",
            secondaryGoal: nil,
            focusArea: "understand_body"
        )

        XCTAssertEqual(profile.baselineDate, baselineDate)
        XCTAssertEqual(profile.primaryGoal, "track_protocols")
    }

    func testNotificationPreferencesDecodeExpandedReminderContract() throws {
        let data = Data(
            """
            {
              "id": "72F51E87-29DB-4FC1-BC80-C5F821182460",
              "insights_enabled": true,
              "alert_severity_only": false,
              "dose_reminders_enabled": true,
              "daily_checkin_reminders_enabled": true,
              "daily_checkin_time": "09:00:00",
              "detailed_previews_enabled": false,
              "quiet_hours_start": "22:00:00",
              "quiet_hours_end": "07:00:00",
              "dose_reminders": [
                {
                  "compound_id": "61251170-8D35-42F3-94E6-61BEBE7D52A9",
                  "local_time": "08:30:00",
                  "enabled": true
                }
              ]
            }
            """.utf8
        )

        let preferences = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        XCTAssertTrue(preferences.doseRemindersEnabled)
        XCTAssertTrue(preferences.dailyCheckinRemindersEnabled)
        XCTAssertEqual(preferences.dailyCheckinTime, "09:00:00")
        XCTAssertFalse(preferences.detailedPreviewsEnabled)
        XCTAssertEqual(preferences.doseReminders.count, 1)
        XCTAssertEqual(preferences.doseReminders.first?.localTime, "08:30:00")
    }

    func testNotificationUpdateEncodesExactBackendKeys() throws {
        let request = UpdateNotificationPreferencesRequest(
            insightsEnabled: true,
            alertSeverityOnly: false,
            doseRemindersEnabled: true,
            dailyCheckinRemindersEnabled: true,
            dailyCheckinTime: "09:00:00",
            detailedPreviewsEnabled: false,
            quietHoursStart: "22:00:00",
            quietHoursEnd: "07:00:00",
            doseReminders: [
                .init(
                    compoundID: UUID(uuidString: "61251170-8D35-42F3-94E6-61BEBE7D52A9")!,
                    localTime: "08:30:00",
                    enabled: true
                )
            ]
        )

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )

        XCTAssertEqual(json["insights_enabled"] as? Bool, true)
        XCTAssertEqual(json["dose_reminders_enabled"] as? Bool, true)
        XCTAssertEqual(json["daily_checkin_reminders_enabled"] as? Bool, true)
        XCTAssertEqual(json["detailed_previews_enabled"] as? Bool, false)
        let doseReminders = try XCTUnwrap(json["dose_reminders"] as? [[String: Any]])
        XCTAssertEqual(doseReminders.first?["compound_id"] as? String, "61251170-8D35-42F3-94E6-61BEBE7D52A9")
        XCTAssertEqual(doseReminders.first?["local_time"] as? String, "08:30:00")
    }

    func testNotificationUpdateEncodesNullForClearedScheduleTimes() throws {
        let request = UpdateNotificationPreferencesRequest(
            insightsEnabled: true,
            alertSeverityOnly: false,
            doseRemindersEnabled: false,
            dailyCheckinRemindersEnabled: false,
            dailyCheckinTime: nil,
            detailedPreviewsEnabled: false,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            doseReminders: []
        )

        let json = try jsonObject(request)

        XCTAssertTrue(json["daily_checkin_time"] is NSNull)
        XCTAssertTrue(json["quiet_hours_start"] is NSNull)
        XCTAssertTrue(json["quiet_hours_end"] is NSNull)
    }

    func testDataExportEncodesRequiredSelectionsFormatAndDateOnlyRange() throws {
        let request = makeExportRequest()

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )

        XCTAssertEqual(json["format"] as? String, "csv")
        XCTAssertEqual(json["include_protocols"] as? Bool, true)
        XCTAssertEqual(json["include_checkins"] as? Bool, false)
        XCTAssertEqual(json["include_insights"] as? Bool, true)
        XCTAssertEqual(json["start_date"] as? String, "2026-07-01")
        XCTAssertEqual(json["end_date"] as? String, "2026-07-20")
    }

    func testMockDownloadReturnsConfiguredFileAndLogsMethodQualifiedRequest() async throws {
        let api = MockAPIClient()
        let endpoint = Endpoint.createDataExport(makeExportRequest())
        let expected = DownloadedFile(
            url: URL(fileURLWithPath: "/tmp/peppy-export.zip"),
            suggestedFilename: "peppy-export.zip"
        )
        api.setMockDownload(expected, for: endpoint)

        let downloaded = try await api.download(endpoint)

        XCTAssertEqual(downloaded, expected)
        XCTAssertEqual(api.requestLog.map(\.requestID), ["POST /profile/export"])
    }

    func testDownloadStreamsAuthenticatedResponseAndUsesContentDispositionFilename() async throws {
        let body = Data("streamed export bytes".utf8)
        let fixture = try makeAPIClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return .init(
                statusCode: 200,
                headers: [
                    "Content-Disposition": "attachment; filename=\"peppy-export.zip\"",
                    "Content-Type": "application/zip"
                ],
                body: body
            )
        }

        let downloaded = try await fixture.client.download(.createDataExport(makeExportRequest()))

        XCTAssertEqual(downloaded.suggestedFilename, "peppy-export.zip")
        XCTAssertEqual(try Data(contentsOf: downloaded.url), body)
    }

    func testDownloadRejectsUnsafeContentDispositionFilenames() async throws {
        let unsafeDispositions = [
            "attachment; filename*=UTF-8''..%2Fsecret.csv",
            "attachment; filename=\"..\"",
            "attachment; filename*=UTF-8''control%00.csv",
            "attachment; filename=\"\(String(repeating: "a", count: 256)).csv\""
        ]

        for disposition in unsafeDispositions {
            let fixture = try makeAPIClient { _ in
                .init(
                    statusCode: 200,
                    headers: ["Content-Disposition": disposition],
                    body: Data("export".utf8)
                )
            }

            let downloaded = try await fixture.client.download(
                .createDataExport(makeExportRequest())
            )

            XCTAssertEqual(
                downloaded.suggestedFilename,
                "peppy-export",
                "Expected safe fallback for \(disposition)"
            )
        }
    }

    func testDownloadDecodesCaseInsensitiveRFC5987Filename() async throws {
        let fixture = try makeAPIClient { _ in
            .init(
                statusCode: 200,
                headers: [
                    "Content-Disposition": "attachment; filename*=utf-8''peppy%20export.csv"
                ],
                body: Data("export".utf8)
            )
        }

        let downloaded = try await fixture.client.download(.createDataExport(makeExportRequest()))

        XCTAssertEqual(downloaded.suggestedFilename, "peppy export.csv")
    }

    func testDownloadRejectsNonSuccessResponse() async throws {
        let fixture = try makeAPIClient { _ in
            .init(statusCode: 403, headers: [:], body: Data())
        }

        do {
            _ = try await fixture.client.download(.createDataExport(makeExportRequest()))
            XCTFail("Expected forbidden download to throw")
        } catch let error as APIError {
            XCTAssertEqual(error, .forbidden)
        }
    }

    func testDownloadRefreshesOnceAfterUnauthorizedAndRetriesWithNewToken() async throws {
        var exportAttempts = 0
        var refreshAttempts = 0
        let fixture = try makeAPIClient { request in
            switch request.url?.path {
            case "/api/v1/profile/export":
                exportAttempts += 1
                if exportAttempts == 1 {
                    XCTAssertEqual(
                        request.value(forHTTPHeaderField: "Authorization"),
                        "Bearer access-token"
                    )
                    return .init(statusCode: 401, headers: [:], body: Data())
                }
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Authorization"),
                    "Bearer refreshed-access-token"
                )
                return .init(
                    statusCode: 200,
                    headers: ["Content-Disposition": "attachment; filename=\"peppy-export.pdf\""],
                    body: Data("pdf bytes".utf8)
                )

            case "/api/v1/auth/refresh":
                refreshAttempts += 1
                XCTAssertEqual(request.httpMethod, "POST")
                return .init(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Data(
                        """
                        {
                          "access_token": "refreshed-access-token",
                          "refresh_token": "refreshed-refresh-token",
                          "token_type": "bearer"
                        }
                        """.utf8
                    )
                )

            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                return .init(statusCode: 500, headers: [:], body: Data())
            }
        }
        try fixture.keychain.save("refresh-token", for: KeychainKeys.refreshToken)

        let downloaded = try await fixture.client.download(.createDataExport(makeExportRequest()))

        XCTAssertEqual(downloaded.suggestedFilename, "peppy-export.pdf")
        XCTAssertEqual(exportAttempts, 2)
        XCTAssertEqual(refreshAttempts, 1)
        XCTAssertEqual(fixture.keychain.get(KeychainKeys.accessToken), "refreshed-access-token")
        XCTAssertEqual(fixture.keychain.get(KeychainKeys.refreshToken), "refreshed-refresh-token")
    }
}

private extension SettingsAPIContractTests {
    func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        )
    }

    func makeProfileUpdateRequest(
        secondaryGoal: String? = "build_habits",
        focusArea: String? = "understand_body"
    ) -> ProfileUpdateRequest {
        ProfileUpdateRequest(
            schemaVersion: 1,
            heightCm: 180.5,
            preferredHeightUnit: "cm",
            weightKg: 82.25,
            preferredWeightUnit: "kg",
            baselineDate: APIDateOnly.date(from: "2026-07-20"),
            primaryGoal: "track_protocols",
            secondaryGoal: secondaryGoal,
            focusArea: focusArea
        )
    }

    func makeExportRequest() -> DataExportRequest {
        DataExportRequest(
            format: .csv,
            includeProtocols: true,
            includeCheckins: false,
            includeInsights: true,
            startDate: APIDateOnly.date(from: "2026-07-01"),
            endDate: APIDateOnly.date(from: "2026-07-20")
        )
    }

    func makeAPIClient(
        handler: @escaping (URLRequest) throws -> SettingsStubResponse
    ) throws -> (client: APIClient, keychain: MockKeychainService) {
        SettingsURLProtocolStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsURLProtocolStub.self]
        let keychain = MockKeychainService()
        try keychain.save("access-token", for: KeychainKeys.accessToken)
        return (
            APIClient(
                baseURL: URL(string: "https://settings.example/api/v1")!,
                session: URLSession(configuration: configuration),
                keychain: keychain
            ),
            keychain
        )
    }
}

private struct SettingsStubResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
}

private final class SettingsURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> SettingsStubResponse)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let stub = try handler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: stub.statusCode,
                    httpVersion: nil,
                    headerFields: stub.headers
                  ) else {
                throw URLError(.badServerResponse)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
