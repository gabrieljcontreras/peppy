import UIKit

@MainActor
final class PeppyAppDelegate: NSObject, UIApplicationDelegate {
    var pushRegistrationCoordinator: PushRegistrationCoordinator?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map {
            String(format: "%02x", $0)
        }
        .joined()

        Task {
            await pushRegistrationCoordinator?.receiveAPNSToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Registration is retried on the next authorization or app activation.
        // Do not log the token or treat a transient APNs failure as account state.
    }
}
