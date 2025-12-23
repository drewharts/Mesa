//
//  RecentSearchesService.swift
//  loc
//
//  Single Responsibility: Persist and retrieve recent selections (places & users)
//  Staff Engineer: Pure data operations, no UI concerns
//

import Foundation

/// Unified model for recent selections (places or users)
/// Codable for UserDefaults persistence
enum RecentSelection: Codable, Identifiable, Equatable {
    case place(id: String, name: String, address: String?)
    case user(id: String, name: String, profilePhotoURL: String?)
    
    var id: String {
        switch self {
        case .place(let id, _, _): return "place_\(id)"
        case .user(let id, _, _): return "user_\(id)"
        }
    }
    
    var rawId: String {
        switch self {
        case .place(let id, _, _): return id
        case .user(let id, _, _): return id
        }
    }
    
    var displayName: String {
        switch self {
        case .place(_, let name, _): return name
        case .user(_, let name, _): return name
        }
    }
    
    var subtitle: String? {
        switch self {
        case .place(_, _, let address): return address
        case .user: return nil
        }
    }
    
    var isPlace: Bool {
        if case .place = self { return true }
        return false
    }
    
    var isUser: Bool {
        if case .user = self { return true }
        return false
    }
    
    static func == (lhs: RecentSelection, rhs: RecentSelection) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service for managing recent selections
/// Single Responsibility: Persist and retrieve recently selected places & users
final class RecentSearchesService {
    static let shared = RecentSearchesService()
    
    // MARK: - Configuration
    
    private let userDefaultsKey = "com.loc.recentSelections"
    private let maxSelections = 5
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// Retrieve recent selections from persistent storage
    func getRecentSelections() -> [RecentSelection] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let selections = try? JSONDecoder().decode([RecentSelection].self, from: data) else {
            return []
        }
        return selections
    }
    
    /// Save a selection to recent history
    /// - Deduplicates by ID (moves existing to front)
    /// - Trims to max count
    /// - Persists immediately
    func saveSelection(_ selection: RecentSelection) {
        var selections = getRecentSelections()
        
        // Remove duplicate by ID
        selections.removeAll { $0.id == selection.id }
        
        // Insert at front
        selections.insert(selection, at: 0)
        
        // Trim to max
        if selections.count > maxSelections {
            selections = Array(selections.prefix(maxSelections))
        }
        
        // Persist as JSON
        if let data = try? JSONEncoder().encode(selections) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    /// Convenience: Save a place
    func savePlace(id: String, name: String, address: String?) {
        saveSelection(.place(id: id, name: name, address: address))
    }
    
    /// Convenience: Save a user
    func saveUser(id: String, name: String, profilePhotoURL: String?) {
        saveSelection(.user(id: id, name: name, profilePhotoURL: profilePhotoURL))
    }
    
    /// Clear all recent selections
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
