import Foundation

enum SettingsRoute: Hashable {
    case profile
    case notifications
    case dataExport
    case security
    case help
    case about
    case legal

    var title: String {
        switch self {
        case .profile: return "Profile"
        case .notifications: return "Notifications"
        case .dataExport: return "Data export"
        case .security: return "Security & privacy"
        case .help: return "Help & About"
        case .about: return "About peppy"
        case .legal: return "Legal"
        }
    }
}

enum SettingsRowTone: Equatable {
    case purple
    case orange
    case green
    case coral
    case gray
    case brand
}

struct SettingsRowModel: Equatable, Identifiable {
    let route: SettingsRoute
    let title: String
    let subtitle: String
    let systemImage: String?
    let tone: SettingsRowTone

    var id: SettingsRoute { route }
}

enum SettingsRootViewModel {
    static let profileRoute: SettingsRoute = .profile

    static let myDataRows: [SettingsRowModel] = [
        SettingsRowModel(
            route: .notifications,
            title: "Notifications",
            subtitle: "Manage your alerts and reminders",
            systemImage: "bell",
            tone: .purple
        ),
        SettingsRowModel(
            route: .dataExport,
            title: "Data export",
            subtitle: "Export your data",
            systemImage: "square.and.arrow.down",
            tone: .orange
        )
    ]

    static let accountAndAppRows: [SettingsRowModel] = [
        SettingsRowModel(
            route: .security,
            title: "Security",
            subtitle: "Password, biometrics, and privacy",
            systemImage: "lock",
            tone: .green
        ),
        SettingsRowModel(
            route: .help,
            title: "Help and support",
            subtitle: "FAQs and contact support",
            systemImage: "questionmark",
            tone: .coral
        ),
        SettingsRowModel(
            route: .about,
            title: "About peppy",
            subtitle: "Learn about our mission",
            systemImage: nil,
            tone: .brand
        ),
        SettingsRowModel(
            route: .legal,
            title: "Legal",
            subtitle: "Terms of service and privacy policy",
            systemImage: "doc.text",
            tone: .gray
        )
    ]

    static let releaseRows = myDataRows + accountAndAppRows
}

struct SettingsAppVersion: Equatable {
    let shortVersion: String
    let build: String

    init(shortVersion: String, build: String) {
        self.shortVersion = shortVersion
        self.build = build
    }

    init(bundle: Bundle = .main) {
        shortVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var displayText: String {
        "App version \(shortVersion) (\(build))"
    }
}

extension AccountProfile {
    static func empty(for userID: UUID?) -> AccountProfile {
        AccountProfile(
            id: userID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            schemaVersion: 1,
            heightCm: nil,
            preferredHeightUnit: nil,
            weightKg: nil,
            preferredWeightUnit: nil,
            baselineDate: nil,
            primaryGoal: nil,
            secondaryGoal: nil,
            focusArea: nil
        )
    }
}
