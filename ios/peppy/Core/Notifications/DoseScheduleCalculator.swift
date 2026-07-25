import Foundation

enum DoseScheduleCalculator {
    enum Recurrence: Equatable {
        case fixedDays(Int)
        case twiceWeekly
        case monthly
    }

    private static let dateOnlyCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    static func recurrence(for frequency: String) -> Recurrence? {
        switch frequency.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "daily":
            return .fixedDays(1)
        case "every other day":
            return .fixedDays(2)
        case "twice weekly":
            return .twiceWeekly
        case "weekly", "once weekly":
            return .fixedDays(7)
        case "every 10 days":
            return .fixedDays(10)
        case "biweekly":
            return .fixedDays(14)
        case "monthly":
            return .monthly
        default:
            return nil
        }
    }

    static func intervalDays(for frequency: String) -> Int? {
        guard case .fixedDays(let days) = recurrence(for: frequency) else {
            return nil
        }
        return days
    }

    static func upcomingDates(
        startingAt startDate: Date,
        frequency: String,
        localTime: DateComponents,
        after now: Date,
        calendar: Calendar = .current,
        limit: Int
    ) -> [Date] {
        guard limit > 0,
              let recurrence = recurrence(for: frequency),
              let hour = localTime.hour,
              let minute = localTime.minute else {
            return []
        }

        var startComponents = dateOnlyCalendar.dateComponents(
            [.year, .month, .day],
            from: startDate
        )
        startComponents.hour = hour
        startComponents.minute = minute
        startComponents.second = 0

        guard let anchor = calendar.date(from: startComponents) else {
            return []
        }

        var candidate = anchor
        var occurrenceIndex = 0
        while candidate <= now {
            occurrenceIndex += 1
            guard let next = date(
                anchoredAt: anchor,
                recurrence: recurrence,
                occurrenceIndex: occurrenceIndex,
                calendar: calendar
            ) else {
                return []
            }
            candidate = next
        }

        var dates: [Date] = []
        dates.reserveCapacity(limit)

        while dates.count < limit {
            dates.append(candidate)
            occurrenceIndex += 1
            guard let next = date(
                anchoredAt: anchor,
                recurrence: recurrence,
                occurrenceIndex: occurrenceIndex,
                calendar: calendar
            ) else {
                break
            }
            candidate = next
        }

        return dates
    }

    /// The next due date for one compound, given its dose logs so far. Falls
    /// back to the protocol's start date when the compound has never been
    /// logged; returns `nil` when the frequency string isn't recognized.
    static func nextDueDate(
        frequency: String,
        protocolStartDate: Date,
        doseLogs: [DoseLog],
        for compoundID: UUID,
        calendar: Calendar = .current
    ) -> Date? {
        let compoundLogs = doseLogs.filter { $0.compoundID == compoundID }
        guard let latest = compoundLogs.map(\.administeredAt).max() else {
            return protocolStartDate
        }
        guard let recurrence = recurrence(for: frequency) else {
            return nil
        }
        switch recurrence {
        case .fixedDays(let interval):
            return calendar.date(byAdding: .day, value: interval, to: latest)
        case .twiceWeekly, .monthly:
            return upcomingDates(
                startingAt: protocolStartDate,
                frequency: frequency,
                localTime: calendar.dateComponents([.hour, .minute], from: latest),
                after: latest,
                calendar: calendar,
                limit: 1
            ).first
        }
    }

    private static func date(
        anchoredAt anchor: Date,
        recurrence: Recurrence,
        occurrenceIndex: Int,
        calendar: Calendar
    ) -> Date? {
        switch recurrence {
        case .fixedDays(let interval):
            return calendar.date(
                byAdding: .day,
                value: interval * occurrenceIndex,
                to: anchor
            )
        case .twiceWeekly:
            let weekOffset = (occurrenceIndex / 2) * 7
            let withinWeekOffset = occurrenceIndex.isMultiple(of: 2) ? 0 : 3
            return calendar.date(
                byAdding: .day,
                value: weekOffset + withinWeekOffset,
                to: anchor
            )
        case .monthly:
            return monthlyDate(
                anchoredAt: anchor,
                monthOffset: occurrenceIndex,
                calendar: calendar
            )
        }
    }

    private static func monthlyDate(
        anchoredAt anchor: Date,
        monthOffset: Int,
        calendar: Calendar
    ) -> Date? {
        let anchorComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: anchor
        )
        guard let year = anchorComponents.year,
              let month = anchorComponents.month,
              let day = anchorComponents.day,
              let firstOfAnchorMonth = calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: 1,
                    hour: anchorComponents.hour,
                    minute: anchorComponents.minute,
                    second: anchorComponents.second
                )
              ),
              let targetMonth = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: firstOfAnchorMonth
              ),
              let dayRange = calendar.range(of: .day, in: .month, for: targetMonth)
        else {
            return nil
        }

        var targetComponents = calendar.dateComponents(
            [.year, .month],
            from: targetMonth
        )
        targetComponents.day = min(day, dayRange.count)
        targetComponents.hour = anchorComponents.hour
        targetComponents.minute = anchorComponents.minute
        targetComponents.second = anchorComponents.second
        return calendar.date(from: targetComponents)
    }
}
