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
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        if isActive, 
           (userSession.profileViewModel?.isLoading == false || !userSession.isUserLoggedIn),
           locationManager.currentLocation != nil {
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
            .onAppear {
                // Start the transition check
                startTransitionCheck()
            }
        }
    }
    
    private func startTransitionCheck() {
        // Check periodically if conditions are met to transition
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if (userSession.profileViewModel?.isLoading == false || !userSession.isUserLoggedIn),
               locationManager.currentLocation != nil {
                withAnimation {
                    self.isActive = true
                }
                timer.invalidate()
            }
        }
    }
}
