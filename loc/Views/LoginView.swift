//  LoginView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//

import SwiftUI
import GoogleSignIn
import FirebaseAuth
import FirebaseCore
import GoogleSignInSwift

struct LoginView: View {
    @State private var errorMessage: String?
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea() // Set background color to white

            VStack(spacing: 40) { // Stack items vertically with spacing
                // Logo at the top
                Image("LocLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150) // Adjust size as needed

                // Error Message (if any)
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Google Sign-In Button
                GoogleSignInButton(action: signInWithGoogle)
                    .frame(height: 60) // Adjust button height
                    .padding(.horizontal, 40) // Add padding for aesthetics
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // Center VStack within the screen
        }
    }



    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Missing client ID"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let rootViewController = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?.rootViewController else {
            errorMessage = "Unable to access root view controller"
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [self] result, error in
            guard error == nil else {
                self.errorMessage = error?.localizedDescription
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.errorMessage = "Failed to retrieve user credentials"
                return
            }
            
            let accessToken = user.accessToken.tokenString
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else {
                    // Set user as logged in
                    self.userSession.isUserLoggedIn = true
                }
            }
        }
    }
}
