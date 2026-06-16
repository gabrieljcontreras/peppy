import HealthKit

protocol HealthKitServiceProtocol {
    var isAvailable: Bool { get }
    func requestReadAccess() async -> PermissionOutcome
}

final class HealthKitService: HealthKitServiceProtocol {
    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestReadAccess() async -> PermissionOutcome {
        guard isAvailable else { return .unavailable }

        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            return .requested
        } catch {
            return .failed
        }
    }

    private static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .stepCount,
            .activeEnergyBurned,
            .bodyMass
        ]

        for identifier in quantityTypes {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }

        types.insert(HKObjectType.workoutType())

        return types
    }()
}

struct MockHealthKitService: HealthKitServiceProtocol {
    var outcome: PermissionOutcome

    var isAvailable: Bool {
        outcome != .unavailable
    }

    func requestReadAccess() async -> PermissionOutcome {
        outcome
    }
}
