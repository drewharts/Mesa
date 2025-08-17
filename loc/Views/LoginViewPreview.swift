//
//  LoginViewPreview.swift
//  loc
//
//  Created for preview purposes only
//

import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct LoginViewPreview: View {
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea(.all)
            VStack(spacing: 32) {
                Spacer()
                
                // Google Sign In Button
                Button(action: {
                    print("Google Sign In tapped")
                }, label: {
                    Image("ios_light_sq_SI")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 45)
                })
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal, 24)
                
                // Apple Sign In Button
                SignInWithAppleButton(.signIn, onRequest: { request in
                    print("Apple Sign In request prepared")
                }, onCompletion: { result in
                    print("Apple Sign In completed")
                })
                .signInWithAppleButtonStyle(.black)
                .frame(width: 180, height: 50)
                .padding(.horizontal, 24)
                
                // Error Message (for testing)
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Test error button
                Button("Show Test Error") {
                    errorMessage = "This is a test error message to see how it looks"
                }
                .foregroundColor(.blue)
                .padding(.top, 20)
                
                Spacer()
            }
        }
    }
}

#Preview {
    LoginViewPreview()
}

#Preview("With Error") {
    LoginViewPreview()
        .onAppear {
            // Simulate error state
        }
}
