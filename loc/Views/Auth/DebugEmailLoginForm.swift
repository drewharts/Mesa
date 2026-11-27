//
//  DebugEmailLoginForm.swift
//  loc
//
//  DEBUG-only email/password form used by UI tests (launch argument -MesaUITestEmailLogin).
//  The whole file is compiled out of Release builds, so TestFlight/App Store binaries have no
//  email sign-in path (testflight.yml also fails the archive if the launch-argument string appears).
//

#if DEBUG
import SwiftUI

struct DebugEmailLoginForm: View {
    let onSignIn: (String, String) -> Void

    @State private var email = ""
    @State private var password = ""

    /// True when the app was launched with the UI-test email login argument.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-MesaUITestEmailLogin")
    }

    var body: some View {
        VStack(spacing: 8) {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("auth.email")
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("auth.password")
            Button("Sign in (UI test)") { onSignIn(email, password) }
                .accessibilityIdentifier("auth.signIn")
        }
    }
}
#endif
