//
//  TableAvailabilityService.swift
//  loc
//
//  Calls POST /lists/<list_id>/availability on the Mesa backend with the user's auth token.
//  A 404/405/501 means the endpoint is not deployed or is switched off; that is remembered for the
//  session so the "Find a table" entry point can hide itself.
//

import Foundation

/// Why an availability search failed.
enum TableAvailabilityError: Error, Equatable {
    /// The backend does not offer the feature (404/405/501).
    case unavailable
    /// Any other failure (network, 5xx, malformed response).
    case failed
}

/// Abstraction over the availability call so view models can be tested without the network.
protocol TableAvailabilityFetching {
    /// Searches the list's places for open tables.
    func search(listId: String, request: TableAvailabilityRequest) async throws -> TableAvailabilityResponse
}

struct TableAvailabilityService: TableAvailabilityFetching {
    static let shared = TableAvailabilityService()

    /// Availability checks fan out to the reservation provider, so allow more time than a normal call.
    private static let requestTimeout: TimeInterval = 45
    /// Status codes meaning "this backend does not offer the feature".
    private static let unavailableStatusCodes: Set<Int> = [404, 405, 501]

    private let baseURL: String

    /// Creates the service against a backend base URL (defaults to the configured one).
    init(baseURL: String = MesaBackendConfig.baseURL) {
        self.baseURL = baseURL
    }

    /// Builds the POST request for a list's availability search; the token is optional.
    static func makeRequest(baseURL: String, listId: String, body: TableAvailabilityRequest, accessToken: String?) throws -> URLRequest {
        guard let encoded = listId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/lists/\(encoded)/availability") else {
            throw TableAvailabilityError.failed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Maps an HTTP status code to an error, or nil for success.
    static func error(forStatusCode code: Int) -> TableAvailabilityError? {
        if (200...299).contains(code) { return nil }
        return unavailableStatusCodes.contains(code) ? .unavailable : .failed
    }

    /// Searches the list's places for open tables; records an "unavailable" backend for the session.
    func search(listId: String, request body: TableAvailabilityRequest) async throws -> TableAvailabilityResponse {
        let token = try? await SupabaseAuthService.shared.getSession().accessToken
        let request = try Self.makeRequest(baseURL: baseURL, listId: listId, body: body, accessToken: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TableAvailabilityError.failed }
        if let failure = Self.error(forStatusCode: http.statusCode) {
            if failure == .unavailable { TableAvailabilityGate.markUnavailable() }
            throw failure
        }
        do {
            return try JSONDecoder().decode(TableAvailabilityResponse.self, from: data)
        } catch {
            throw TableAvailabilityError.failed
        }
    }
}

/// Session-wide memory of whether the backend offers availability search.
enum TableAvailabilityGate {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var unavailable = false

    /// True until the backend has answered "not available" once this session.
    static var isOffered: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !unavailable
    }

    /// Remembers that the backend does not offer the feature (until the app restarts).
    static func markUnavailable() {
        lock.lock()
        defer { lock.unlock() }
        unavailable = true
    }
}
