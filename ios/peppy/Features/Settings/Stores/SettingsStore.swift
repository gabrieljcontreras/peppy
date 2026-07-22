import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private let api: APIClientProtocol
    private var sessionGeneration = 0
    private var refreshGeneration = 0

    private(set) var user: User?
    private(set) var profile: AccountProfile?
    private(set) var notificationPreferences: NotificationPreferences?
    var isRefreshing = false
    var refreshError: APIError?

    init(
        api: APIClientProtocol,
        initialUser: User? = nil,
        cachedProfile: AccountProfile? = nil,
        cachedNotificationPreferences: NotificationPreferences? = nil
    ) {
        self.api = api
        user = initialUser
        profile = cachedProfile
        notificationPreferences = cachedNotificationPreferences
    }

    func beginSession(user: User) {
        if self.user?.id != user.id {
            resetSession()
        }
        self.user = user
    }

    func refresh() async {
        refreshGeneration += 1
        let session = sessionGeneration
        let refresh = refreshGeneration
        isRefreshing = true
        refreshError = nil

        async let profileResult = fetchProfile()
        async let notificationResult = fetchNotificationPreferences()
        let (loadedProfile, loadedNotifications) = await (
            profileResult,
            notificationResult
        )

        guard session == sessionGeneration, refresh == refreshGeneration else { return }

        var profileError: APIError?
        switch loadedProfile {
        case .success(let confirmedProfile):
            profile = confirmedProfile
        case .failure(.notFound):
            profile = .empty(for: user?.id)
        case .failure(let error):
            profileError = error
        }

        var notificationError: APIError?
        switch loadedNotifications {
        case .success(let confirmedPreferences):
            notificationPreferences = confirmedPreferences
        case .failure(let error):
            notificationError = error
        }

        refreshError = profileError ?? notificationError
        isRefreshing = false
    }

    func updateProfile(
        user userRequest: UpdateCurrentUserRequest,
        profile profileRequest: ProfileUpdateRequest
    ) async throws {
        let generation = sessionGeneration
        let confirmedUser: User = try await api.execute(.updateCurrentUser(userRequest))

        guard generation == sessionGeneration else {
            throw APIError.unauthorized
        }
        let confirmedProfile: AccountProfile = try await api.execute(
            .updateProfile(profileRequest)
        )

        guard generation == sessionGeneration else {
            throw APIError.unauthorized
        }
        user = confirmedUser
        profile = confirmedProfile
    }

    func updateNotifications(
        _ request: UpdateNotificationPreferencesRequest
    ) async throws {
        let generation = sessionGeneration
        let confirmed: NotificationPreferences = try await api.execute(
            .updateNotificationPreferences(request)
        )

        guard generation == sessionGeneration else {
            throw APIError.unauthorized
        }
        notificationPreferences = confirmed
    }

    func resetSession() {
        sessionGeneration += 1
        refreshGeneration += 1
        user = nil
        profile = nil
        notificationPreferences = nil
        isRefreshing = false
        refreshError = nil
    }

    private func fetchProfile() async -> Result<AccountProfile, APIError> {
        do {
            let profile: AccountProfile = try await api.execute(.getProfile)
            return .success(profile)
        } catch {
            return .failure(apiError(from: error))
        }
    }

    private func fetchNotificationPreferences() async -> Result<NotificationPreferences, APIError> {
        do {
            let preferences: NotificationPreferences = try await api.execute(
                .getNotificationPreferences
            )
            return .success(preferences)
        } catch {
            return .failure(apiError(from: error))
        }
    }

    private func apiError(from error: Error) -> APIError {
        error as? APIError ?? .unknown(error.localizedDescription)
    }
}
