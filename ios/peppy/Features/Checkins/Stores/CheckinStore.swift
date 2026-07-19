import Foundation
import Observation

enum CheckinCreateResult: Equatable {
    case saved(Checkin)
    case existing(Checkin)
    case failed
}

enum CheckinDetailLoadResult: Equatable {
    case loaded(Checkin)
    case notFound
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
    private var sessionGeneration = 0
    private var operationToken = 0
    private var detailTokens: [UUID: Int] = [:]
    private var mutationTokens: [UUID: Int] = [:]

    private(set) var checkins: [Checkin] = []
    private(set) var selectedCheckin: Checkin?
    private(set) var isLoading = false
    private(set) var revision = 0
    private(set) var initialLoadErrorMessage: String?
    private(set) var refreshErrorMessage: String?
    private(set) var detailErrorMessage: String?
    private(set) var mutationErrorMessage: String?

    var errorMessage: String? {
        mutationErrorMessage ?? detailErrorMessage ?? refreshErrorMessage ?? initialLoadErrorMessage
    }

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

    func resetSession() {
        sessionGeneration += 1
        loadToken += 1
        collectionVersion = 0
        detailTokens.removeAll()
        mutationTokens.removeAll()
        didLoad = false
        checkins = []
        selectedCheckin = nil
        isLoading = false
        revision = 0
        initialLoadErrorMessage = nil
        refreshErrorMessage = nil
        detailErrorMessage = nil
        mutationErrorMessage = nil
    }

    func load(force: Bool = false) async {
        guard force || !didLoad else { return }
        loadToken += 1
        let token = loadToken
        let version = collectionVersion
        let generation = sessionGeneration
        let isRefresh = didLoad || !checkins.isEmpty
        isLoading = true
        if isRefresh {
            refreshErrorMessage = nil
        } else {
            initialLoadErrorMessage = nil
        }
        do {
            let loaded: [Checkin] = try await api.execute(
                .getCheckins(startDate: nil, endDate: nil)
            )
            guard generation == sessionGeneration, token == loadToken else { return }
            isLoading = false
            guard version == collectionVersion else { return }
            checkins = Self.normalized(loaded)
            if let selectedID = selectedCheckin?.id,
               let refreshedSelection = checkins.first(where: { $0.id == selectedID }) {
                selectedCheckin = refreshedSelection
            }
            invalidateAllDetailResponses()
            collectionVersion += 1
            didLoad = true
            initialLoadErrorMessage = nil
            if isRefresh {
                refreshErrorMessage = nil
            }
        } catch {
            guard generation == sessionGeneration, token == loadToken else { return }
            isLoading = false
            guard version == collectionVersion else { return }
            if isRefresh {
                refreshErrorMessage = Self.message(for: error)
            } else {
                initialLoadErrorMessage = Self.message(for: error)
            }
        }
    }

    @discardableResult
    func loadDetail(_ id: UUID) async -> CheckinDetailLoadResult {
        if let local = checkin(id: id) { selectedCheckin = local }
        detailErrorMessage = nil
        operationToken += 1
        let token = operationToken
        let generation = sessionGeneration
        detailTokens[id] = token
        do {
            let detail: Checkin = try await api.execute(.getCheckin(id: id))
            guard generation == sessionGeneration,
                  detailTokens[id] == token else { return .failed }
            detailTokens.removeValue(forKey: id)
            reconcile(detail)
            selectedCheckin = detail
            detailErrorMessage = nil
            return .loaded(detail)
        } catch APIError.notFound {
            guard generation == sessionGeneration,
                  detailTokens[id] == token else { return .failed }
            detailTokens.removeValue(forKey: id)
            detailErrorMessage = "Check-in not found. Refresh your check-ins and try again."
            return .notFound
        } catch {
            guard generation == sessionGeneration,
                  detailTokens[id] == token else { return .failed }
            detailTokens.removeValue(forKey: id)
            detailErrorMessage = Self.message(for: error)
            return .failed
        }
    }

    func create(_ request: CreateCheckinRequest) async -> CheckinCreateResult {
        let generation = sessionGeneration
        mutationErrorMessage = nil
        do {
            let created: Checkin = try await api.execute(.createCheckin(request))
            guard generation == sessionGeneration else { return .failed }
            reconcile(created)
            revision += 1
            return .saved(created)
        } catch APIError.conflict(_) {
            guard generation == sessionGeneration else { return .failed }
            await load(force: true)
            guard generation == sessionGeneration else { return .failed }
            if let today { return .existing(today) }
            mutationErrorMessage = "A check-in already exists for today, but it could not be loaded."
            return .failed
        } catch {
            guard generation == sessionGeneration else { return .failed }
            mutationErrorMessage = Self.message(for: error)
            return .failed
        }
    }

    func update(id: UUID, request: UpdateCheckinRequest) async -> Checkin? {
        guard let existing = checkin(id: id) else {
            mutationErrorMessage = "The check-in could not be found. Refresh and try again."
            return nil
        }
        guard isToday(existing.date) else {
            mutationErrorMessage = "Only today's check-in can be edited."
            return nil
        }
        guard isToday(request.date) else {
            mutationErrorMessage = "Today's check-in cannot be moved to another date."
            return nil
        }
        guard mutationTokens[id] == nil else { return nil }
        operationToken += 1
        let token = operationToken
        let generation = sessionGeneration
        mutationTokens[id] = token
        defer {
            if mutationTokens[id] == token {
                mutationTokens.removeValue(forKey: id)
            }
        }
        mutationErrorMessage = nil
        do {
            let updated: Checkin = try await api.execute(.updateCheckin(id: id, request))
            guard generation == sessionGeneration,
                  mutationTokens[id] == token else { return nil }
            reconcile(updated)
            revision += 1
            return updated
        } catch {
            guard generation == sessionGeneration,
                  mutationTokens[id] == token else { return nil }
            mutationErrorMessage = Self.message(for: error)
            return nil
        }
    }

    func clearDetailError() {
        detailErrorMessage = nil
    }

    private func reconcile(_ value: Checkin) {
        detailTokens.removeValue(forKey: value.id)
        checkins = Self.normalized(
            checkins.filter { $0.id != value.id } + [value]
        )
        if selectedCheckin?.id == value.id { selectedCheckin = value }
        collectionVersion += 1
    }

    private func invalidateAllDetailResponses() {
        detailTokens.removeAll()
    }

    private func isToday(_ date: Date) -> Bool {
        Self.utcCalendar.isDate(date, inSameDayAs: now())
    }

    private static func message(for error: Error) -> String {
        (error as? APIError)?.userMessage ?? error.localizedDescription
    }

    private static func normalized(_ values: [Checkin]) -> [Checkin] {
        var valuesByID: [UUID: Checkin] = [:]
        for value in values {
            if let existing = valuesByID[value.id] {
                valuesByID[value.id] = preferred(existing, value)
            } else {
                valuesByID[value.id] = value
            }
        }

        let sorted = valuesByID.values.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return Array(sorted.prefix(100))
    }

    private static func preferred(_ lhs: Checkin, _ rhs: Checkin) -> Checkin {
        let lhsUpdated = lhs.updatedAt ?? .distantPast
        let rhsUpdated = rhs.updatedAt ?? .distantPast
        if lhsUpdated != rhsUpdated { return lhsUpdated > rhsUpdated ? lhs : rhs }
        if lhs.date != rhs.date { return lhs.date > rhs.date ? lhs : rhs }

        let lhsCreated = lhs.createdAt ?? .distantPast
        let rhsCreated = rhs.createdAt ?? .distantPast
        if lhsCreated != rhsCreated { return lhsCreated > rhsCreated ? lhs : rhs }

        return canonicalKey(lhs) >= canonicalKey(rhs) ? lhs : rhs
    }

    private static func canonicalKey(_ value: Checkin) -> String {
        var fields: [String] = []
        fields.append(value.userId?.uuidString ?? "")
        fields.append(value.weightKg.map { String($0.bitPattern) } ?? "")
        fields.append(value.energyLevel.map(String.init) ?? "")
        fields.append(value.sleepQuality.map(String.init) ?? "")
        fields.append(value.appetiteLevel.map(String.init) ?? "")
        fields.append(value.mood.map(String.init) ?? "")
        fields.append(value.nausea.map(String.init) ?? "")
        fields.append(value.injectionSiteReaction.map(String.init) ?? "")
        fields.append(value.fatigue.map(String.init) ?? "")
        fields.append(value.headache.map(String.init) ?? "")
        fields.append(value.giIssues.map(String.init) ?? "")
        fields.append(value.notes ?? "")
        return fields.joined(separator: "|")
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}
