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
        isLoading = true
        errorMessage = nil
        do {
            let loaded: [Checkin] = try await api.execute(
                .getCheckins(startDate: nil, endDate: nil)
            )
            guard token == loadToken else { return }
            checkins = loaded.sorted { $0.date > $1.date }
            didLoad = true
            isLoading = false
        } catch {
            guard token == loadToken else { return }
            errorMessage = Self.message(for: error)
            isLoading = false
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
            didLoad = true
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
        checkins.sort { $0.date > $1.date }
        if selectedCheckin?.id == value.id { selectedCheckin = value }
    }

    private static func message(for error: Error) -> String {
        (error as? APIError)?.userMessage ?? error.localizedDescription
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}
