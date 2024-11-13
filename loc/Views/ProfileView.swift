//
//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI

struct ProfileView: View {
    let profile: Profile

    var body: some View {
        VStack(spacing: 20) {
            // Profile Photo
            if let profilePhoto = profile.profilePhoto {
                profilePhoto
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .padding(.top, 40)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.top, 40)
            }
            
            // Name
            Text("\(profile.firstName) \(profile.lastName)")
                .font(.title)
                .fontWeight(.bold)
            
            // Phone Number
            Text(profile.phoneNumber)
                .foregroundColor(.gray)
                .font(.subheadline)
            
            Divider().padding(.horizontal, 40)
            
            // Place Lists
            VStack(alignment: .leading, spacing: 10) {
                Text("Place Lists")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if profile.placeLists.isEmpty {
                    Text("No place lists available")
                        .foregroundColor(.gray)
                        .font(.body)
                } else {
                    ForEach(profile.placeLists, id: \.name) { placeList in
                        HStack {
                            Text(placeList.name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(placeList.places.count) places")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        Divider()
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
}
