//
//  ProfileDataLoadingState.swift
//  loc
//
//  Extracted from ProfileViewModel.swift.
//

import Foundation

/// Loading state for profile data sections.
enum ProfileDataLoadingState {
    case idle
    case loading
    case loaded
    case error
}
