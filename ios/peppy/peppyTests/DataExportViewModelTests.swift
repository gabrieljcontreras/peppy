import Foundation
import XCTest
@testable import peppy

@MainActor
final class DataExportViewModelTests: XCTestCase {
    private let now = APIDateOnly.date(from: "2026-07-23")!

    func testDefaultsSelectAvailableCategoriesPDFAndAllTime() throws {
        let fixture = Fixture(now: now)

        XCTAssertTrue(fixture.model.includeProtocols)
        XCTAssertTrue(fixture.model.includeCheckins)
        XCTAssertTrue(fixture.model.includeInsights)
        XCTAssertEqual(fixture.model.selectedFormat, .pdf)
        XCTAssertEqual(fixture.model.selectedDatePreset, .allTime)

        let request = try fixture.model.exportRequest()
        XCTAssertNil(request.startDate)
        XCTAssertNil(request.endDate)
    }

    func testAllVisibleCategoriesCanBeDisabledForAccountOnlyExport() throws {
        let fixture = Fixture(now: now)
        fixture.model.includeProtocols = false
        fixture.model.includeCheckins = false
        fixture.model.includeInsights = false

        let request = try fixture.model.exportRequest()

        XCTAssertFalse(request.includeProtocols)
        XCTAssertFalse(request.includeCheckins)
        XCTAssertFalse(request.includeInsights)
    }

    func testThirtyAndNinetyDayPresetsUseInclusiveDateOnlyRanges() throws {
        let fixture = Fixture(now: now)

        fixture.model.selectedDatePreset = .last30Days
        var request = try fixture.model.exportRequest()
        XCTAssertEqual(
            request.startDate.map(APIDateOnly.string(from:)),
            "2026-06-24"
        )
        XCTAssertEqual(
            request.endDate.map(APIDateOnly.string(from:)),
            "2026-07-23"
        )

        fixture.model.selectedDatePreset = .last90Days
        request = try fixture.model.exportRequest()
        XCTAssertEqual(
            request.startDate.map(APIDateOnly.string(from:)),
            "2026-04-25"
        )
        XCTAssertEqual(
            request.endDate.map(APIDateOnly.string(from:)),
            "2026-07-23"
        )
    }

    func testDateRangesPreserveLocalCalendarDaysEastOfUTC() throws {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let tokyoNow = tokyoCalendar.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 23,
                hour: 12
            )
        )!
        let model = DataExportViewModel(
            api: MockAPIClient(),
            fileService: RecordingExportFileService(),
            calendar: tokyoCalendar,
            now: { tokyoNow }
        )

        model.selectedDatePreset = .last30Days
        var request = try model.exportRequest()
        XCTAssertEqual(
            request.startDate.map(APIDateOnly.string(from:)),
            "2026-06-24"
        )
        XCTAssertEqual(
            request.endDate.map(APIDateOnly.string(from:)),
            "2026-07-23"
        )

        model.selectedDatePreset = .custom
        model.customStartDate = tokyoCalendar.date(
            from: DateComponents(year: 2026, month: 7, day: 1)
        )!
        model.customEndDate = tokyoCalendar.date(
            from: DateComponents(year: 2026, month: 7, day: 20)
        )!
        request = try model.exportRequest()
        XCTAssertEqual(
            request.startDate.map(APIDateOnly.string(from:)),
            "2026-07-01"
        )
        XCTAssertEqual(
            request.endDate.map(APIDateOnly.string(from:)),
            "2026-07-20"
        )
    }

    func testDateRangesUseGregorianYearsWithNonGregorianUserCalendar() throws {
        let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!
        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.timeZone = tokyoTimeZone
        let tokyoNow = gregorianCalendar.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 23,
                hour: 12
            )
        )!
        var buddhistCalendar = Calendar(identifier: .buddhist)
        buddhistCalendar.timeZone = tokyoTimeZone
        let model = DataExportViewModel(
            api: MockAPIClient(),
            fileService: RecordingExportFileService(),
            calendar: buddhistCalendar,
            now: { tokyoNow }
        )
        model.selectedDatePreset = .last30Days

        let request = try model.exportRequest()

        XCTAssertEqual(
            request.startDate.map(APIDateOnly.string(from:)),
            "2026-06-24"
        )
        XCTAssertEqual(
            request.endDate.map(APIDateOnly.string(from:)),
            "2026-07-23"
        )
    }

    func testCustomRangeRejectsStartAfterEndAndFutureDates() {
        let fixture = Fixture(now: now)
        fixture.model.selectedDatePreset = .custom
        fixture.model.customStartDate = APIDateOnly.date(from: "2026-07-20")!
        fixture.model.customEndDate = APIDateOnly.date(from: "2026-07-10")!

        XCTAssertThrowsError(try fixture.model.exportRequest()) { error in
            XCTAssertEqual(
                error as? DataExportValidationError,
                .startAfterEnd
            )
        }

        fixture.model.customStartDate = APIDateOnly.date(from: "2026-07-20")!
        fixture.model.customEndDate = APIDateOnly.date(from: "2026-07-24")!

        XCTAssertThrowsError(try fixture.model.exportRequest()) { error in
            XCTAssertEqual(
                error as? DataExportValidationError,
                .futureDate
            )
        }
    }

    func testSelectedFormatMapsToRequestAndExpectedFileExtension() async {
        let fixture = Fixture(now: now)
        fixture.model.selectedFormat = .csv
        fixture.api.setMockDownload(
            DownloadedFile(
                url: fixture.downloadURL,
                suggestedFilename: "peppy-export.zip"
            ),
            for: .createDataExport(fixture.csvRequest)
        )

        await fixture.model.createExport()

        XCTAssertEqual(
            fixture.api.requestLog.compactMap(\.dataExportRequest).first?.format,
            .csv
        )
        XCTAssertEqual(fixture.files.preparedExpectedExtensions, ["zip"])
        XCTAssertEqual(fixture.model.shareURL, fixture.files.preparedURL)
    }

    func testFailureRetainsSelectionsAndMakesExportRetryable() async {
        let fixture = Fixture(now: now)
        fixture.model.includeProtocols = false
        fixture.model.includeCheckins = true
        fixture.model.includeInsights = false
        fixture.model.selectedFormat = .csv
        fixture.model.selectedDatePreset = .last30Days
        fixture.api.setMockError(
            .serverError,
            for: .createDataExport(fixture.csvRequest)
        )

        await fixture.model.createExport()

        XCTAssertFalse(fixture.model.includeProtocols)
        XCTAssertTrue(fixture.model.includeCheckins)
        XCTAssertFalse(fixture.model.includeInsights)
        XCTAssertEqual(fixture.model.selectedFormat, .csv)
        XCTAssertEqual(fixture.model.selectedDatePreset, .last30Days)
        XCTAssertFalse(fixture.model.isExporting)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertNil(fixture.model.shareURL)
    }

    func testCancellationRemovesDownloadedTemporaryFileAndDoesNotShowError() async {
        let downloadURL = temporaryFile(named: "cancelled.pdf")
        let api = SuspendedDownloadAPI(
            downloaded: DownloadedFile(
                url: downloadURL,
                suggestedFilename: "cancelled.pdf"
            )
        )
        let files = RecordingExportFileService()
        let model = DataExportViewModel(
            api: api,
            fileService: files,
            calendar: utcCalendar,
            now: { [now] in now }
        )

        let export = Task { await model.createExport() }
        while !api.isWaiting {
            await Task.yield()
        }

        model.cancelExport()
        api.finishDownload()
        await export.value

        XCTAssertEqual(files.removedURLs, [downloadURL])
        XCTAssertFalse(model.isExporting)
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(model.shareURL)
    }

    func testShareCompletionRemovesPreparedFile() async {
        let fixture = Fixture(now: now)
        fixture.api.setMockDownload(
            DownloadedFile(
                url: fixture.downloadURL,
                suggestedFilename: "peppy-export.pdf"
            ),
            for: .createDataExport(fixture.pdfRequest)
        )
        await fixture.model.createExport()

        fixture.model.shareSheetDidFinish()

        XCTAssertEqual(fixture.files.removedURLs, [fixture.files.preparedURL])
        XCTAssertNil(fixture.model.shareURL)
    }

    func testExportFileServiceMovesFileWithCompleteProtectionAndBackupExclusion() throws {
        let environment = try FileEnvironment()
        defer { environment.cleanup() }
        let source = environment.makeSourceFile(
            named: "URLSessionDownload.tmp",
            contents: Data("private health export".utf8)
        )
        let attributes = RecordingExportFileAttributeApplier(
            fileManager: environment.fileManager
        )
        let service = ExportFileService(
            fileManager: environment.fileManager,
            rootDirectory: environment.exportRoot,
            attributeApplier: attributes
        )

        let prepared = try service.prepare(
            DownloadedFile(
                url: source,
                suggestedFilename: "peppy-export.pdf"
            ),
            expectedExtension: "pdf"
        )

        XCTAssertFalse(environment.fileManager.fileExists(atPath: source.path))
        XCTAssertTrue(
            prepared.path.hasPrefix(environment.exportRoot.path + "/")
        )
        XCTAssertEqual(prepared.pathExtension, "pdf")
        XCTAssertEqual(
            try Data(contentsOf: prepared),
            Data("private health export".utf8)
        )

        XCTAssertEqual(attributes.protections.count, 1)
        XCTAssertEqual(attributes.protections.first?.url, prepared)
        XCTAssertEqual(attributes.protections.first?.protection, .complete)
        XCTAssertEqual(attributes.backupExcludedURLs, [prepared])
        XCTAssertEqual(
            try prepared.resourceValues(
                forKeys: [.isExcludedFromBackupKey]
            ).isExcludedFromBackup,
            true
        )
    }

    func testExportFileServiceRejectsMismatchedExtensionAndRemovesSource() throws {
        let environment = try FileEnvironment()
        defer { environment.cleanup() }
        let source = environment.makeSourceFile(
            named: "URLSessionDownload.tmp",
            contents: Data("not a pdf".utf8)
        )
        let service = ExportFileService(
            fileManager: environment.fileManager,
            rootDirectory: environment.exportRoot
        )

        XCTAssertThrowsError(
            try service.prepare(
                DownloadedFile(
                    url: source,
                    suggestedFilename: "peppy-export.zip"
                ),
                expectedExtension: "pdf"
            )
        ) { error in
            XCTAssertEqual(
                error as? ExportFileError,
                .unexpectedExtension(expected: "pdf", actual: "zip")
            )
        }
        XCTAssertFalse(environment.fileManager.fileExists(atPath: source.path))
        XCTAssertFalse(
            environment.fileManager.fileExists(
                atPath: environment.exportRoot.path
            )
        )
    }

    func testExportFileServiceRemovesInterruptedStaleFiles() throws {
        let environment = try FileEnvironment()
        defer { environment.cleanup() }
        try environment.fileManager.createDirectory(
            at: environment.exportRoot,
            withIntermediateDirectories: true
        )
        let stale = environment.exportRoot.appendingPathComponent("stale.zip")
        try Data("stale".utf8).write(to: stale)
        let service = ExportFileService(
            fileManager: environment.fileManager,
            rootDirectory: environment.exportRoot
        )

        try service.removeStaleFiles()

        XCTAssertFalse(environment.fileManager.fileExists(atPath: stale.path))
        XCTAssertFalse(
            environment.fileManager.fileExists(
                atPath: environment.exportRoot.path
            )
        )
    }
}

@MainActor
private final class Fixture {
    let api = MockAPIClient()
    let files = RecordingExportFileService()
    let now: Date
    let downloadURL = URL(fileURLWithPath: "/tmp/url-session-download")

    lazy var model = DataExportViewModel(
        api: api,
        fileService: files,
        calendar: utcCalendar,
        now: { [now] in now }
    )

    init(now: Date) {
        self.now = now
    }

    var pdfRequest: DataExportRequest {
        DataExportRequest(
            format: .pdf,
            includeProtocols: true,
            includeCheckins: true,
            includeInsights: true,
            startDate: nil,
            endDate: nil
        )
    }

    var csvRequest: DataExportRequest {
        DataExportRequest(
            format: .csv,
            includeProtocols: model.includeProtocols,
            includeCheckins: model.includeCheckins,
            includeInsights: model.includeInsights,
            startDate: model.selectedDatePreset == .last30Days
                ? APIDateOnly.date(from: "2026-06-24")
                : nil,
            endDate: model.selectedDatePreset == .last30Days ? now : nil
        )
    }
}

@MainActor
private final class RecordingExportFileService: ExportFileServicing {
    let preparedURL = URL(fileURLWithPath: "/tmp/peppy-exports/prepared.pdf")
    private(set) var preparedDownloads: [DownloadedFile] = []
    private(set) var preparedExpectedExtensions: [String] = []
    private(set) var removedURLs: [URL] = []
    private(set) var staleCleanupCount = 0

    func prepare(
        _ downloaded: DownloadedFile,
        expectedExtension: String
    ) throws -> URL {
        preparedDownloads.append(downloaded)
        preparedExpectedExtensions.append(expectedExtension)
        return preparedURL
    }

    func remove(_ url: URL) {
        removedURLs.append(url)
    }

    func removeStaleFiles() throws {
        staleCleanupCount += 1
    }
}

@MainActor
private final class SuspendedDownloadAPI: APIClientProtocol {
    let downloaded: DownloadedFile
    private(set) var isWaiting = false
    private var continuation: CheckedContinuation<DownloadedFile, Never>?

    init(downloaded: DownloadedFile) {
        self.downloaded = downloaded
    }

    func execute<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        throw APIError.notFound
    }

    func executeVoid(_ endpoint: Endpoint) async throws {
        throw APIError.notFound
    }

    func download(_ endpoint: Endpoint) async throws -> DownloadedFile {
        isWaiting = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finishDownload() {
        continuation?.resume(returning: downloaded)
        continuation = nil
    }
}

private struct FileEnvironment {
    let fileManager = FileManager.default
    let root: URL
    let exportRoot: URL

    init() throws {
        root = fileManager.temporaryDirectory
            .appendingPathComponent("DataExportTests-\(UUID().uuidString)")
        exportRoot = root.appendingPathComponent("peppy-exports")
        try fileManager.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
    }

    func makeSourceFile(named name: String, contents: Data) -> URL {
        let url = root.appendingPathComponent(name)
        try! contents.write(to: url)
        return url
    }

    func cleanup() {
        try? fileManager.removeItem(at: root)
    }
}

private final class RecordingExportFileAttributeApplier:
    ExportFileAttributeApplying
{
    private let system: SystemExportFileAttributeApplier
    private(set) var protections: [
        (url: URL, protection: FileProtectionType)
    ] = []
    private(set) var backupExcludedURLs: [URL] = []

    init(fileManager: FileManager) {
        system = SystemExportFileAttributeApplier(fileManager: fileManager)
    }

    func applyProtection(
        _ protection: FileProtectionType,
        to url: URL
    ) throws {
        protections.append((url, protection))
        try system.applyProtection(protection, to: url)
    }

    func excludeFromBackup(_ url: URL) throws -> URL {
        backupExcludedURLs.append(url)
        return try system.excludeFromBackup(url)
    }
}

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private extension Endpoint {
    var dataExportRequest: DataExportRequest? {
        guard case .createDataExport(let request) = self else { return nil }
        return request
    }
}

private func temporaryFile(named name: String) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(name)
}
