//
//  ShareableProfile.swift
//  loc
//
//  Created by Claude Code on [current date]
//

import Foundation

struct ShareableProfile: Codable, Identifiable {
    let id: String
    let fullName: String
    let profilePhotoURL: String?

    init(from profileData: ProfileData) {
        self.id = profileData.id
        self.fullName = profileData.fullName
        self.profilePhotoURL = profileData.profilePhotoURL?.absoluteString
    }

    init(id: String, fullName: String, profilePhotoURL: String?) {
        self.id = id
        self.fullName = fullName
        self.profilePhotoURL = profilePhotoURL
    }

    var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "loc"
        components.host = "profile"
        components.path = "/\(id)"

        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: fullName))

        if let photoURL = profilePhotoURL {
            queryItems.append(URLQueryItem(name: "photoURL", value: photoURL))
        }

        components.queryItems = queryItems
        return components.url
    }

    static func from(url: URL) -> ShareableProfile? {
        guard url.scheme == "loc",
              url.host == "profile",
              !url.pathComponents.isEmpty else {
            return nil
        }

        let pathComponents = url.pathComponents
        guard pathComponents.count > 1 else { return nil }

        let userId = String(pathComponents[1])

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            // Allow parsing without query items - just need the userId
            return ShareableProfile(id: userId, fullName: "", profilePhotoURL: nil)
        }

        let name = queryItems.first(where: { $0.name == "name" })?.value ?? ""
        let photoURL = queryItems.first(where: { $0.name == "photoURL" })?.value

        return ShareableProfile(id: userId, fullName: name, profilePhotoURL: photoURL)
    }
}
