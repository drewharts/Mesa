//
//  LoginView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//


import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false

    // Assuming `isUserLoggedIn` is an environment object that manages the login status
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Your App")
                .font(.largeTitle)
                .padding(.top, 60)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
            
            if isLoading {
                ProgressView()
                    .padding()
            } else {
                Button("Login") {
                    loginUser()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Create Account") {
                    registerUser()
                }
                .padding()
                .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Authentication Functions
    private func loginUser() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in both fields"
            return
        }

        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                userSession.isUserLoggedIn = true
            }
        }
    }

    private func registerUser() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in both fields"
            return
        }

        isLoading = true
        errorMessage = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                userSession.isUserLoggedIn = true
            }
        }
    }
}
