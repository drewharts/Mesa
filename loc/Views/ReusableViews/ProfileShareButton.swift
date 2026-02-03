//
//  ProfileShareButton.swift
//  loc
//
//  Created by Claude Code on [current date]
//

import SwiftUI

struct ProfileShareButton: View {
    let userId: String
    let fullName: String
    let profilePhotoURL: String?
    var style: ProfileShareButtonStyle = .default
    @EnvironmentObject private var serviceContainer: ServiceContainer

    enum ProfileShareButtonStyle {
        case `default`
        case toolbar
    }

    var body: some View {
        Button(action: {
            serviceContainer.placeShareService.shareProfile(
                userId: userId,
                fullName: fullName,
                profilePhotoURL: profilePhotoURL
            )
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(style == .toolbar ? .body : .title2)
                .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
