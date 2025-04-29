import SwiftUI
import UIKit

struct MinPlaceDetailView: View {
    @ObservedObject var viewModel: PlaceDetailViewModel
    @Binding var showNoPhoneNumberAlert: Bool
    @Binding var selectedImage: UIImage?
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Place name and type
            HStack {
                Text(viewModel.placeName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let type = viewModel.placeType {
                    Text(type)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            // Opening hours
            if let hours = viewModel.openingHours {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hours")
                        .font(.headline)
                    
                    ForEach(hours, id: \.self) { hour in
                        Text(hour)
                            .font(.subheadline)
                    }
                }
            }
            
            // Phone number
            if !viewModel.phoneNumber.isEmpty {
                Button(action: {
                    if let url = URL(string: "tel:\(viewModel.phoneNumber)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text(viewModel.phoneNumber)
                    }
                    .foregroundColor(.blue)
                }
            } else {
                Button(action: {
                    showNoPhoneNumberAlert = true
                }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("No phone number available")
                    }
                    .foregroundColor(.gray)
                }
            }
            
            // Travel time
            Text("Travel time: \(viewModel.travelTime)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Photos
            if !viewModel.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.photos, id: \.self) { photo in
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedImage = photo
                                }
                        }
                    }
                }
            }
        }
        .padding()
    }
} 