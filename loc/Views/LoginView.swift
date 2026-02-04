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
    @State private var showSheet = false
    
    // MARK: - Brand Colors
    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)
    private let mesaCream = Color(red: 245/255, green: 240/255, blue: 227/255)
    private let cardBackground = Color(red: 248/255, green: 248/255, blue: 250/255)
    private let subtleGray = Color(red: 200/255, green: 200/255, blue: 205/255)
    
    var body: some View {
        ZStack {
            // Splash screen background
            mesaCharcoal
                .ignoresSafeArea()
            
            // Mesa logo centered
            Image("LoginImage")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Bottom sheet
            VStack {
                Spacer()
                
                loginSheet
                    .offset(y: showSheet ? 0 : 400)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                showSheet = true
            }
        }
    }
    
    // MARK: - Login Sheet
    private var loginSheet: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Drag indicator
            dragIndicator
            
            // Title and subtitle
            titleSection
            
            // Sign in buttons
            buttonsSection
            
            // Error message
            errorSection
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 50)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(cardBackground)
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: -10)
        )
    }
    
    // MARK: - Drag Indicator
    private var dragIndicator: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(subtleGray)
                .frame(width: 40, height: 5)
            Spacer()
        }
        .padding(.bottom, 8)
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
                        .font(.system(size: 19, weight: .medium))
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
