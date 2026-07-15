import Foundation
import Observation

@MainActor
@Observable
final class WeeklySummaryViewModel {
    private let store: InsightsStore

    var payload: WeeklySummaryPayload? {
        store.weekly?.summary
    }

    /// Distinguishes "not fetched yet" from "fetched, no summary available".
    var hasLoaded: Bool {
        store.weekly != nil
    }

    /// "Week of May 24 – May 30, 2026"
    var weekRangeText: String {
        guard let (start, end) = weekDates else { return "" }
        let startText = Self.dayFormatter.string(from: start)
        let endText = Self.dayYearFormatter.string(from: end)
        return "Week of \(startText) – \(endText)"
    }

    /// "May 24 – May 30" (hero footer caption)
    var weekRangeCaption: String {
        guard let (start, end) = weekDates else { return "" }
        return "\(Self.dayFormatter.string(from: start)) – \(Self.dayFormatter.string(from: end))"
    }

    /// Signed, 1 decimal, in kg — nil hides the hero numerals.
    var heroDeltaText: String? {
        guard let delta = payload?.hero.weightDeltaKg else { return nil }
        return String(format: "%+.1f kg", delta)
    }

    var heroTrendingDown: Bool {
        (payload?.hero.weightDeltaKg ?? 0) < 0
    }

    var chartPoints: [(date: Date, weightKg: Double)] {
        guard let payload else { return [] }
        return payload.weightSeries
            .compactMap { point in
                Self.isoDayFormatter.date(from: point.date)
                    .map { (date: $0, weightKg: point.weightKg) }
            }
            .sorted { $0.date < $1.date }
    }

    var hasNarrative: Bool {
        payload?.narrative != nil
    }

    init(store: InsightsStore) {
        self.store = store
    }

    func onAppear() async {
        guard store.weekly == nil else { return }
        await store.loadWeeklySummary()
    }

    private var weekDates: (start: Date, end: Date)? {
        guard let payload,
              let start = Self.isoDayFormatter.date(from: payload.weekStart),
              let end = Self.isoDayFormatter.date(from: payload.weekEnd) else {
            return nil
        }
        return (start, end)
    }

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let dayYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}
