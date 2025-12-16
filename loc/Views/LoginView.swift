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
    @State private var showContent = false
    
    // MARK: - Brand Colors
    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)
    private let mesaCream = Color(red: 245/255, green: 240/255, blue: 227/255)
    private let cardBackground = Color(red: 248/255, green: 248/255, blue: 250/255)
    private let subtleGray = Color(red: 200/255, green: 200/255, blue: 205/255)
    
    var body: some View {
        ZStack {
            // Soft gradient background
            LinearGradient(
                colors: [
                    Color(red: 200/255, green: 200/255, blue: 210/255),
                    Color(red: 180/255, green: 180/255, blue: 195/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Floating card
            VStack(spacing: 0) {
                Spacer()
                
                loginCard
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Login Card
    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Logo
            logoSection
            
            // Title and subtitle
            titleSection
            
            // Sign in buttons
            buttonsSection
            
            // Error message
            errorSection
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 40)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 30, x: 0, y: 10)
        )
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        Image("MesaLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: mesaCharcoal.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Get Started")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(mesaCharcoal)
            
            Text("Discover and save the best places,\nshared by people you trust.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .lineSpacing(2)
        }
    }
    
    // MARK: - Buttons Section
    private var buttonsSection: some View {
        VStack(spacing: 12) {
            // Apple Sign In Button
            SignInWithAppleButton(.continue, onRequest: { request in
                viewModel.prepareAppleSignIn(request: request)
            }, onCompletion: { result in
                viewModel.handleAppleSignIn(result: result, userSession: userSession)
            })
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(Capsule())
            
            // Google Sign In Button
            Button(action: {
                viewModel.signInWithGoogle(userSession: userSession)
            }) {
                HStack(spacing: 12) {
                    GoogleLogoView()
                        .frame(width: 20, height: 20)
                    
                    Text("Continue with Google")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(mesaCharcoal)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    Capsule()
                        .stroke(subtleGray.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Error Section
    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.top, 4)
        }
    }
}

#Preview {
    LoginViewPreview()
}
