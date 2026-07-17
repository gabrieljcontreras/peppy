import Foundation
import Observation

enum CheckinCreateResult: Equatable {
    case saved(Checkin)
    case existing(Checkin)
    case failed
}

@MainActor
@Observable
final class CheckinStore {
    private let api: APIClientProtocol
    private let now: () -> Date
    private var didLoad = false
    private var loadToken = 0
    private var collectionVersion = 0
    private var mutatingIDs: Set<UUID> = []

    private(set) var checkins: [Checkin] = []
    private(set) var selectedCheckin: Checkin?
    private(set) var isLoading = false
    private(set) var revision = 0
    var errorMessage: String?

    init(api: APIClientProtocol, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.now = now
    }

    var today: Checkin? {
        checkins.first { Self.utcCalendar.isDate($0.date, inSameDayAs: now()) }
    }

    var history: [Checkin] {
        checkins.filter { !Self.utcCalendar.isDate($0.date, inSameDayAs: now()) }
    }

    func checkin(id: UUID) -> Checkin? {
        if selectedCheckin?.id == id { return selectedCheckin }
        return checkins.first { $0.id == id }
    }

    func load(force: Bool = false) async {
        guard force || !didLoad else { return }
        loadToken += 1
        let token = loadToken
        let version = collectionVersion
        isLoading = true
        errorMessage = nil
        do {
            let loaded: [Checkin] = try await api.execute(
                .getCheckins(startDate: nil, endDate: nil)
            )
            guard token == loadToken else { return }
            isLoading = false
            guard version == collectionVersion else { return }
            checkins = Self.normalized(loaded)
            if let selectedID = selectedCheckin?.id,
               let refreshedSelection = checkins.first(where: { $0.id == selectedID }) {
                selectedCheckin = refreshedSelection
            }
            didLoad = true
        } catch {
            guard token == loadToken else { return }
            isLoading = false
            guard version == collectionVersion else { return }
            errorMessage = Self.message(for: error)
        }
    }

    func loadDetail(_ id: UUID) async {
        if let local = checkin(id: id) { selectedCheckin = local }
        do {
            let detail: Checkin = try await api.execute(.getCheckin(id: id))
            selectedCheckin = detail
            reconcile(detail)
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func create(_ request: CreateCheckinRequest) async -> CheckinCreateResult {
        errorMessage = nil
        do {
            let created: Checkin = try await api.execute(.createCheckin(request))
            reconcile(created)
            revision += 1
            return .saved(created)
        } catch APIError.conflict(_) {
            await load(force: true)
            if let today { return .existing(today) }
            errorMessage = "A check-in already exists for today, but it could not be loaded."
            return .failed
        } catch {
            errorMessage = Self.message(for: error)
            return .failed
        }
    }

    func update(id: UUID, request: UpdateCheckinRequest) async -> Checkin? {
        guard let existing = checkin(id: id) else {
            errorMessage = "The check-in could not be found. Refresh and try again."
            return nil
        }
        guard isToday(existing.date) else {
            errorMessage = "Only today's check-in can be edited."
            return nil
        }
        guard isToday(request.date) else {
            errorMessage = "Today's check-in cannot be moved to another date."
            return nil
        }
        guard mutatingIDs.insert(id).inserted else { return nil }
        defer { mutatingIDs.remove(id) }
        errorMessage = nil
        do {
            let updated: Checkin = try await api.execute(.updateCheckin(id: id, request))
            reconcile(updated)
            revision += 1
            return updated
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    private func reconcile(_ value: Checkin) {
        if let index = checkins.firstIndex(where: { $0.id == value.id }) {
            checkins[index] = value
        } else {
            checkins.append(value)
        }
        checkins = Self.normalized(checkins)
        if selectedCheckin?.id == value.id { selectedCheckin = value }
        collectionVersion += 1
    }

    private func isToday(_ date: Date) -> Bool {
        Self.utcCalendar.isDate(date, inSameDayAs: now())
    }

    private static func message(for error: Error) -> String {
        (error as? APIError)?.userMessage ?? error.localizedDescription
    }

    private static func normalized(_ values: [Checkin]) -> [Checkin] {
        Array(values.sorted { $0.date > $1.date }.prefix(100))
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}
