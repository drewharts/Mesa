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
    let dataManager: DataManager?
    @State private var showAdminDebug = false
    
    init(viewModel: LoginViewModel, dataManager: DataManager? = nil) {
        self.viewModel = viewModel
        self.dataManager = dataManager
    }

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
                        .frame(height: 50)
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
                .frame(width: 210, height: 50)
                .padding(.horizontal, 24)
                
                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                
                #if DEBUG
                // Admin Debug Button (only in DEBUG builds)
                if AdminConfig.adminModeEnabled {
                    Button {
                        showAdminDebug = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Admin Login")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.bottom, 20)
                }
                #endif
            }
        }
        .sheet(isPresented: $showAdminDebug) {
            AdminDebugView(dataManager: dataManager)
                .environmentObject(userSession)
        }
    }
}

#Preview {
    LoginViewPreview()
}

// Fix for missing init in preview - add default init
extension LoginView {
    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
        self.dataManager = nil
    }
}


