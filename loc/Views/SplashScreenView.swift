//
//  SplashScreenView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//


import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    
    var body: some View {
        if isActive {
            ContentView()
                .transition(.opacity)
        } else {
            GeometryReader { geometry in
                Image("SplashScreen") // Replace with your image name
                    .resizable()
                    .scaledToFill() // Scale to fill the entire screen, may crop edges
                    .frame(width: geometry.size.width, height: geometry.size.height) // Set to full screen size
                    .clipped() // Ensure any overflow is clipped
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}
