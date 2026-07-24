import Foundation
import UIKit

@MainActor
protocol PushRegistrationStoring: AnyObject {
    var deviceID: UUID? { get set }
}

@MainActor
final class UserDefaultsPushRegistrationStore: PushRegistrationStoring {
    private enum Key {
        static let deviceID = "peppy.push.registered-device-id"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var deviceID: UUID? {
        get {
            defaults.string(forKey: Key.deviceID).flatMap(UUID.init(uuidString:))
        }
        set {
            defaults.set(newValue?.uuidString, forKey: Key.deviceID)
        }
    }
}

@MainActor
protocol RemoteNotificationRegistering: AnyObject {
    func registerForRemoteNotifications()
}

@MainActor
final class ApplicationRemoteNotificationRegistrar: RemoteNotificationRegistering {
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}

@MainActor
protocol PushRegistrationCoordinating: AnyObject {
    func registerPendingTokenIfPossible() async
    func unregister() async
    func unregister(authenticatedBy accessToken: String?) async
}

extension PushRegistrationCoordinating {
    func unregister(authenticatedBy accessToken: String?) async {
        await unregister()
    }
}

@MainActor
final class PushRegistrationCoordinator: PushRegistrationCoordinating {
    private let api: APIClientProtocol
    private let registrationStore: PushRegistrationStoring
    private let isSignedIn: () -> Bool
    private var pendingToken: String?
    private var registrationTask: Task<DeviceToken?, Never>?
    private var registrationTaskToken: String?
    private var sessionGeneration = 0
    private var isUnregistering = false

    init(
        api: APIClientProtocol,
        registrationStore: PushRegistrationStoring? = nil,
        isSignedIn: @escaping () -> Bool
    ) {
        self.api = api
        self.registrationStore = registrationStore ?? UserDefaultsPushRegistrationStore()
        self.isSignedIn = isSignedIn
    }

    func receiveAPNSToken(_ token: String) async {
        pendingToken = token
        await registerPendingTokenIfPossible()
    }

    func registerPendingTokenIfPossible() async {
        guard !isUnregistering, isSignedIn(), let token = pendingToken else {
            return
        }

        if let registrationTask {
            _ = await registrationTask.value
            if pendingToken != nil, registrationTaskToken != pendingToken {
                await registerPendingTokenIfPossible()
            }
            return
        }

        let generation = sessionGeneration
        let previousDeviceID = registrationStore.deviceID
        let task = Task<DeviceToken?, Never> {
            try? await api.execute(
                .registerDevice(token: token, platform: "ios")
            )
        }
        registrationTask = task
        registrationTaskToken = token

        let device = await task.value
        guard generation == sessionGeneration, !isUnregistering else {
            return
        }

        registrationTask = nil
        registrationTaskToken = nil
        guard let device else {
            // APNs registration is repaired on the next session/app activation.
            return
        }

        registrationStore.deviceID = device.id
        if let previousDeviceID, previousDeviceID != device.id {
            try? await api.executeVoid(.deleteDevice(id: previousDeviceID))
        }

        guard generation == sessionGeneration, !isUnregistering else {
            return
        }
        if pendingToken == token {
            pendingToken = nil
        }
    }

    func unregister() async {
        await unregister(
            authenticatedBy: nil,
            allowsSharedCredentials: true
        )
    }

    func unregister(authenticatedBy accessToken: String?) async {
        await unregister(
            authenticatedBy: accessToken,
            allowsSharedCredentials: false
        )
    }

    private func unregister(
        authenticatedBy accessToken: String?,
        allowsSharedCredentials: Bool
    ) async {
        sessionGeneration += 1
        isUnregistering = true

        let inFlightDevice = await registrationTask?.value
        registrationTask = nil
        registrationTaskToken = nil
        pendingToken = nil

        var deviceIDs = Set<UUID>()
        if let deviceID = registrationStore.deviceID {
            deviceIDs.insert(deviceID)
        }
        if let inFlightDevice {
            deviceIDs.insert(inFlightDevice.id)
        }
        registrationStore.deviceID = nil

        for deviceID in deviceIDs {
            if let accessToken {
                try? await api.executeVoid(
                    .deleteDevice(id: deviceID),
                    authenticatedBy: accessToken
                )
            } else if allowsSharedCredentials {
                try? await api.executeVoid(.deleteDevice(id: deviceID))
            }
        }

        isUnregistering = false
    }
}
