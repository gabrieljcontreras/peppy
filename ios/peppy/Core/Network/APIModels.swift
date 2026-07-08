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
    let displayName: String?
    let isVerified: Bool?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case isVerified = "is_verified"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        email: String,
        createdAt: Date? = nil,
        displayName: String? = nil,
        isVerified: Bool? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.isVerified = isVerified
        self.createdAt = createdAt
    }
}

// MARK: - Onboarding Profile

struct OnboardingProfilePayload: Codable, Equatable {
    let schemaVersion: Int
    let age: Int?
    let heightCm: Double?
    let preferredHeightUnit: String?
    let weightKg: Double?
    let preferredWeightUnit: String?
    let peptides: [String]
    let customPeptides: [String]
    let otherMedications: String?
    let workoutDaysPerWeek: Int?
    let goals: [String]
    let customGoal: String?
    let healthkit: HealthKitProfilePayload?
    let notifications: NotificationProfilePayload?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case age
        case heightCm = "height_cm"
        case preferredHeightUnit = "preferred_height_unit"
        case weightKg = "weight_kg"
        case preferredWeightUnit = "preferred_weight_unit"
        case peptides
        case customPeptides = "custom_peptides"
        case otherMedications = "other_medications"
        case workoutDaysPerWeek = "workout_days_per_week"
        case goals
        case customGoal = "custom_goal"
        case healthkit
        case notifications
    }
}

struct HealthKitProfilePayload: Codable, Equatable {
    let requested: Bool
    let lastSyncAt: Date?

    enum CodingKeys: String, CodingKey {
        case requested
        case lastSyncAt = "last_sync_at"
    }
}

struct NotificationProfilePayload: Codable, Equatable {
    let authorized: Bool
}

struct OnboardingProfileAttachRequest: Encodable {
    let schemaVersion: Int
    let draftId: String
    let draftCreatedAt: Date
    let draftUpdatedAt: Date
    let isComplete: Bool
    let currentStep: String
    let profile: OnboardingProfilePayload

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case draftId = "draft_id"
        case draftCreatedAt = "draft_created_at"
        case draftUpdatedAt = "draft_updated_at"
        case isComplete = "is_complete"
        case currentStep = "current_step"
        case profile
    }
}

extension OnboardingProfileAttachRequest {
    init(draft: OnboardingDraft) {
        self.schemaVersion = draft.schemaVersion
        self.draftId = draft.draftID.uuidString.lowercased()
        self.draftCreatedAt = draft.createdAt
        self.draftUpdatedAt = draft.updatedAt
        self.isComplete = draft.isComplete
        self.currentStep = draft.currentStep.serverValue
        self.profile = OnboardingProfilePayload(draft: draft)
    }
}

extension OnboardingProfilePayload {
    init(draft: OnboardingDraft) {
        self.schemaVersion = draft.schemaVersion
        self.age = draft.age
        self.heightCm = draft.heightCentimeters
        self.preferredHeightUnit = draft.heightCentimeters == nil ? nil : draft.preferredHeightUnit.serverValue
        self.weightKg = draft.weightKilograms
        self.preferredWeightUnit = draft.weightKilograms == nil ? nil : draft.preferredWeightUnit.serverValue
        self.peptides = draft.selectedPeptides
        self.customPeptides = draft.customPeptides
        self.otherMedications = draft.otherMedications
        self.workoutDaysPerWeek = draft.workoutDaysPerWeek
        self.goals = draft.goals.map(\.serverValue).sorted()
        self.customGoal = draft.customGoal
        self.healthkit = draft.healthChoice == .notAsked
            ? nil
            : HealthKitProfilePayload(requested: draft.healthChoice == .requested, lastSyncAt: nil)
        self.notifications = draft.notificationChoice == .notAsked
            ? nil
            : NotificationProfilePayload(authorized: draft.notificationOutcome == .authorized)
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
    let setupStatus: String?
    let isStarter: Bool?
    let compounds: [Compound]

    enum CodingKeys: String, CodingKey {
        case id, name, notes, compounds
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case setupStatus = "setup_status"
        case isStarter = "is_starter"
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

struct StarterProtocolActivationRequest: Encodable {
    let doseMg: Double
    let doseUnit: String
    let frequency: String
    let administrationRoute: String
    let startDate: Date

    enum CodingKeys: String, CodingKey {
        case doseMg = "dose_mg"
        case doseUnit = "dose_unit"
        case frequency
        case administrationRoute = "administration_route"
        case startDate = "start_date"
    }
}

// MARK: - Check-in

struct Checkin: Codable, Identifiable {
    let id: UUID
    let userId: UUID?
    let date: Date
    let weightKg: Double?
    let energyLevel: Int?
    let sleepQuality: Int?
    let appetiteLevel: Int?
    let mood: Int?
    let nausea: Int?
    let injectionSiteReaction: Int?
    let fatigue: Int?
    let headache: Int?
    let giIssues: Int?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, date, mood, nausea, fatigue, headache, notes
        case userId = "user_id"
        case weightKg = "weight_kg"
        case energyLevel = "energy_level"
        case sleepQuality = "sleep_quality"
        case appetiteLevel = "appetite_level"
        case injectionSiteReaction = "injection_site_reaction"
        case giIssues = "gi_issues"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        userId: UUID?,
        date: Date,
        weightKg: Double?,
        energyLevel: Int?,
        sleepQuality: Int?,
        appetiteLevel: Int?,
        mood: Int?,
        nausea: Int?,
        injectionSiteReaction: Int?,
        fatigue: Int?,
        headache: Int?,
        giIssues: Int?,
        notes: String?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.weightKg = weightKg
        self.energyLevel = energyLevel
        self.sleepQuality = sleepQuality
        self.appetiteLevel = appetiteLevel
        self.mood = mood
        self.nausea = nausea
        self.injectionSiteReaction = injectionSiteReaction
        self.fatigue = fatigue
        self.headache = headache
        self.giIssues = giIssues
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        date = try Self.dateOnlyFormatter.date(
            from: container.decode(String.self, forKey: .date)
        ) ?? container.decode(Date.self, forKey: .date)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        energyLevel = try container.decodeIfPresent(Int.self, forKey: .energyLevel)
        sleepQuality = try container.decodeIfPresent(Int.self, forKey: .sleepQuality)
        appetiteLevel = try container.decodeIfPresent(Int.self, forKey: .appetiteLevel)
        mood = try container.decodeIfPresent(Int.self, forKey: .mood)
        nausea = try container.decodeIfPresent(Int.self, forKey: .nausea)
        injectionSiteReaction = try container.decodeIfPresent(Int.self, forKey: .injectionSiteReaction)
        fatigue = try container.decodeIfPresent(Int.self, forKey: .fatigue)
        headache = try container.decodeIfPresent(Int.self, forKey: .headache)
        giIssues = try container.decodeIfPresent(Int.self, forKey: .giIssues)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct CreateCheckinRequest: Codable, Equatable {
    let date: Date
    let weightKg: Double?
    let energyLevel: Int?
    let sleepQuality: Int?
    let appetiteLevel: Int?
    let mood: Int?
    let nausea: Int?
    let injectionSiteReaction: Int?
    let fatigue: Int?
    let headache: Int?
    let giIssues: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case date, mood, nausea, fatigue, headache, notes
        case weightKg = "weight_kg"
        case energyLevel = "energy_level"
        case sleepQuality = "sleep_quality"
        case appetiteLevel = "appetite_level"
        case injectionSiteReaction = "injection_site_reaction"
        case giIssues = "gi_issues"
    }

    init(
        date: Date,
        weightKg: Double?,
        energyLevel: Int?,
        sleepQuality: Int?,
        appetiteLevel: Int?,
        mood: Int?,
        nausea: Int?,
        injectionSiteReaction: Int?,
        fatigue: Int?,
        headache: Int?,
        giIssues: Int?,
        notes: String?
    ) {
        self.date = date
        self.weightKg = weightKg
        self.energyLevel = energyLevel
        self.sleepQuality = sleepQuality
        self.appetiteLevel = appetiteLevel
        self.mood = mood
        self.nausea = nausea
        self.injectionSiteReaction = injectionSiteReaction
        self.fatigue = fatigue
        self.headache = headache
        self.giIssues = giIssues
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try Self.dateOnlyFormatter.date(
            from: container.decode(String.self, forKey: .date)
        ) ?? container.decode(Date.self, forKey: .date)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        energyLevel = try container.decodeIfPresent(Int.self, forKey: .energyLevel)
        sleepQuality = try container.decodeIfPresent(Int.self, forKey: .sleepQuality)
        appetiteLevel = try container.decodeIfPresent(Int.self, forKey: .appetiteLevel)
        mood = try container.decodeIfPresent(Int.self, forKey: .mood)
        nausea = try container.decodeIfPresent(Int.self, forKey: .nausea)
        injectionSiteReaction = try container.decodeIfPresent(Int.self, forKey: .injectionSiteReaction)
        fatigue = try container.decodeIfPresent(Int.self, forKey: .fatigue)
        headache = try container.decodeIfPresent(Int.self, forKey: .headache)
        giIssues = try container.decodeIfPresent(Int.self, forKey: .giIssues)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.dateOnlyFormatter.string(from: date), forKey: .date)
        try container.encodeIfPresent(weightKg, forKey: .weightKg)
        try container.encodeIfPresent(energyLevel, forKey: .energyLevel)
        try container.encodeIfPresent(sleepQuality, forKey: .sleepQuality)
        try container.encodeIfPresent(appetiteLevel, forKey: .appetiteLevel)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(nausea, forKey: .nausea)
        try container.encodeIfPresent(injectionSiteReaction, forKey: .injectionSiteReaction)
        try container.encodeIfPresent(fatigue, forKey: .fatigue)
        try container.encodeIfPresent(headache, forKey: .headache)
        try container.encodeIfPresent(giIssues, forKey: .giIssues)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
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
