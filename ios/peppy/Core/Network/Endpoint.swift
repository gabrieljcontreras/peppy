import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum Endpoint {
    // MARK: - Auth
    case register(email: String, password: String)
    case login(email: String, password: String)
    case refreshToken(refreshToken: String)
    case logout
    case me

    // MARK: - Profile
    case attachOnboardingProfile(OnboardingProfileAttachRequest)

    // MARK: - Dashboard
    case getDashboardSummary

    // MARK: - Protocols
    case getProtocols
    case getProtocol(id: UUID)
    case createProtocol(CreateProtocolRequest)
    case updateProtocol(id: UUID, UpdateProtocolRequest)
    case deleteProtocol(id: UUID)
    case activateProtocol(id: UUID)
    case activateStarterProtocol(id: UUID, StarterProtocolActivationRequest)
    case deactivateProtocol(id: UUID)
    case addCompound(protocolID: UUID, CreateCompoundRequest)
    case updateCompound(id: UUID, UpdateCompoundRequest)
    case removeCompound(id: UUID)

    // MARK: - Dose Logs
    case getDoseLogs(protocolID: UUID)
    case createDoseLog(CreateDoseLogRequest)

    // MARK: - Check-ins
    case getCheckins(startDate: Date?, endDate: Date?)
    case getCheckin(id: UUID)
    case createCheckin(CreateCheckinRequest)

    // MARK: - Labs
    case getLabs
    case getLab(id: UUID)
    case createLab(CreateLabRequest)

    // MARK: - Insights
    case getInsights(unreadOnly: Bool?, type: String?, severity: String?)
    case getInsight(id: UUID)
    case markInsightRead(id: UUID)
    case insightAction(id: UUID, action: String)
    case generateInsights
    case getWeeklySummary

    // MARK: - Wearables
    case getConnections
    case connectWearable(provider: String)
    case syncWearable(provider: String)
    case disconnectWearable(id: UUID)

    // MARK: - Notifications
    case registerDevice(token: String, platform: String)
    case getDevices
    case deleteDevice(id: UUID)
    case getNotificationPreferences
    case updateNotificationPreferences(UpdatePreferencesRequest)

    var path: String {
        switch self {
        // Auth
        case .register: return "/auth/register"
        case .login: return "/auth/login"
        case .refreshToken: return "/auth/refresh"
        case .logout: return "/auth/logout"
        case .me: return "/auth/me"

        // Profile
        case .attachOnboardingProfile:
            return "/profile/onboarding/attach"

        // Dashboard
        case .getDashboardSummary:
            return "/dashboard/summary"

        // Protocols
        case .getProtocols, .createProtocol: return "/protocols"
        case .getProtocol(let id), .updateProtocol(let id, _), .deleteProtocol(let id):
            return "/protocols/\(id)"
        case .activateProtocol(let id), .activateStarterProtocol(let id, _):
            return "/protocols/\(id)/activate"
        case .deactivateProtocol(let id): return "/protocols/\(id)/deactivate"
        case .addCompound(let protocolID, _): return "/protocols/\(protocolID)/compounds"
        case .updateCompound(let id, _), .removeCompound(let id):
            return "/protocols/compounds/\(id)"

        // Dose Logs
        case .getDoseLogs(let protocolID): return "/protocols/\(protocolID)/dose-logs"
        case .createDoseLog: return "/dose-logs"

        // Check-ins
        case .getCheckins, .createCheckin: return "/checkins"
        case .getCheckin(let id): return "/checkins/\(id)"

        // Labs
        case .getLabs, .createLab: return "/labs"
        case .getLab(let id): return "/labs/\(id)"

        // Insights
        case .getInsights, .generateInsights: return "/insights"
        case .getInsight(let id): return "/insights/\(id)"
        case .markInsightRead(let id): return "/insights/\(id)/read"
        case .insightAction(let id, _): return "/insights/\(id)/action"
        case .getWeeklySummary: return "/insights/summary/weekly"

        // Wearables
        case .getConnections: return "/wearables/connections"
        case .connectWearable(let provider): return "/wearables/connect/\(provider)"
        case .syncWearable(let provider): return "/wearables/sync/\(provider)"
        case .disconnectWearable(let id): return "/wearables/connections/\(id)"

        // Notifications
        case .registerDevice, .getDevices: return "/notifications/devices"
        case .deleteDevice(let id): return "/notifications/devices/\(id)"
        case .getNotificationPreferences, .updateNotificationPreferences:
            return "/notifications/preferences"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .login, .refreshToken, .logout,
             .attachOnboardingProfile,
             .createProtocol, .activateProtocol, .activateStarterProtocol, .deactivateProtocol,
             .addCompound, .createDoseLog,
             .createCheckin,
             .createLab,
             .markInsightRead, .insightAction, .generateInsights,
             .connectWearable, .syncWearable,
             .registerDevice:
            return .post
        case .updateProtocol, .updateCompound, .updateNotificationPreferences:
            return .patch
        case .deleteProtocol, .removeCompound, .disconnectWearable, .deleteDevice:
            return .delete
        default:
            return .get
        }
    }

    var body: Encodable? {
        switch self {
        case .register(let email, let password):
            return ["email": email, "password": password]
        case .login(let email, let password):
            return ["email": email, "password": password]
        case .refreshToken(let token):
            return ["refresh_token": token]
        case .attachOnboardingProfile(let request):
            return request
        case .createProtocol(let request):
            return request
        case .updateProtocol(_, let request):
            return request
        case .activateStarterProtocol(_, let request):
            return request
        case .addCompound(_, let request):
            return request
        case .updateCompound(_, let request):
            return request
        case .createDoseLog(let request):
            return request
        case .createCheckin(let request):
            return request
        case .createLab(let request):
            return request
        case .insightAction(_, let action):
            return ["action": action]
        case .registerDevice(let token, let platform):
            return ["token": token, "platform": platform]
        case .updateNotificationPreferences(let request):
            return request
        default:
            return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .getCheckins(let startDate, let endDate):
            var items: [URLQueryItem] = []
            let formatter = ISO8601DateFormatter()
            if let start = startDate {
                items.append(URLQueryItem(name: "start_date", value: formatter.string(from: start)))
            }
            if let end = endDate {
                items.append(URLQueryItem(name: "end_date", value: formatter.string(from: end)))
            }
            return items.isEmpty ? nil : items

        case .getInsights(let unreadOnly, let type, let severity):
            var items: [URLQueryItem] = []
            if let unreadOnly = unreadOnly {
                items.append(URLQueryItem(name: "unread_only", value: String(unreadOnly)))
            }
            if let type = type {
                items.append(URLQueryItem(name: "type", value: type))
            }
            if let severity = severity {
                items.append(URLQueryItem(name: "severity", value: severity))
            }
            return items.isEmpty ? nil : items

        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .register, .login, .refreshToken:
            return false
        default:
            return true
        }
    }

    /// Stable request identity for tests and mocks. Paths alone collide when
    /// one path serves multiple verbs (e.g. GET vs POST `/protocols`).
    var requestID: String {
        "\(method.rawValue) \(path)"
    }
}
