import Foundation

enum CheckinRoute: Hashable {
    case create
    case detail(UUID)
    case edit(UUID)

    var loadingIntent: CheckinLoadingIntent? {
        switch self {
        case .create:
            nil
        case .detail:
            .detail
        case .edit:
            .edit
        }
    }
}

enum CheckinLoadingIntent: Equatable {
    case detail
    case edit
}

enum CheckinHubState: Equatable {
    case idle
    case loading
    case empty
    case loaded
    case failed(String)
}

struct CheckinMetricModel: Identifiable, Equatable {
    let label: String
    let value: String

    var id: String { label }
}

struct CheckinSymptomModel: Identifiable, Equatable {
    let label: String
    let severity: Int

    var id: String { label }
}

struct CheckinDetailModel: Identifiable, Equatable {
    let id: UUID
    let dateText: String
    let metrics: [CheckinMetricModel]
    let symptoms: [CheckinSymptomModel]
    let notes: String?
    let isToday: Bool
}

struct CheckinHistoryRowModel: Identifiable, Equatable {
    let id: UUID
    let dateText: String
    let summary: String
    let route: CheckinRoute
}
