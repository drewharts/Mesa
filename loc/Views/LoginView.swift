//  LoginView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//

import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 40) {
                Image("LocLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                GoogleSignInButton(action: viewModel.signInWithGoogle)
                    .frame(height: 60)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onChange(of: viewModel.isUserLoggedIn) { isLoggedIn in
            if isLoggedIn {
                userSession.profile = viewModel.profile
                userSession.isUserLoggedIn = true
                
            }
        }
    }
}
