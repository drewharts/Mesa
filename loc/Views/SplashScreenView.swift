//
//  SplashScreenView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI
import CoreLocation
import FirebaseAuth

struct SplashScreenView: View {
    @State private var isActive = false
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        Group {
            if isActive {
                ContentView()
                    .transition(.opacity)
            } else {
                GeometryReader { geometry in
                    Image("SplashScreen")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            let delay = userSession.isUserLoggedIn ? 0.5 : 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}
