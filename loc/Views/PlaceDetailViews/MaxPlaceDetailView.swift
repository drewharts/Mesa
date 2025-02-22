//
//  MaxPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/10/25.
//

import SwiftUI
import GooglePlaces

struct MaxPlaceDetailView: View {
    @ObservedObject var viewModel: PlaceDetailViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    // Accept the same binding
    @Binding var selectedImage: UIImage?
    
    // 1) A state to track when we have no phone number
    @Binding var showNoPhoneNumberAlert: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 15) {
                // CALL Bubble
                Button(action: {
                    // Check if phoneNumber is non-nil and not empty
                    if let phoneNumber = selectedPlaceVM.selectedPlace?.phone,
                       !phoneNumber.isEmpty,
                       let url = URL(string: "tel://\(phoneNumber)") {
                        UIApplication.shared.open(url)
                    } else {
                        showNoPhoneNumberAlert = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone")
                            .font(.subheadline)
                            .foregroundColor(.black)
                        Text("CALL")
                            .font(.subheadline)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
                }


                // MENU Bubble
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle")
                        .font(.subheadline)
                        .foregroundColor(.black)
                    Text("MENU")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Divider()
                .padding(.top, 15)
                .padding(.bottom, 15)
            
            Text("PHOTOS")
                .font(.subheadline)
                .foregroundColor(.black)
                .fontWeight(.semibold)
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.photos.isEmpty {
                        GridView(images: viewModel.photos,
                                 selectedImage: $selectedImage)
                    } else {
                        ProgressView("Loading Photos...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}
