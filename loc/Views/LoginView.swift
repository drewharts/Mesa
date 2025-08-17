//  LoginView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//

import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea(.all)
            VStack(spacing: 32) {
                Spacer()
                
                // Google Sign In Button
                Button(action: {
                    viewModel.signInWithGoogle(userSession: userSession)
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
                    viewModel.prepareAppleSignIn(request: request)
                }, onCompletion: { result in
                    viewModel.handleAppleSignIn(result: result, userSession: userSession)
                })
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal, 24)
                
                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
            }
        }
    }
}


