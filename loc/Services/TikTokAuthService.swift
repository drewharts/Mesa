//
//  TikTokAuthService.swift
//  loc
//
//  Created by Mesa on 7/7/25.
//

import Foundation
import FirebaseAuth
import SwiftUI

struct TikTokAuthStatus: Codable {
    let connected: Bool
    let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case connected
        case expiresAt = "expires_at"
    }
}

class TikTokAuthService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isCheckingStatus: Bool = false
    @Published var expiresAt: Date?
    
    private let baseURL = "https://mesa-backend-production.up.railway.app"
    
    init() {
        Task {
            await checkConnectionStatus()
        }
    }
    
    // Check TikTok connection status
    @MainActor
    func checkConnectionStatus() async {
        isCheckingStatus = true
        defer { isCheckingStatus = false }
        
        guard let user = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else {
            isConnected = false
            return
        }
        
        guard let url = URL(string: "\(baseURL)/auth/tiktok/status") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                let status = try JSONDecoder().decode(TikTokAuthStatus.self, from: data)
                isConnected = status.connected
                
                if let expiresAtString = status.expiresAt {
                    let formatter = ISO8601DateFormatter()
                    expiresAt = formatter.date(from: expiresAtString)
                }
            } else {
                isConnected = false
            }
        } catch {
            print("Error checking TikTok status: \(error)")
            isConnected = false
        }
    }
    
    // Initiate TikTok OAuth flow
    func connectTikTok() {
        guard let url = URL(string: "\(baseURL)/auth/tiktok/login") else { return }
        
        // Open in Safari for OAuth flow
        UIApplication.shared.open(url)
    }
    
    // Disconnect TikTok account
    @MainActor
    func disconnectTikTok() async -> Bool {
        guard let user = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else {
            return false
        }
        
        guard let url = URL(string: "\(baseURL)/auth/tiktok/disconnect") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isConnected = false
                expiresAt = nil
                return true
            }
            return false
        } catch {
            print("Error disconnecting TikTok: \(error)")
            return false
        }
    }
    
    // Process URL with TikTok authentication
    func processTikTokURLWithAuth(_ urlString: String) async -> Result<TikTokProcessorResponse, Error> {
        guard let user = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else {
            return .failure(NSError(domain: "TikTokAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
        }
        
        guard let url = URL(string: "\(baseURL)/process-url-with-auth") else {
            return .failure(NSError(domain: "TikTokAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["url": urlString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    // Token expired, need to reconnect
                    isConnected = false
                    return .failure(NSError(domain: "TikTokAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "TikTok authorization expired"]))
                }
                
                if httpResponse.statusCode == 200 {
                    let decodedResponse = try JSONDecoder().decode(TikTokProcessorResponse.self, from: data)
                    return .success(decodedResponse)
                } else {
                    return .failure(NSError(domain: "TikTokAuth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"]))
                }
            }
            
            return .failure(NSError(domain: "TikTokAuth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
        } catch {
            return .failure(error)
        }
    }
}