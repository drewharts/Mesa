//
//  LoginView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//


import SwiftUI
import GoogleSignIn
import FirebaseAuth
import FirebaseCore

struct LoginView: View {
    @State private var errorMessage: String?
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea() // Set background color to white

            VStack(spacing: 30) {
                // App Title
                Text("Locc")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                // Error Message (if any)
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Google Sign-In Button
                Button(action: signInWithGoogle) {
                    HStack {
                        Image("google_logo") // Add your Google logo image asset to the project
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Sign in with Google")
                            .fontWeight(.medium)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1) // Add border for Google-like button
                    )
                }
                .padding(.horizontal, 50) // Adjust button padding
            }
            .padding()
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
//                    self.saveUserToFirestore(authResult?.user)
                    self.userSession.isUserLoggedIn = true
                }
            }
        }
    }
    
}
