//
//  A11yID.swift
//  locUITests
//
//  Single source of truth for accessibility identifiers used by UI tests.
//  Naming scheme: `area.element`. Identifiers are set in the app with `.accessibilityIdentifier(...)`.
//  Where an identifier may not exist yet in app code, tests fall back to visible labels (see `Label`).
//

import Foundation

enum A11yID {
    enum Auth {
        static let title = "auth.title"
        static let signInApple = "auth.signInApple"
        static let signInGoogle = "auth.signInGoogle"
        /// Optional email/password fields; the shipping app has none, so signed-in tests skip without them.
        static let email = "auth.email"
        static let password = "auth.password"
        static let signIn = "auth.signIn"
    }

    enum Tab {
        static let explore = "tab.explore"
        static let profile = "tab.profile"
    }

    enum List {
        static let findTable = "list.findTable"
    }

    enum Profile {
        static let addList = "profile.lists.add"
    }

    enum Import {
        static let googleMaps = "import.googleMaps"
    }

    /// Visible-label fallbacks for elements whose identifiers may not be in the app yet.
    enum Label {
        static let signedOutTitle = "Get Started"
        static let continueWithGoogle = "Continue with Google"
        static let explore = "Explore"
        static let profile = "Profile"
        static let findTable = "Find a table"
        static let importGoogleMaps = "Import from Google Maps"
    }
}
