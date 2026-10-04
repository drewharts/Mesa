//
//  OnboardingStatus.swift
//  loc
//
//  Which post-login onboarding steps a user still needs to complete.
//

import Foundation

struct OnboardingStatus: Equatable {
    let needsPhone: Bool
    let needsProfilePhoto: Bool
    let needsList: Bool

    /// True when no onboarding steps remain.
    var isComplete: Bool {
        !needsPhone && !needsProfilePhoto && !needsList
    }
}
