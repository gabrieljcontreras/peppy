import Foundation
import Observation

enum DataExportDatePreset: String, CaseIterable, Identifiable {
    case allTime
    case last30Days
    case last90Days
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .allTime: "All Time"
        case .last30Days: "30 Days"
        case .last90Days: "90 Days"
        case .custom: "Custom"
        }
    }
}

enum DataExportValidationError: Error, Equatable {
    case startAfterEnd
    case futureDate
    case invalidDate

    var message: String {
        switch self {
        case .startAfterEnd:
            "The start date must be on or before the end date."
        case .futureDate:
            "Export dates can’t be in the future."
        case .invalidDate:
            "Choose a valid export date range."
        }
    }
}

@MainActor
@Observable
final class DataExportViewModel {
    var includeProtocols = true
    var includeCheckins = true
    var includeInsights = true
    var selectedFormat: DataExportFormat = .pdf
    var selectedDatePreset: DataExportDatePreset = .allTime
    var customStartDate: Date
    var customEndDate: Date

    private(set) var isExporting = false
    private(set) var shareURL: URL?
    var errorMessage: String?

    private let api: APIClientProtocol
    private let fileService: ExportFileServicing
    private let calendar: Calendar
    private let now: () -> Date

    private var downloadTask: Task<DownloadedFile, Error>?
    private var cancelRequested = false

    init(
        api: APIClientProtocol,
        fileService: ExportFileServicing,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.api = api
        self.fileService = fileService
        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.timeZone = calendar.timeZone
        self.calendar = gregorianCalendar
        self.now = now

        let today = gregorianCalendar.startOfDay(for: now())
        customEndDate = today
        customStartDate = gregorianCalendar.date(
            byAdding: .day,
            value: -29,
            to: today
        ) ?? today
    }

    var dateRangeSummary: String {
        switch selectedDatePreset {
        case .allTime:
            "All available data"
        case .last30Days:
            "Last 30 days"
        case .last90Days:
            "Last 90 days"
        case .custom:
            "\(Self.dateFormatter.string(from: customStartDate)) – \(Self.dateFormatter.string(from: customEndDate))"
        }
    }

    func exportRequest() throws -> DataExportRequest {
        let today = calendar.startOfDay(for: now())
        let range: (start: Date?, end: Date?)

        switch selectedDatePreset {
        case .allTime:
            range = (nil, nil)
        case .last30Days:
            guard let start = calendar.date(
                byAdding: .day,
                value: -29,
                to: today
            ) else {
                throw DataExportValidationError.invalidDate
            }
            range = (
                try apiDateOnly(from: start),
                try apiDateOnly(from: today)
            )
        case .last90Days:
            guard let start = calendar.date(
                byAdding: .day,
                value: -89,
                to: today
            ) else {
                throw DataExportValidationError.invalidDate
            }
            range = (
                try apiDateOnly(from: start),
                try apiDateOnly(from: today)
            )
        case .custom:
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.startOfDay(for: customEndDate)
            guard start <= end else {
                throw DataExportValidationError.startAfterEnd
            }
            guard start <= today, end <= today else {
                throw DataExportValidationError.futureDate
            }
            range = (
                try apiDateOnly(from: start),
                try apiDateOnly(from: end)
            )
        }

        return DataExportRequest(
            format: selectedFormat,
            includeProtocols: includeProtocols,
            includeCheckins: includeCheckins,
            includeInsights: includeInsights,
            startDate: range.start,
            endDate: range.end
        )
    }

    func createExport() async {
        guard !isExporting else { return }

        let request: DataExportRequest
        do {
            request = try exportRequest()
        } catch let validation as DataExportValidationError {
            errorMessage = validation.message
            return
        } catch {
            errorMessage = "Check your export selections and try again."
            return
        }

        isExporting = true
        cancelRequested = false
        errorMessage = nil
        let task = Task {
            try await api.download(.createDataExport(request))
        }
        downloadTask = task

        var downloaded: DownloadedFile?
        defer {
            downloadTask = nil
            isExporting = false
        }

        do {
            let completedDownload = try await task.value
            downloaded = completedDownload
            guard !cancelRequested, !task.isCancelled else {
                if let downloaded {
                    fileService.remove(downloaded.url)
                }
                return
            }

            let prepared = try fileService.prepare(
                completedDownload,
                expectedExtension: request.format.expectedFileExtension
            )
            guard !cancelRequested else {
                fileService.remove(prepared)
                return
            }
            shareURL = prepared
        } catch is CancellationError {
            if let downloaded {
                fileService.remove(downloaded.url)
            }
        } catch {
            if let downloaded {
                fileService.remove(downloaded.url)
            }
            guard !cancelRequested else { return }
            errorMessage = (error as? APIError)?.userMessage
                ?? "We couldn’t create your export. Please try again."
        }
    }

    func cancelExport() {
        guard isExporting else { return }
        cancelRequested = true
        downloadTask?.cancel()
    }

    func shareSheetDidFinish() {
        guard let shareURL else { return }
        fileService.remove(shareURL)
        self.shareURL = nil
    }

    func removeSharedFile() {
        shareSheetDidFinish()
    }

    func removeStaleFiles() {
        try? fileService.removeStaleFiles()
    }

    private func apiDateOnly(from localDate: Date) throws -> Date {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: localDate
        )
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = utcCalendar.date(from: components) else {
            throw DataExportValidationError.invalidDate
        }
        return date
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

extension DataExportFormat {
    var expectedFileExtension: String {
        switch self {
        case .pdf: "pdf"
        case .csv: "zip"
        }
    }
}
