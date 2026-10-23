//
//  MesaBackendConfig.swift
//  loc
//
//  Configuration for Mesa backend connection
//

import Foundation

struct MesaBackendConfig {
    /// Production backend, used when no build setting overrides it.
    static let productionBaseURL = "https://mesa.drewharts.com"

    /// Base URL for all Mesa backend API requests.
    /// Comes from the MESA_API_BASE_URL build setting (Info.plist key MesaAPIBaseURL).
    /// App Store builds use production; the TestFlight CI workflow overrides it to staging.
    static let baseURL: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "MesaAPIBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.hasPrefix("https://") || raw.hasPrefix("http://") else { return productionBaseURL }
        return raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    }()

    /// Host used for universal links and associated domains.
    static let universalLinkHost = "mesa.drewharts.com"
}
