//  NearbyPlacesService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import Foundation

class NearbyPlacesService {
    private let baseURL = "https://mesa-backend-production.up.railway.app"
    
    func fetchNearbyPlaces(latitude: Double, longitude: Double) async throws -> NearbyPlacesResponse {
        let urlString = "\(baseURL)/nearby-places?latitude=\(latitude)&longitude=\(longitude)"
        
        guard let url = URL(string: urlString) else {
            throw NearbyPlacesError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NearbyPlacesError.invalidResponse
        }
        
        do {
            let nearbyPlacesResponse = try JSONDecoder().decode(NearbyPlacesResponse.self, from: data)
            return nearbyPlacesResponse
        } catch {
            print("❌ Decoding error: \(error)")
            throw NearbyPlacesError.decodingError(error)
        }
    }
}

enum NearbyPlacesError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for nearby places request"
        case .invalidResponse:
            return "Invalid response from nearby places API"
        case .decodingError(let error):
            return "Failed to decode nearby places response: \(error.localizedDescription)"
        }
    }
} 