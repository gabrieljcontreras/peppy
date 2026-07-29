import Foundation

enum APIError: Error, Equatable {
    case unauthorized
    case forbidden
    case paymentRequired
    case notFound
    case conflict(String)
    case validationFailed([String])
    case serverError
    case networkUnavailable
    case decodingFailed
    case unknown(String)

    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Session expired. Please log in again."
        case .forbidden:
            return "You don't have permission to do that."
        case .paymentRequired:
            return "Peppy Premium is required for this."
        case .notFound:
            return "The requested item was not found."
        case .conflict(let message):
            return message
        case .validationFailed(let messages):
            return messages.joined(separator: "\n")
        case .serverError:
            return "Something went wrong. Please try again."
        case .networkUnavailable:
            return "No internet connection."
        case .decodingFailed:
            return "Failed to process server response."
        case .unknown(let message):
            return message.isEmpty ? "An unexpected error occurred." : message
        }
    }

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.paymentRequired, .paymentRequired),
             (.notFound, .notFound),
             (.serverError, .serverError),
             (.networkUnavailable, .networkUnavailable),
             (.decodingFailed, .decodingFailed):
            return true
        case (.validationFailed(let a), .validationFailed(let b)):
            return a == b
        case (.conflict(let a), .conflict(let b)):
            return a == b
        case (.unknown(let a), .unknown(let b)):
            return a == b
        default:
            return false
        }
    }
}

struct APIErrorResponse: Decodable {
    let detail: String?
    let message: String?
    let errors: [String]?

    var errorMessage: String {
        if let errors = errors, !errors.isEmpty {
            return errors.joined(separator: "\n")
        }
        return detail ?? message ?? "Unknown error"
    }
}
