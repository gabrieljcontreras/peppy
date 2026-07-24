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
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case id, email, timezone
        case displayName = "display_name"
        case isVerified = "is_verified"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        email: String,
        createdAt: Date? = nil,
        displayName: String? = nil,
        isVerified: Bool? = nil,
        timezone: String? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.isVerified = isVerified
        self.createdAt = createdAt
        self.timezone = timezone
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

/// Backend `date` fields (e.g. `start_date`) travel as plain `yyyy-MM-dd` strings,
/// unlike `datetime` fields which use full ISO 8601 timestamps.
enum APIDateOnly {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}

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

    init(
        id: UUID,
        name: String,
        startDate: Date,
        endDate: Date?,
        notes: String?,
        isActive: Bool,
        setupStatus: String?,
        isStarter: Bool?,
        compounds: [Compound]
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.isActive = isActive
        self.setupStatus = setupStatus
        self.isStarter = isStarter
        self.compounds = compounds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try APIDateOnly.date(
            from: container.decode(String.self, forKey: .startDate)
        ) ?? container.decode(Date.self, forKey: .startDate)
        if let rawEndDate = try container.decodeIfPresent(String.self, forKey: .endDate) {
            endDate = APIDateOnly.date(from: rawEndDate) ?? (try? container.decode(Date.self, forKey: .endDate))
        } else {
            endDate = nil
        }
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        setupStatus = try container.decodeIfPresent(String.self, forKey: .setupStatus)
        isStarter = try container.decodeIfPresent(Bool.self, forKey: .isStarter)
        compounds = try container.decode([Compound].self, forKey: .compounds)
    }
}

struct Compound: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let doseMg: Double
    let doseUnit: String
    let frequency: String
    let administrationRoute: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, frequency, notes
        case doseMg = "dose_mg"
        case doseUnit = "dose_unit"
        case administrationRoute = "administration_route"
    }
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(APIDateOnly.string(from: startDate), forKey: .startDate)
        try container.encodeIfPresent(endDate.map(APIDateOnly.string(from:)), forKey: .endDate)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(compounds, forKey: .compounds)
    }
}

struct CreateCompoundRequest: Encodable {
    let name: String
    let doseMg: Double
    let doseUnit: String
    let frequency: String
    let administrationRoute: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name, frequency, notes
        case doseMg = "dose_mg"
        case doseUnit = "dose_unit"
        case administrationRoute = "administration_route"
    }
}

struct UpdateCompoundRequest: Encodable {
    let name: String?
    let doseMg: Double?
    let doseUnit: String?
    let frequency: String?
    let administrationRoute: String?
    let notes: String?
    private let clearNotes: Bool

    enum CodingKeys: String, CodingKey {
        case name, frequency, notes
        case doseMg = "dose_mg"
        case doseUnit = "dose_unit"
        case administrationRoute = "administration_route"
    }

    init(
        name: String? = nil,
        doseMg: Double? = nil,
        doseUnit: String? = nil,
        frequency: String? = nil,
        administrationRoute: String? = nil,
        notes: String? = nil,
        clearNotes: Bool = false
    ) {
        self.name = name
        self.doseMg = doseMg
        self.doseUnit = doseUnit
        self.frequency = frequency
        self.administrationRoute = administrationRoute
        self.notes = notes
        self.clearNotes = clearNotes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(doseMg, forKey: .doseMg)
        try container.encodeIfPresent(doseUnit, forKey: .doseUnit)
        try container.encodeIfPresent(frequency, forKey: .frequency)
        try container.encodeIfPresent(administrationRoute, forKey: .administrationRoute)
        if clearNotes && notes == nil {
            try container.encodeNil(forKey: .notes)
        } else {
            try container.encodeIfPresent(notes, forKey: .notes)
        }
    }
}

struct UpdateProtocolRequest: Encodable {
    let name: String?
    let startDate: Date?
    let endDate: Date?
    let notes: String?
    private let clearEndDate: Bool
    private let clearNotes: Bool

    enum CodingKeys: String, CodingKey {
        case name, notes
        case startDate = "start_date"
        case endDate = "end_date"
    }

    init(
        name: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String? = nil,
        clearEndDate: Bool = false,
        clearNotes: Bool = false
    ) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.clearEndDate = clearEndDate
        self.clearNotes = clearNotes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(startDate.map(APIDateOnly.string(from:)), forKey: .startDate)
        if let endDate {
            try container.encode(APIDateOnly.string(from: endDate), forKey: .endDate)
        } else if clearEndDate {
            try container.encodeNil(forKey: .endDate)
        }
        if clearNotes && notes == nil {
            try container.encodeNil(forKey: .notes)
        } else {
            try container.encodeIfPresent(notes, forKey: .notes)
        }
    }
}

// MARK: - Dose Log

struct DoseLog: Codable, Identifiable, Hashable {
    let id: UUID
    let protocolID: UUID
    let compoundID: UUID
    let dose: Double
    let unit: String
    let administeredAt: Date
    let route: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, dose, unit, route, notes
        case protocolID = "protocol_id"
        case compoundID = "compound_id"
        case administeredAt = "administered_at"
    }

    init(
        id: UUID,
        protocolID: UUID,
        compoundID: UUID,
        dose: Double,
        unit: String,
        administeredAt: Date,
        route: String,
        notes: String?
    ) {
        self.id = id
        self.protocolID = protocolID
        self.compoundID = compoundID
        self.dose = dose
        self.unit = unit
        self.administeredAt = administeredAt
        self.route = route
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        protocolID = try container.decode(UUID.self, forKey: .protocolID)
        compoundID = try container.decode(UUID.self, forKey: .compoundID)
        dose = try container.decode(Double.self, forKey: .dose)
        unit = try container.decode(String.self, forKey: .unit)
        // The backend emits microsecond fractions, which JSONDecoder's .iso8601 rejects.
        if let raw = try? container.decode(String.self, forKey: .administeredAt),
           let parsed = Self.timestampFormatter.date(from: raw)
               ?? Self.fractionalTimestampFormatter.date(from: raw) {
            administeredAt = parsed
        } else {
            administeredAt = try container.decode(Date.self, forKey: .administeredAt)
        }
        route = try container.decode(String.self, forKey: .route)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct CreateDoseLogRequest: Encodable {
    let protocolID: UUID
    let compoundID: UUID
    let dose: Double
    let unit: String
    let administeredAt: Date
    let route: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case dose, unit, route, notes
        case protocolID = "protocol_id"
        case compoundID = "compound_id"
        case administeredAt = "administered_at"
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

struct Checkin: Codable, Identifiable, Equatable {
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
        createdAt = try Self.decodeTimestampIfPresent(forKey: .createdAt, from: container)
        updatedAt = try Self.decodeTimestampIfPresent(forKey: .updatedAt, from: container)
    }

    private static func decodeTimestampIfPresent(
        forKey key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Date? {
        guard container.contains(key), try !container.decodeNil(forKey: key) else {
            return nil
        }

        let raw = try container.decode(String.self, forKey: key)
        guard let parsed = timestamp(from: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Expected ISO-8601 timestamp with or without a timezone."
            )
        }
        return parsed
    }

    private static func timestamp(from raw: String) -> Date? {
        guard timestampValidators.contains(where: { $0.date(from: raw) != nil }) else {
            return nil
        }

        return timestampFormatter.date(from: raw)
            ?? fractionalTimestampFormatter.date(from: raw)
            ?? timestampFormatter.date(from: raw + "Z")
            ?? fractionalTimestampFormatter.date(from: raw + "Z")
    }

    private static let timestampValidators: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
    ].map { format in
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

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

struct UpdateCheckinRequest: Encodable, Equatable {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.dateFormatter.string(from: date), forKey: .date)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encode(energyLevel, forKey: .energyLevel)
        try container.encode(sleepQuality, forKey: .sleepQuality)
        try container.encode(appetiteLevel, forKey: .appetiteLevel)
        try container.encode(mood, forKey: .mood)
        try container.encode(nausea, forKey: .nausea)
        try container.encode(injectionSiteReaction, forKey: .injectionSiteReaction)
        try container.encode(fatigue, forKey: .fatigue)
        try container.encode(headache, forKey: .headache)
        try container.encode(giIssues, forKey: .giIssues)
        try container.encode(notes, forKey: .notes)
    }

    private static let dateFormatter: DateFormatter = {
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

struct InsightSupportingItem: Codable, Equatable, Hashable {
    let iconKey: String
    let label: String
    let sublabel: String?
    let value: String

    enum CodingKeys: String, CodingKey {
        case label, sublabel, value
        case iconKey = "icon_key"
    }
}

struct Insight: Codable, Identifiable, Equatable {
    let id: UUID
    let type: String
    let severity: String
    let title: String
    let description: String
    let explanation: String
    let confidence: Double
    let createdAt: Date
    let readAt: Date?
    let dismissedAt: Date?
    let snoozedUntil: Date?
    let actionTaken: String?
    let actionNotes: String?
    let supportingData: [InsightSupportingItem]?

    enum CodingKeys: String, CodingKey {
        case id, type, severity, title, description, explanation, confidence
        case createdAt = "created_at"
        case readAt = "read_at"
        case dismissedAt = "dismissed_at"
        case snoozedUntil = "snoozed_until"
        case actionTaken = "action_taken"
        case actionNotes = "action_notes"
        case supportingData = "supporting_data"
    }

    var isUnread: Bool {
        readAt == nil && dismissedAt == nil
    }

    init(
        id: UUID,
        type: String,
        severity: String,
        title: String,
        description: String,
        explanation: String,
        confidence: Double,
        createdAt: Date,
        readAt: Date? = nil,
        dismissedAt: Date? = nil,
        snoozedUntil: Date? = nil,
        actionTaken: String? = nil,
        actionNotes: String? = nil,
        supportingData: [InsightSupportingItem]? = nil
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.explanation = explanation
        self.confidence = confidence
        self.createdAt = createdAt
        self.readAt = readAt
        self.dismissedAt = dismissedAt
        self.snoozedUntil = snoozedUntil
        self.actionTaken = actionTaken
        self.actionNotes = actionNotes
        self.supportingData = supportingData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        severity = try container.decode(String.self, forKey: .severity)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        explanation = try container.decode(String.self, forKey: .explanation)
        confidence = try container.decode(Double.self, forKey: .confidence)
        createdAt = try Self.decodeTimestamp(forKey: .createdAt, from: container)
        readAt = try Self.decodeTimestampIfPresent(forKey: .readAt, from: container)
        dismissedAt = try Self.decodeTimestampIfPresent(forKey: .dismissedAt, from: container)
        snoozedUntil = try Self.decodeTimestampIfPresent(forKey: .snoozedUntil, from: container)
        actionTaken = try container.decodeIfPresent(String.self, forKey: .actionTaken)
        actionNotes = try container.decodeIfPresent(String.self, forKey: .actionNotes)
        supportingData = try container.decodeIfPresent(
            [InsightSupportingItem].self,
            forKey: .supportingData
        )
    }

    private static func decodeTimestamp(
        forKey key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Date {
        if let raw = try? container.decode(String.self, forKey: key),
           let parsed = timestamp(from: raw) {
            return parsed
        }
        return try container.decode(Date.self, forKey: key)
    }

    private static func decodeTimestampIfPresent(
        forKey key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Date? {
        guard try !container.decodeNil(forKey: key) else {
            return nil
        }
        if let raw = try? container.decode(String.self, forKey: key),
           let parsed = timestamp(from: raw) {
            return parsed
        }
        return try container.decodeIfPresent(Date.self, forKey: key)
    }

    private static func timestamp(from raw: String) -> Date? {
        timestampFormatter.date(from: raw) ?? fractionalTimestampFormatter.date(from: raw)
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct WeeklySummaryHero: Codable, Equatable {
    let weightDeltaKg: Double?
    let weightFromKg: Double?
    let weightToKg: Double?

    enum CodingKeys: String, CodingKey {
        case weightDeltaKg = "weight_delta_kg"
        case weightFromKg = "weight_from_kg"
        case weightToKg = "weight_to_kg"
    }
}

struct WeeklySummaryMetric: Codable, Equatable, Identifiable {
    let key: String
    let label: String
    let value: String
    let detail: String?
    let positive: Bool?

    var id: String { key }
}

struct WeeklyWatchItem: Codable, Equatable {
    let title: String
    let detail: String
}

struct WeeklyWeightPoint: Codable, Equatable {
    let date: String
    let weightKg: Double

    enum CodingKeys: String, CodingKey {
        case date
        case weightKg = "weight_kg"
    }
}

struct WeeklySummaryPayload: Codable, Equatable {
    let weekStart: String
    let weekEnd: String
    let hero: WeeklySummaryHero
    let weightSeries: [WeeklyWeightPoint]
    let whatChanged: [WeeklySummaryMetric]
    let whatToWatch: [WeeklyWatchItem]
    let providerQuestions: [String]
    let narrative: String?

    enum CodingKeys: String, CodingKey {
        case hero, narrative
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case weightSeries = "weight_series"
        case whatChanged = "what_changed"
        case whatToWatch = "what_to_watch"
        case providerQuestions = "provider_questions"
    }
}

struct WeeklySummaryEnvelope: Codable, Equatable {
    let available: Bool
    let summary: WeeklySummaryPayload?
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
