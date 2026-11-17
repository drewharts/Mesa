//
//  AppUpdateGate.swift
//  loc
//
//  Server-driven minimum app version. The backend's GET /app/config returns
//  {"min_ios_version": "5.03"}; when the installed version is lower, the app
//  shows a blocking "Update Mesa" screen. Fails open: any network or parsing
//  problem leaves the app usable.
//

import SwiftUI

@MainActor
final class AppUpdateGate: ObservableObject {
    static let shared = AppUpdateGate()

    @Published private(set) var updateRequired = false

    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6740463252")!

    private var lastCheck: Date?

    func check() async {
        if let last = lastCheck, Date().timeIntervalSince(last) < 60 { return }
        lastCheck = Date()
        guard let url = URL(string: MesaBackendConfig.baseURL + "/app/config") else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = "GET"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let minVersion = json["min_ios_version"] as? String else { return }
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            updateRequired = Self.isVersion(current, lowerThan: minVersion)
        } catch {
            // Fail open.
        }
    }

    /// Mesa versions are decimal-style ("4.99" < "5.0" < "5.01" < "5.03"), so two-part
    /// versions compare as decimals. Anything else compares component by component.
    nonisolated static func isVersion(_ current: String, lowerThan minimum: String) -> Bool {
        let a = current.trimmingCharacters(in: .whitespaces)
        let b = minimum.trimmingCharacters(in: .whitespaces)
        guard !a.isEmpty, !b.isEmpty else { return false }
        let twoPart: (String) -> Bool = { $0.split(separator: ".").count <= 2 }
        if twoPart(a), twoPart(b),
           let da = Decimal(string: a, locale: Locale(identifier: "en_US_POSIX")),
           let db = Decimal(string: b, locale: Locale(identifier: "en_US_POSIX")) {
            return da < db
        }
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y }
        }
        return false
    }
}

struct UpdateRequiredView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.app")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(.primary)
                Text("Update Mesa")
                    .font(.title2.weight(.semibold))
                Text("This version of Mesa is no longer supported. Update to keep using your lists and places.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    openURL(AppUpdateGate.appStoreURL)
                } label: {
                    Text("Update")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
        }
    }
}
