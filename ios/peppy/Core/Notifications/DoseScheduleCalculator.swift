import Foundation

enum DoseScheduleCalculator {
    private static let dateOnlyCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    static func intervalDays(for frequency: String) -> Int? {
        switch frequency.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "daily":
            return 1
        case "every other day":
            return 2
        case "twice weekly":
            return 3
        case "weekly", "once weekly":
            return 7
        case "every 10 days":
            return 10
        case "biweekly":
            return 14
        case "monthly":
            return 30
        default:
            return nil
        }
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
              let interval = intervalDays(for: frequency),
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

        guard var candidate = calendar.date(from: startComponents) else {
            return []
        }

        while candidate <= now {
            guard let next = calendar.date(
                byAdding: .day,
                value: interval,
                to: candidate
            ) else {
                return []
            }
            candidate = next
        }

        var dates: [Date] = []
        dates.reserveCapacity(limit)

        while dates.count < limit {
            dates.append(candidate)
            guard let next = calendar.date(
                byAdding: .day,
                value: interval,
                to: candidate
            ) else {
                break
            }
            candidate = next
        }

        return dates
    }
}
