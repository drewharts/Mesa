//
//  NetworkSessionManager.swift
//  loc
//
//  Centralized URLSession manager with proper connection pooling
//  to prevent socket exhaustion from concurrent requests.
//

import Foundation

/// Centralized URLSession manager with proper connection pooling.
class NetworkSessionManager {
    static let shared = NetworkSessionManager()

    /// Shared session for API requests (JSON).
    let apiSession: URLSession

    /// Shared session for image downloads.
    let imageSession: URLSession

    private init() {
        // API session configuration - limited connections to prevent socket exhaustion
        let apiConfig = URLSessionConfiguration.default
        apiConfig.httpMaximumConnectionsPerHost = 4
        apiConfig.timeoutIntervalForRequest = 30
        apiConfig.timeoutIntervalForResource = 60
        apiSession = URLSession(configuration: apiConfig)

        // Image session configuration - slightly more connections, shorter timeout
        let imageConfig = URLSessionConfiguration.default
        imageConfig.httpMaximumConnectionsPerHost = 6
        imageConfig.timeoutIntervalForRequest = 15
        imageConfig.timeoutIntervalForResource = 30
        imageSession = URLSession(configuration: imageConfig)
    }
}
