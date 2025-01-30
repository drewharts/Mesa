//
//  UserProfileListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI
import GooglePlaces

struct UserProfileListsView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var placeLists: [PlaceList]

    //slider that will show more and less lists based on distance from you
    //long press restaurants for more info
    //bring instagram photos to here
    var body: some View {
        VStack(alignment: .leading) {
            Text("LISTS")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
            
            if placeLists.isEmpty {
                Text("No lists available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            } else {
                ScrollView {
                    ForEach(placeLists) { list in
                        VStack(alignment: .leading) {
                            Text(list.name)
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.leading, 20)

                            if let places = viewModel.placeListGMSPlaces[list.id] {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(places, id: \.placeID) { place in
                                            VStack {
                                                if let image = viewModel.placeImages[place.placeID ?? ""] {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 85, height: 85)
                                                        .cornerRadius(50)
                                                        .clipped()
                                                } else {
                                                    ProgressView()
                                                        .frame(width: 85, height: 85)
                                                }

                                                Text(place.name ?? "Unknown")
                                                    .font(.footnote)
                                                    .foregroundColor(.black)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(1)
                                                    .frame(width: 85)
                                            }
                                            .padding(.trailing, 10)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            } else {
                                Text("Loading places...")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 20)
                            }
                        }
                    }
                }
            }
        }
    }
}
