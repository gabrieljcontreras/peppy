import Foundation

// MARK: - Auth

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }
}

// MARK: - Protocol

struct Protocol: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let startDate: Date
    let endDate: Date?
    let notes: String?
    let isActive: Bool
    let compounds: [Compound]

    enum CodingKeys: String, CodingKey {
        case id, name, notes, compounds
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
    }
}

struct Compound: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let dose: Double
    let unit: String
    let frequency: String
}

struct CreateProtocolRequest: Encodable {
    let name: String
    let startDate: Date
    let endDate: Date?
    let notes: String?
    let compounds: [CreateCompoundRequest]

    enum CodingKeys: String, CodingKey {
        case name, notes, compounds
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct CreateCompoundRequest: Encodable {
    let name: String
    let dose: Double
    let unit: String
    let frequency: String
}

struct UpdateProtocolRequest: Encodable {
    let name: String?
    let startDate: Date?
    let endDate: Date?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name, notes
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

// MARK: - Check-in

struct Checkin: Codable, Identifiable {
    let id: UUID
    let date: Date
    let weight: Double?
    let mood: Int?
    let sleepHours: Double?
    let symptoms: [String]
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, date, weight, mood, symptoms, notes
        case sleepHours = "sleep_hours"
    }
}

struct CreateCheckinRequest: Encodable {
    let date: Date
    let weight: Double?
    let mood: Int?
    let sleepHours: Double?
    let symptoms: [String]
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case date, weight, mood, symptoms, notes
        case sleepHours = "sleep_hours"
    }
}

// MARK: - Lab

struct Lab: Codable, Identifiable {
    let id: UUID
    let date: Date
    let panelType: String
    let markers: [LabMarker]

    enum CodingKeys: String, CodingKey {
        case id, date, markers
        case panelType = "panel_type"
    }
}

struct LabMarker: Codable, Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let unit: String
    let referenceMin: Double?
    let referenceMax: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, value, unit
        case referenceMin = "reference_min"
        case referenceMax = "reference_max"
    }
}

struct CreateLabRequest: Encodable {
    let date: Date
    let panelType: String
    let markers: [CreateMarkerRequest]

    enum CodingKeys: String, CodingKey {
        case date, markers
        case panelType = "panel_type"
    }
}

struct CreateMarkerRequest: Encodable {
    let name: String
    let value: Double
    let unit: String
    let referenceMin: Double?
    let referenceMax: Double?

    enum CodingKeys: String, CodingKey {
        case name, value, unit
        case referenceMin = "reference_min"
        case referenceMax = "reference_max"
    }
}

// MARK: - Insight

struct Insight: Codable, Identifiable {
    let id: UUID
    let type: String
    let severity: String
    let title: String
    let body: String
    let isRead: Bool
    let action: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, severity, title, body, action
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - Wearable

struct WearableConnection: Codable, Identifiable {
    let id: UUID
    let provider: String
    let connectedAt: Date
    let lastSyncAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, provider
        case connectedAt = "connected_at"
        case lastSyncAt = "last_sync_at"
    }
}

// MARK: - Notifications

struct DeviceToken: Codable, Identifiable {
    let id: UUID
    let platform: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, platform
        case createdAt = "created_at"
    }
}

struct NotificationPreferences: Codable {
    let insightsEnabled: Bool
    let alertSeverityOnly: Bool
    let quietHoursStart: String?
    let quietHoursEnd: String?

    enum CodingKeys: String, CodingKey {
        case insightsEnabled = "insights_enabled"
        case alertSeverityOnly = "alert_severity_only"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
    }
}

struct UpdatePreferencesRequest: Encodable {
    let insightsEnabled: Bool?
    let alertSeverityOnly: Bool?
    let quietHoursStart: String?
    let quietHoursEnd: String?

    enum CodingKeys: String, CodingKey {
        case insightsEnabled = "insights_enabled"
        case alertSeverityOnly = "alert_severity_only"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
    }
}
