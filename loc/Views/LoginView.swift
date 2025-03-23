//  LoginView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//

import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea(.all)
            VStack {
                Button(action: {
                    viewModel.signInWithGoogle(userSession: userSession)
                }, label: {
                    Image("ios_light_sq_SI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                })
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
    }
}


