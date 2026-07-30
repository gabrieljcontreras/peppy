import Foundation

struct DashboardSummary: Codable, Equatable {
    let generatedAt: Date
    let profileStatus: String
    let `protocol`: DashboardProtocolSummary
    let todayCheckin: DashboardTodayCheckin
    let responseSnapshot: DashboardResponseSnapshot
    // Null for free accounts — insights are gated behind Peppy Premium, so the
    // backend omits the payload rather than sending content the user cannot
    // open. Optional here, otherwise the whole summary fails to decode and a
    // free user sees the dashboard error card instead of the locked card.
    let insight: DashboardInsightSummary?
    let connectedContext: DashboardConnectedContext
    // `var` with an inline default, not `let`: the default keeps every
    // existing memberwise-init call site compiling without the argument, and
    // only a mutable property with an initial value still gets decoded.
    var recentActivity: [DashboardActivityItem]? = nil

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case profileStatus = "profile_status"
        case `protocol`
        case todayCheckin = "today_checkin"
        case responseSnapshot = "response_snapshot"
        case insight
        case connectedContext = "connected_context"
        case recentActivity = "recent_activity"
    }
}

struct DashboardProtocolSummary: Codable, Equatable {
    let id: UUID?
    let status: String
    let title: String
    let compounds: [String]
    let startDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, title, compounds
        case startDate = "start_date"
    }

    init(id: UUID?, status: String, title: String, compounds: [String], startDate: Date? = nil) {
        self.id = id
        self.status = status
        self.title = title
        self.compounds = compounds
        self.startDate = startDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        title = try container.decode(String.self, forKey: .title)
        compounds = try container.decode([String].self, forKey: .compounds)
        if let raw = try container.decodeIfPresent(String.self, forKey: .startDate) {
            startDate = APIDateOnly.date(from: raw)
        } else {
            startDate = nil
        }
    }
}

struct DashboardTodayCheckin: Codable, Equatable {
    let logged: Bool
    let checkinId: UUID?

    enum CodingKeys: String, CodingKey {
        case logged
        case checkinId = "checkin_id"
    }
}

struct DashboardCheckinPreview: Equatable {
    let isSaved: Bool
    let title: String
    let subtitle: String
    let highlights: [String]

    var accessibilitySummary: String {
        (["View full check-in", subtitle] + highlights)
            .map { "\($0)." }
            .joined(separator: " ")
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
    // See DashboardSummary.recentActivity for why this is `var` + default.
    var confidence: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id, title, severity, confidence
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

struct DashboardActivityItem: Codable, Equatable, Identifiable {
    let type: String
    let title: String
    let subtitle: String
    let timestamp: Date
    let protocolID: UUID?
    let checkinID: UUID?

    var id: String { "\(type)-\(timestamp.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case type, title, subtitle, timestamp
        case protocolID = "protocol_id"
        case checkinID = "checkin_id"
    }
}

struct DashboardWearableTiles: Equatable {
    let sleepHours: Double?
    let hrvMs: Double?
    let readinessScore: Double?

    var isEmpty: Bool {
        sleepHours == nil && hrvMs == nil && readinessScore == nil
    }
}

extension DashboardSummary {
    func replacingProtocol(with protocolValue: ProtocolModel) -> DashboardSummary {
        DashboardSummary(
            generatedAt: generatedAt,
            profileStatus: profileStatus,
            protocol: DashboardProtocolSummary(
                id: protocolValue.id,
                status: protocolValue.status.rawValue,
                title: protocolValue.name,
                compounds: protocolValue.compounds.map(\.name)
            ),
            todayCheckin: todayCheckin,
            responseSnapshot: responseSnapshot,
            insight: insight,
            connectedContext: connectedContext,
            recentActivity: recentActivity
        )
    }

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
