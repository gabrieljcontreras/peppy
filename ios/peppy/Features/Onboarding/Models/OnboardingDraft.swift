import Foundation

enum HeightUnit: String, Codable, CaseIterable {
    case feetAndInches
    case centimeters
}

enum WeightUnit: String, Codable, CaseIterable {
    case pounds
    case kilograms
}

enum PermissionChoice: String, Codable {
    case notAsked
    case requested
    case skipped
}

enum OnboardingGoal: String, Codable, CaseIterable, Identifiable {
    case trackProtocols
    case understandBody
    case buildHabits
    case seeWhatWorks
    case optimizeRecovery
    case feelInControl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trackProtocols: "Track my protocols"
        case .understandBody: "Understand my body better"
        case .buildHabits: "Build consistent habits"
        case .seeWhatWorks: "See what's actually working"
        case .optimizeRecovery: "Optimize recovery"
        case .feelInControl: "Feel more in control"
        }
    }
}

enum OnboardingStep: Int, Codable, CaseIterable {
    case intro
    case age
    case height
    case weight
    case peptides
    case medications
    case workout
    case goals
    case health
    case notifications

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var questionnaireIndex: Int? {
        guard rawValue >= Self.age.rawValue,
              rawValue <= Self.goals.rawValue else { return nil }
        return rawValue
    }
}

struct OnboardingDraft: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var currentStep: OnboardingStep = .intro
    var isComplete = false
    var age: Int?
    var heightCentimeters: Double?
    var preferredHeightUnit: HeightUnit = .feetAndInches
    var weightKilograms: Double?
    var preferredWeightUnit: WeightUnit = .pounds
    var selectedPeptides: [String] = []
    var customPeptides: [String] = []
    var otherMedications: String?
    var workoutDaysPerWeek: Int?
    var goals: Set<OnboardingGoal> = []
    var customGoal: String?
    var healthChoice: PermissionChoice = .notAsked
    var healthOutcome: PermissionOutcome = .notDetermined
    var notificationChoice: PermissionChoice = .notAsked
    var notificationOutcome: PermissionOutcome = .notDetermined
    var createdAt = Date()
    var updatedAt = Date()

    static func centimeters(feet: Int, inches: Int) -> Double {
        (Double(feet) * 30.48) + (Double(inches) * 2.54)
    }

    static func kilograms(pounds: Double) -> Double {
        pounds * 0.45359237
    }
}
