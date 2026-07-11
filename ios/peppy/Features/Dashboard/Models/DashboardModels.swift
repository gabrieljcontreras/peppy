import Foundation

struct DashboardSummary: Codable, Equatable {
    let generatedAt: Date
    let profileStatus: String
    let `protocol`: DashboardProtocolSummary
    let todayCheckin: DashboardTodayCheckin
    let responseSnapshot: DashboardResponseSnapshot
    let insight: DashboardInsightSummary
    let connectedContext: DashboardConnectedContext

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case profileStatus = "profile_status"
        case `protocol`
        case todayCheckin = "today_checkin"
        case responseSnapshot = "response_snapshot"
        case insight
        case connectedContext = "connected_context"
    }
}

struct DashboardProtocolSummary: Codable, Equatable {
    let id: UUID?
    let status: String
    let title: String
    let compounds: [String]
}

struct DashboardTodayCheckin: Codable, Equatable {
    let logged: Bool
    let checkinId: UUID?

    enum CodingKeys: String, CodingKey {
        case logged
        case checkinId = "checkin_id"
    }
}

struct DashboardResponseSnapshot: Codable, Equatable {
    let weightTrend: [DashboardWeightPoint]
    let latestEnergy: Int?
    let latestMood: Int?

    enum CodingKeys: String, CodingKey {
        case weightTrend = "weight_trend"
        case latestEnergy = "latest_energy"
        case latestMood = "latest_mood"
    }
}

struct DashboardWeightPoint: Codable, Equatable {
    let date: Date
    let weightKg: Double

    enum CodingKeys: String, CodingKey {
        case date
        case weightKg = "weight_kg"
    }
}

struct DashboardInsightSummary: Codable, Equatable {
    let id: UUID?
    let title: String?
    let severity: String?
    let emptyMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, title, severity
        case emptyMessage = "empty_message"
    }
}

struct DashboardConnectedContext: Codable, Equatable {
    let healthkitRequested: Bool?
    let hasLabs: Bool
    let hasWearables: Bool

    enum CodingKeys: String, CodingKey {
        case healthkitRequested = "healthkit_requested"
        case hasLabs = "has_labs"
        case hasWearables = "has_wearables"
    }
}

extension DashboardSummary {
    static let mockPendingStarter = DashboardSummary(
        generatedAt: Date(timeIntervalSince1970: 1_788_000_000),
        profileStatus: "present",
        protocol: DashboardProtocolSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            status: "pending_setup",
            title: "Starter protocol",
            compounds: ["Retatrutide"]
        ),
        todayCheckin: DashboardTodayCheckin(logged: false, checkinId: nil),
        responseSnapshot: DashboardResponseSnapshot(
            weightTrend: [
                DashboardWeightPoint(date: Date(timeIntervalSince1970: 1_787_740_800), weightKg: 75.2),
                DashboardWeightPoint(date: Date(timeIntervalSince1970: 1_787_827_200), weightKg: 74.8),
            ],
            latestEnergy: 7,
            latestMood: 8
        ),
        insight: DashboardInsightSummary(
            id: nil,
            title: nil,
            severity: nil,
            emptyMessage: "Peppy needs a few check-ins to find useful patterns."
        ),
        connectedContext: DashboardConnectedContext(
            healthkitRequested: true,
            hasLabs: false,
            hasWearables: false
        )
    )

    static let mockMissingProfile = DashboardSummary(
        generatedAt: Date(timeIntervalSince1970: 1_788_000_000),
        profileStatus: "missing",
        protocol: DashboardProtocolSummary(
            id: nil,
            status: "missing",
            title: "Create your protocol",
            compounds: []
        ),
        todayCheckin: DashboardTodayCheckin(logged: false, checkinId: nil),
        responseSnapshot: DashboardResponseSnapshot(
            weightTrend: [],
            latestEnergy: nil,
            latestMood: nil
        ),
        insight: DashboardInsightSummary(
            id: nil,
            title: nil,
            severity: nil,
            emptyMessage: "Peppy needs a few check-ins to find useful patterns."
        ),
        connectedContext: DashboardConnectedContext(
            healthkitRequested: nil,
            hasLabs: false,
            hasWearables: false
        )
    )
}
