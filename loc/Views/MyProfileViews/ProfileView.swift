//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var placeVM: DetailPlaceViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Picture
                ProfilePictureView()

                // Name
                let firstName = profile.data.firstName
                let lastName = profile.data.lastName
                Text("\(firstName) \(lastName)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                HStack(spacing: 50) {
                    VStack {
                        Text("\(profile.followers)")
                            .foregroundStyle(.black)
                        Text("Followers")
                            .foregroundStyle(.black)
                            .font(.footnote)
                            .fontWeight(.light)
                    }
                    VStack {
                        Text("\(profile.following)")
                            .foregroundStyle(.black)
                        Text("Following")
                            .foregroundStyle(.black)
                            .font(.footnote)
                            .fontWeight(.light)
                    }
                }

                Divider()
                    .padding(.top, 15)
                    .padding(.horizontal, 20)
                
                // Favorites & Lists
                ProfileFavoriteListView()
                ProfileViewListsView()

                // Logout Button
                Button(action: {
                    userSession.logout()
                }) {
                    Text("Log Out")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
            .padding(.top, 10)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left") // Custom back icon
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.black)
                        Text("Back") // Optional: Add text next to the icon
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

//#if DEBUG
//struct ProfileView_Previews: PreviewProvider {
//    static var previews: some View {
//        // Mock dependencies
//        let mockLocationManager = LocationManager()
//        let mockFirestoreService = FirestoreService()
//        // Mock ProfileData
//        let profileData = ProfileData(
//            id: "kKEEK3Snx4Yirp7jIi9FMyzEUWF2",
//            firstName: "Drew",
//            lastName: "Hartsfield",
//            email: "drewharts8@gmail.com",
//            profilePhotoURL: URL(string: "https://lh3.googleusercontent.com/a/ACg8ocIRjc_nBuuY7tyQTXTDfuvvkhLNjKHnWiyyjRR0jMUxdjeLeTIJ=s200"),
//            phoneNumber: "123-456-7890",
//            fullName: "Drew Hartsfield"  // Computed or manually set
//        )
//        let detailPlaceVM = DetailPlaceViewModel(firestoreService: mockFirestoreService)
//        // Mock ProfileViewModel
//        let profileVM = ProfileViewModel(
//            data: profileData,
//            firestoreService: mockFirestoreService,
//            detailPlaceViewModel: detailPlaceVM,
//            userId: "kKEEK3Snx4Yirp7jIi9FMyzEUWF2"
//        )
////        profileVM.followers = 42
//        
//        // Mock UserSession
//        let userSession = UserSession(firestoreService: mockFirestoreService)
//        
//        // Mock SelectedPlaceViewModel
//        let selectedPlaceVM = SelectedPlaceViewModel(locationManager: mockLocationManager, firestoreService: mockFirestoreService)
//
//        // Wrap in NavigationView for toolbar to work
//        NavigationView {
//            ProfileView()
//                .environmentObject(userSession)
//                .environmentObject(selectedPlaceVM)
//                .environmentObject(profileVM)
//        }
//    }
//}
//#endif
