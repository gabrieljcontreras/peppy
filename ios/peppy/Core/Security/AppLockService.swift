import Foundation
import LocalAuthentication

enum AppLockUnavailabilityReason: Equatable {
    case notAvailable
    case notEnrolled
    case lockedOut

    var message: String {
        switch self {
        case .notAvailable:
            "Face ID isn’t available on this device."
        case .notEnrolled:
            "Set up Face ID in iOS Settings, then try again."
        case .lockedOut:
            "Face ID is temporarily locked. Unlock your iPhone, then try again."
        }
    }
}

enum AppLockAvailability: Equatable {
    case available
    case unavailable(AppLockUnavailabilityReason)
}

@MainActor
protocol AppLockAuthenticating {
    func availability() -> AppLockAvailability
    func authenticate(reason: String) async -> Bool
}

@MainActor
final class LocalAuthenticationAppLockService: AppLockAuthenticating {
    func availability() -> AppLockAvailability {
        availability(using: LAContext())
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""

        guard availability(using: context) == .available else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }

    private func availability(using context: LAContext) -> AppLockAvailability {
        var evaluationError: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &evaluationError
        )

        guard canEvaluate else {
            guard let code = evaluationError.flatMap({
                LAError.Code(rawValue: $0.code)
            }) else {
                return .unavailable(.notAvailable)
            }

            switch code {
            case .biometryNotEnrolled:
                return .unavailable(.notEnrolled)
            case .biometryLockout:
                return .unavailable(.lockedOut)
            default:
                return .unavailable(.notAvailable)
            }
        }

        guard context.biometryType == .faceID else {
            return .unavailable(.notAvailable)
        }

        return .available
    }
}
