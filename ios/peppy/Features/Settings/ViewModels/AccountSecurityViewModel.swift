import Foundation
import Observation

@MainActor
@Observable
final class AccountSecurityViewModel {
    var currentPassword = ""
    var newPassword = ""
    var confirmNewPassword = ""
    var deletionPassword = ""

    private(set) var errorMessage: String?
    private(set) var isChangingPassword = false
    private(set) var isDeletingAccount = false
    private(set) var isDeleteConfirmationPresented = false

    var isAccountActionInFlight: Bool {
        isChangingPassword || isDeletingAccount
    }

    private let api: APIClientProtocol
    private let finishSignedOutSession: @MainActor () async -> Void
    private let removeDeviceSettings: @MainActor () -> Void

    init(
        api: APIClientProtocol,
        finishSignedOutSession: @escaping @MainActor () async -> Void,
        removeDeviceSettings: @escaping @MainActor () -> Void = {}
    ) {
        self.api = api
        self.finishSignedOutSession = finishSignedOutSession
        self.removeDeviceSettings = removeDeviceSettings
    }

    func changePassword() async {
        guard !isChangingPassword, !isDeletingAccount else { return }
        errorMessage = passwordValidationMessage
        guard errorMessage == nil else { return }

        isChangingPassword = true
        defer { isChangingPassword = false }

        do {
            try await api.executeVoid(
                .changePassword(
                    ChangePasswordRequest(
                        currentPassword: currentPassword,
                        newPassword: newPassword
                    )
                )
            )
            await finishSignedOutSession()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func requestAccountDeletion() {
        guard !isChangingPassword, !isDeletingAccount else { return }

        guard !deletionPassword.isEmpty else {
            errorMessage = "Enter your current password to continue."
            isDeleteConfirmationPresented = false
            return
        }

        errorMessage = nil
        isDeleteConfirmationPresented = true
    }

    func clearError() {
        errorMessage = nil
    }

    func cancelAccountDeletion() {
        guard !isDeletingAccount else { return }
        isDeleteConfirmationPresented = false
    }

    func confirmAccountDeletion() async {
        guard isDeleteConfirmationPresented,
              !deletionPassword.isEmpty,
              !isChangingPassword,
              !isDeletingAccount else {
            return
        }

        errorMessage = nil
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await api.executeVoid(
                .deleteAccount(
                    DeleteAccountRequest(
                        currentPassword: deletionPassword
                    )
                )
            )
            isDeleteConfirmationPresented = false
            removeDeviceSettings()
            await finishSignedOutSession()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    private var passwordValidationMessage: String? {
        if currentPassword.isEmpty {
            return "Enter your current password."
        }
        if newPassword.count < 8 {
            return "New password must be at least 8 characters."
        }
        if newPassword != confirmNewPassword {
            return "New passwords do not match."
        }
        return nil
    }

    private func userMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.userMessage
        }
        return error.localizedDescription
    }
}
