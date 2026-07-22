import Foundation

// MARK: - Account And Profile

struct AccountProfile: Decodable, Equatable, Identifiable {
    let id: UUID
    let schemaVersion: Int
    let heightCm: Double?
    let preferredHeightUnit: String?
    let weightKg: Double?
    let preferredWeightUnit: String?
    let baselineDate: Date?
    let primaryGoal: String?
    let secondaryGoal: String?
    let focusArea: String?

    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion = "schema_version"
        case heightCm = "height_cm"
        case preferredHeightUnit = "preferred_height_unit"
        case weightKg = "weight_kg"
        case preferredWeightUnit = "preferred_weight_unit"
        case baselineDate = "baseline_date"
        case primaryGoal = "primary_goal"
        case secondaryGoal = "secondary_goal"
        case focusArea = "focus_area"
    }

    init(
        id: UUID,
        schemaVersion: Int,
        heightCm: Double?,
        preferredHeightUnit: String?,
        weightKg: Double?,
        preferredWeightUnit: String?,
        baselineDate: Date?,
        primaryGoal: String?,
        secondaryGoal: String?,
        focusArea: String?
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.heightCm = heightCm
        self.preferredHeightUnit = preferredHeightUnit
        self.weightKg = weightKg
        self.preferredWeightUnit = preferredWeightUnit
        self.baselineDate = baselineDate
        self.primaryGoal = primaryGoal
        self.secondaryGoal = secondaryGoal
        self.focusArea = focusArea
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        heightCm = try container.decodeIfPresent(Double.self, forKey: .heightCm)
        preferredHeightUnit = try container.decodeIfPresent(String.self, forKey: .preferredHeightUnit)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        preferredWeightUnit = try container.decodeIfPresent(String.self, forKey: .preferredWeightUnit)
        if let value = try container.decodeIfPresent(String.self, forKey: .baselineDate) {
            guard let parsed = APIDateOnly.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .baselineDate,
                    in: container,
                    debugDescription: "Expected a yyyy-MM-dd date."
                )
            }
            baselineDate = parsed
        } else {
            baselineDate = nil
        }
        primaryGoal = try container.decodeIfPresent(String.self, forKey: .primaryGoal)
        secondaryGoal = try container.decodeIfPresent(String.self, forKey: .secondaryGoal)
        focusArea = try container.decodeIfPresent(String.self, forKey: .focusArea)
    }

}

struct ProfileUpdateRequest: Encodable, Equatable {
    let schemaVersion: Int
    let heightCm: Double?
    let preferredHeightUnit: String?
    let weightKg: Double?
    let preferredWeightUnit: String?
    let baselineDate: Date?
    let primaryGoal: String?
    let secondaryGoal: String?
    let focusArea: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case heightCm = "height_cm"
        case preferredHeightUnit = "preferred_height_unit"
        case weightKg = "weight_kg"
        case preferredWeightUnit = "preferred_weight_unit"
        case baselineDate = "baseline_date"
        case primaryGoal = "primary_goal"
        case secondaryGoal = "secondary_goal"
        case focusArea = "focus_area"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(heightCm, forKey: .heightCm)
        try container.encodeIfPresent(preferredHeightUnit, forKey: .preferredHeightUnit)
        try container.encodeIfPresent(weightKg, forKey: .weightKg)
        try container.encodeIfPresent(preferredWeightUnit, forKey: .preferredWeightUnit)
        if let baselineDate {
            try container.encode(APIDateOnly.string(from: baselineDate), forKey: .baselineDate)
        }
        try container.encodeIfPresent(primaryGoal, forKey: .primaryGoal)
        try container.encode(secondaryGoal, forKey: .secondaryGoal)
        try container.encode(focusArea, forKey: .focusArea)
    }
}

struct UpdateCurrentUserRequest: Encodable, Equatable {
    let displayName: String?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case timezone
    }
}

// MARK: - Notifications

struct DoseReminderPreference: Codable, Equatable, Identifiable {
    let compoundID: UUID
    let localTime: String
    let enabled: Bool

    var id: UUID { compoundID }

    enum CodingKeys: String, CodingKey {
        case compoundID = "compound_id"
        case localTime = "local_time"
        case enabled
    }
}

struct NotificationPreferences: Codable, Equatable, Identifiable {
    let id: UUID
    let insightsEnabled: Bool
    let alertSeverityOnly: Bool
    let doseRemindersEnabled: Bool
    let dailyCheckinRemindersEnabled: Bool
    let dailyCheckinTime: String?
    let detailedPreviewsEnabled: Bool
    let quietHoursStart: String?
    let quietHoursEnd: String?
    let doseReminders: [DoseReminderPreference]

    enum CodingKeys: String, CodingKey {
        case id
        case insightsEnabled = "insights_enabled"
        case alertSeverityOnly = "alert_severity_only"
        case doseRemindersEnabled = "dose_reminders_enabled"
        case dailyCheckinRemindersEnabled = "daily_checkin_reminders_enabled"
        case dailyCheckinTime = "daily_checkin_time"
        case detailedPreviewsEnabled = "detailed_previews_enabled"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case doseReminders = "dose_reminders"
    }
}

struct UpdateNotificationPreferencesRequest: Encodable, Equatable {
    let insightsEnabled: Bool
    let alertSeverityOnly: Bool
    let doseRemindersEnabled: Bool
    let dailyCheckinRemindersEnabled: Bool
    let dailyCheckinTime: String?
    let detailedPreviewsEnabled: Bool
    let quietHoursStart: String?
    let quietHoursEnd: String?
    let doseReminders: [DoseReminderPreference]

    enum CodingKeys: String, CodingKey {
        case insightsEnabled = "insights_enabled"
        case alertSeverityOnly = "alert_severity_only"
        case doseRemindersEnabled = "dose_reminders_enabled"
        case dailyCheckinRemindersEnabled = "daily_checkin_reminders_enabled"
        case dailyCheckinTime = "daily_checkin_time"
        case detailedPreviewsEnabled = "detailed_previews_enabled"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case doseReminders = "dose_reminders"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(insightsEnabled, forKey: .insightsEnabled)
        try container.encode(alertSeverityOnly, forKey: .alertSeverityOnly)
        try container.encode(doseRemindersEnabled, forKey: .doseRemindersEnabled)
        try container.encode(dailyCheckinRemindersEnabled, forKey: .dailyCheckinRemindersEnabled)
        try container.encode(dailyCheckinTime, forKey: .dailyCheckinTime)
        try container.encode(detailedPreviewsEnabled, forKey: .detailedPreviewsEnabled)
        try container.encode(quietHoursStart, forKey: .quietHoursStart)
        try container.encode(quietHoursEnd, forKey: .quietHoursEnd)
        try container.encode(doseReminders, forKey: .doseReminders)
    }

}

// MARK: - Security

struct ChangePasswordRequest: Encodable, Equatable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

struct DeleteAccountRequest: Encodable, Equatable {
    let currentPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
    }
}

// MARK: - Export

enum DataExportFormat: String, Codable, Equatable {
    case pdf
    case csv
}

struct DataExportRequest: Encodable, Equatable {
    let format: DataExportFormat
    let includeProtocols: Bool
    let includeCheckins: Bool
    let includeInsights: Bool
    let startDate: Date?
    let endDate: Date?

    enum CodingKeys: String, CodingKey {
        case format
        case includeProtocols = "include_protocols"
        case includeCheckins = "include_checkins"
        case includeInsights = "include_insights"
        case startDate = "start_date"
        case endDate = "end_date"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(includeProtocols, forKey: .includeProtocols)
        try container.encode(includeCheckins, forKey: .includeCheckins)
        try container.encode(includeInsights, forKey: .includeInsights)
        if let startDate {
            try container.encode(APIDateOnly.string(from: startDate), forKey: .startDate)
        }
        if let endDate {
            try container.encode(APIDateOnly.string(from: endDate), forKey: .endDate)
        }
    }
}

struct DownloadedFile: Equatable {
    let url: URL
    let suggestedFilename: String
}
