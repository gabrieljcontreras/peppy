import SwiftUI

@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var currentUser: User?
    var activeProtocol: Protocol?
    var toast: Toast?

    func showError(_ error: APIError) {
        toast = Toast(message: error.userMessage, type: .error)
    }

    func showSuccess(_ message: String) {
        toast = Toast(message: message, type: .success)
    }

    func showInfo(_ message: String) {
        toast = Toast(message: message, type: .info)
    }

    func login(user: User) {
        currentUser = user
        isAuthenticated = true
    }

    func logout() {
        currentUser = nil
        activeProtocol = nil
        isAuthenticated = false
    }
}
