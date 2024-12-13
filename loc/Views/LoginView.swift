//  LoginView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//

import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject var viewModel = LoginViewModel()

    var body: some View {
        VStack {
            Button("Sign in with Google") {
                viewModel.signInWithGoogle(userSession: userSession)
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
        }
    }
}

