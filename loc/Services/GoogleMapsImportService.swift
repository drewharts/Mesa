//
//  GoogleMapsImportService.swift
//  loc
//
//  Service: Calls the Google Maps list import backend endpoint
//  Single Responsibility: Network request and response decoding for /maps/import-list
//

import Foundation

class GoogleMapsImportService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Calls the backend to extract and resolve places from a shared Google Maps list URL.
    func importList(url: String) async throws -> GoogleMapsImportResult {
        guard let requestURL = URL(string: "\(MesaBackendConfig.baseURL)/maps/import-list") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body = ["url": url]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorBody["error"] {
                throw GoogleMapsImportError.serverError(errorMessage)
            }
            throw GoogleMapsImportError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GoogleMapsImportResult.self, from: data)
    }

    // MARK: - Two-Phase Import

    /// Extracts place names and coordinates from a Google Maps list URL without resolving them (Phase 1).
    func extractList(url: String) async throws -> GoogleMapsExtractResult {
        guard let requestURL = URL(string: "\(MesaBackendConfig.baseURL)/maps/extract-list") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body = ["url": url]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorBody["error"] {
                throw GoogleMapsImportError.serverError(errorMessage)
            }
            throw GoogleMapsImportError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GoogleMapsExtractResult.self, from: data)
    }

    /// Resolves a single extracted place via Serper to get full place details (Phase 2).
    func resolvePlace(name: String?, latitude: Double, longitude: Double) async throws -> GoogleMapsResolveResult {
        guard let requestURL = URL(string: "\(MesaBackendConfig.baseURL)/maps/resolve-place") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any?] = [
            "name": name,
            "latitude": latitude,
            "longitude": longitude
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorBody["error"] {
                throw GoogleMapsImportError.serverError(errorMessage)
            }
            throw GoogleMapsImportError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GoogleMapsResolveResult.self, from: data)
    }
}

/// Errors specific to Google Maps import operations.
enum GoogleMapsImportError: LocalizedError {
    case serverError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .httpError(let code):
            return "Server returned status code \(code)"
        }
    }
}
