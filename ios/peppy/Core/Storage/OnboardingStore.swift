import Foundation

protocol OnboardingStoreProtocol: AnyObject {
    var hasKnownAccount: Bool { get set }
    func loadAnonymousDraft() -> OnboardingDraft?
    func saveAnonymousDraft(_ draft: OnboardingDraft)
    func clearAnonymousDraft()
    func associateAnonymousDraft(with userID: UUID)
    func loadDraft(for userID: UUID) -> OnboardingDraft?
    func removeDraft(for userID: UUID)
}

final class UserDefaultsOnboardingStore: OnboardingStoreProtocol {
    private enum Key {
        static let anonymous = "peppy.onboarding.anonymous"
        static let knownAccount = "peppy.onboarding.hasKnownAccount"

        static func user(_ id: UUID) -> String {
            "peppy.onboarding.user.\(id.uuidString.lowercased())"
        }
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var hasKnownAccount: Bool {
        get { defaults.bool(forKey: Key.knownAccount) }
        set { defaults.set(newValue, forKey: Key.knownAccount) }
    }

    func loadAnonymousDraft() -> OnboardingDraft? {
        load(forKey: Key.anonymous)
    }

    func saveAnonymousDraft(_ draft: OnboardingDraft) {
        save(draft, forKey: Key.anonymous)
    }

    func clearAnonymousDraft() {
        defaults.removeObject(forKey: Key.anonymous)
    }

    func associateAnonymousDraft(with userID: UUID) {
        if let draft = loadAnonymousDraft() {
            save(draft, forKey: Key.user(userID))
            clearAnonymousDraft()
        }
        hasKnownAccount = true
    }

    func loadDraft(for userID: UUID) -> OnboardingDraft? {
        load(forKey: Key.user(userID))
    }

    func removeDraft(for userID: UUID) {
        defaults.removeObject(forKey: Key.user(userID))
    }

    private func save(_ draft: OnboardingDraft, forKey key: String) {
        guard let data = try? encoder.encode(draft) else { return }
        defaults.set(data, forKey: key)
    }

    private func load(forKey key: String) -> OnboardingDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let draft = try? decoder.decode(OnboardingDraft.self, from: data),
              draft.schemaVersion == OnboardingDraft.currentSchemaVersion else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return draft
    }
}

final class InMemoryOnboardingStore: OnboardingStoreProtocol {
    var hasKnownAccount = false
    var anonymousDraft: OnboardingDraft?
    var userDrafts: [UUID: OnboardingDraft] = [:]

    func loadAnonymousDraft() -> OnboardingDraft? { anonymousDraft }
    func saveAnonymousDraft(_ draft: OnboardingDraft) { anonymousDraft = draft }
    func clearAnonymousDraft() { anonymousDraft = nil }

    func associateAnonymousDraft(with userID: UUID) {
        if let anonymousDraft {
            userDrafts[userID] = anonymousDraft
            self.anonymousDraft = nil
        }
        hasKnownAccount = true
    }

    func loadDraft(for userID: UUID) -> OnboardingDraft? {
        userDrafts[userID]
    }

    func removeDraft(for userID: UUID) {
        userDrafts[userID] = nil
    }
}
