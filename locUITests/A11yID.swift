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
        /// DEBUG-only email/password form, shown with launch argument -MesaUITestEmailLogin.
        static let email = "auth.email"
        static let password = "auth.password"
        static let signIn = "auth.signIn"
    }

    enum Tab {
        static let explore = "tab.explore"
        static let profile = "tab.profile"
    }

    enum Explore {
        static let city = "explore.city"
        static let list = "explore.list"
        static let featured = "explore.featured"
    }

    enum List {
        static let findTable = "list.findTable"
        static let findTableSearch = "list.findTable.search"
    }

    enum Profile {
        static let addList = "profile.lists.add"
        static let listRow = "profile.lists.row"
        static let name = "profile.name"
    }

    enum Import {
        static let googleMaps = "import.googleMaps"
        static let googleMapsURL = "import.googleMaps.url"
        static let cancel = "import.cancel"
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
