import Foundation

protocol APIClientProtocol {
    func execute<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func executeVoid(_ endpoint: Endpoint) async throws
    func download(_ endpoint: Endpoint) async throws -> DownloadedFile
}

actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let keychain: KeychainServiceProtocol
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var refreshTask: Task<String, Error>?

    init(
        baseURL: URL = URL(string: "http://localhost:8000/api/v1")!,
        session: URLSession = .shared,
        keychain: KeychainServiceProtocol
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func execute<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await performRequest(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func executeVoid(_ endpoint: Endpoint) async throws {
        _ = try await performRequest(endpoint)
    }

    func download(_ endpoint: Endpoint) async throws -> DownloadedFile {
        try await performDownload(endpoint)
    }

    private func performDownload(
        _ endpoint: Endpoint,
        isRetry: Bool = false
    ) async throws -> DownloadedFile {
        var request = try buildRequest(for: endpoint)

        if endpoint.requiresAuth {
            guard let token = keychain.get(KeychainKeys.accessToken) else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (temporaryURL, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return DownloadedFile(
                url: temporaryURL,
                suggestedFilename: suggestedFilename(from: httpResponse)
            )
        case 401:
            if isRetry || !endpoint.requiresAuth {
                throw APIError.unauthorized
            }
            _ = try await refreshTokenOnce()
            return try await performDownload(endpoint, isRetry: true)
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 422:
            throw APIError.validationFailed(["Validation failed"])
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    private func performRequest(_ endpoint: Endpoint, isRetry: Bool = false) async throws -> Data {
        var request = try buildRequest(for: endpoint)

        if endpoint.requiresAuth {
            guard let token = keychain.get(KeychainKeys.accessToken) else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 401:
            if isRetry || !endpoint.requiresAuth {
                throw APIError.unauthorized
            }
            let newToken = try await refreshTokenOnce()
            var retryRequest = try buildRequest(for: endpoint)
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await session.data(for: retryRequest)
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttpResponse.statusCode) else {
                throw APIError.unauthorized
            }
            return retryData

        case 403:
            throw APIError.forbidden

        case 404:
            throw APIError.notFound

        case 409:
            if let response = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.conflict(response.errorMessage)
            }
            throw APIError.conflict("A check-in already exists for this date.")

        case 422:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.validationFailed(errorResponse.errors ?? [errorResponse.errorMessage])
            }
            throw APIError.validationFailed(["Validation failed"])

        case 500...599:
            throw APIError.serverError

        default:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.unknown(errorResponse.errorMessage)
            }
            throw APIError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    private func refreshTokenOnce() async throws -> String {
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        let task = Task<String, Error> {
            defer { refreshTask = nil }

            guard let refreshToken = keychain.get(KeychainKeys.refreshToken) else {
                throw APIError.unauthorized
            }

            let endpoint = Endpoint.refreshToken(refreshToken: refreshToken)
            var request = try buildRequest(for: endpoint)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                keychain.delete(KeychainKeys.accessToken)
                keychain.delete(KeychainKeys.refreshToken)
                throw APIError.unauthorized
            }

            let authResponse = try decoder.decode(AuthResponse.self, from: data)
            try keychain.save(authResponse.accessToken, for: KeychainKeys.accessToken)
            try keychain.save(authResponse.refreshToken, for: KeychainKeys.refreshToken)

            return authResponse.accessToken
        }

        refreshTask = task
        return try await task.value
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)!
        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw APIError.unknown("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

    private func suggestedFilename(from response: HTTPURLResponse) -> String {
        if let disposition = response.value(forHTTPHeaderField: "Content-Disposition") {
            let parameters = disposition.split(separator: ";", omittingEmptySubsequences: true)

            if let encoded = parameters.first(where: {
                $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("filename*=")
            }) {
                let value = encoded.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
                if let decoded = decodeRFC5987Filename(value),
                   let safe = safeFilename(decoded) {
                    return safe
                }
                return "peppy-export"
            }

            if let plain = parameters.first(where: {
                $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("filename=")
            }) {
                let value = plain.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
                let unquoted = value.trimmingCharacters(in: CharacterSet(charactersIn: " \t\""))
                if let safe = safeFilename(unquoted) {
                    return safe
                }
                return "peppy-export"
            }
        }

        return safeFilename(response.suggestedFilename ?? "") ?? "peppy-export"
    }

    private func decodeRFC5987Filename(_ value: String) -> String? {
        let unquoted = value.trimmingCharacters(in: CharacterSet(charactersIn: " \t\""))
        let components = unquoted.split(
            separator: "'",
            maxSplits: 2,
            omittingEmptySubsequences: false
        )
        guard components.count == 3,
              components[0].caseInsensitiveCompare("UTF-8") == .orderedSame else {
            return nil
        }
        return String(components[2]).removingPercentEncoding
    }

    private func safeFilename(_ value: String) -> String? {
        let filename = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prohibitedCharacters = CharacterSet.controlCharacters.union(
            CharacterSet(charactersIn: "/\\")
        )

        guard !filename.isEmpty,
              filename != ".",
              filename != "..",
              filename.utf8.count <= 255,
              filename.rangeOfCharacter(from: prohibitedCharacters) == nil else {
            return nil
        }
        return filename
    }
}

private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

enum KeychainKeys {
    static let accessToken = "peppy.accessToken"
    static let refreshToken = "peppy.refreshToken"
}
