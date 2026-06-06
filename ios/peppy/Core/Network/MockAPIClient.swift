import Foundation

final class MockAPIClient: APIClientProtocol {
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: APIError] = [:]
    var requestLog: [Endpoint] = []

    func execute<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        requestLog.append(endpoint)

        if let error = mockErrors[endpoint.path] {
            throw error
        }

        if let response = mockResponses[endpoint.path] as? T {
            return response
        }

        throw APIError.notFound
    }

    func executeVoid(_ endpoint: Endpoint) async throws {
        requestLog.append(endpoint)

        if let error = mockErrors[endpoint.path] {
            throw error
        }
    }

    func setMockResponse<T>(_ response: T, for path: String) {
        mockResponses[path] = response
    }

    func setMockError(_ error: APIError, for path: String) {
        mockErrors[path] = error
    }

    func clearMocks() {
        mockResponses.removeAll()
        mockErrors.removeAll()
        requestLog.removeAll()
    }
}
