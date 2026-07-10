import Foundation

final class MockAPIClient: APIClientProtocol {
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: APIError] = [:]
    var requestLog: [Endpoint] = []
    var onRequest: ((Endpoint) async -> Void)?

    func execute<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        requestLog.append(endpoint)
        await onRequest?(endpoint)

        if let error = mockError(for: endpoint) {
            throw error
        }

        if let response = mockResponse(for: endpoint) as? T {
            return response
        }

        throw APIError.notFound
    }

    func executeVoid(_ endpoint: Endpoint) async throws {
        requestLog.append(endpoint)
        await onRequest?(endpoint)

        if let error = mockError(for: endpoint) {
            throw error
        }
    }

    func setMockResponse<T>(_ response: T, for path: String) {
        mockResponses[path] = response
    }

    func setMockResponse<T>(_ response: T, for endpoint: Endpoint) {
        mockResponses[endpoint.requestID] = response
    }

    func setMockError(_ error: APIError, for path: String) {
        mockErrors[path] = error
    }

    func setMockError(_ error: APIError, for endpoint: Endpoint) {
        mockErrors[endpoint.requestID] = error
    }

    func clearMocks() {
        mockResponses.removeAll()
        mockErrors.removeAll()
        requestLog.removeAll()
        onRequest = nil
    }

    // Method-qualified keys win; bare paths remain supported for existing tests.
    private func mockResponse(for endpoint: Endpoint) -> Any? {
        mockResponses[endpoint.requestID] ?? mockResponses[endpoint.path]
    }

    private func mockError(for endpoint: Endpoint) -> APIError? {
        mockErrors[endpoint.requestID] ?? mockErrors[endpoint.path]
    }
}
