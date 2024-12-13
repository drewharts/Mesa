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
        ZStack {
            Color.white
                .ignoresSafeArea(.all)
            VStack {
                Button(action: {
                    viewModel.signInWithGoogle(userSession: userSession)
                }, label: {
                    Image("ios_light_sq_SI")
                        .resizable() // Allow resizing
                        .scaledToFit() // Maintain aspect ratio
                        .frame(width: 200, height: 200) // Adjust size as needed
                })
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
        }
    }
}

