import SwiftUI
import GoogleSignIn
import Firebase

struct GoogleSignInView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            Text("Sign in with Google")
                .font(.title)
                .padding(.bottom, 20)
            
            Button(action: {
                signInWithGoogle()
            }) {
                HStack {
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                    Text("Sign in with Google")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
        }
        .padding()
    }
    
    // MARK: - Google Sign-In Method
    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Failed to retrieve clientID"
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Start sign-in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: UIApplication.shared.windows.first?.rootViewController) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                errorMessage = "Failed to get user information"
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)

            // Authenticate with Firebase
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }

                // Update user session
                userSession.isUserLoggedIn = true
            }
        }
    }
}

