import SwiftUI

struct SearchResultsView: View {
    let placeResults: [MesaPlaceSuggestion]
    let userResults: [ProfileData]
    let showNoPlaceFound: Bool
    let searchText: String
    let isSearching: Bool
    let onSelectPlace: (MesaPlaceSuggestion) -> Void
    let onSelectUser: (ProfileData) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 10) {
                    if isSearching {
                        // Show loading indicator
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Searching...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else {
                        UserResultsView(userResults: userResults, onSelectUser: onSelectUser)
                        PlaceResultsView(
                            placeResults: placeResults,
                            showNoPlaceFound: showNoPlaceFound,
                            searchText: searchText,
                            onSelectPlace: onSelectPlace
                        )
                    }
                }
            }
            .frame(height: isSearching ? 100 : CGFloat((userResults.count + placeResults.count) * 120 + (showNoPlaceFound ? 120 : 0)))
        }
    }
}

struct PlaceResultsView: View {
    let placeResults: [MesaPlaceSuggestion]
    let showNoPlaceFound: Bool
    let searchText: String
    let onSelectPlace: (MesaPlaceSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !placeResults.isEmpty {
                Text("Places")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                ForEach(placeResults, id: \.id) { prediction in
                    Button(action: { onSelectPlace(prediction) }) {
                        VStack(alignment: .center) {
                            Text(prediction.name)
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .center)

                            if let secondaryText = prediction.address {
                                Text(secondaryText)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
                }
            } else if showNoPlaceFound {
                Text("Places")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    VStack(spacing: 4) {
                        Text("No place found")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("We couldn't find '\(searchText)' in our database")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                .padding(.horizontal, 20)
            }
        }
    }
}

struct UserResultsView: View {
    let userResults: [ProfileData]
    let onSelectUser: (ProfileData) -> Void

    var body: some View {
        if !userResults.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text("Users")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                
                ForEach(userResults) { user in
                    Button(action: { onSelectUser(user) }) {
                        HStack {
                            // Profile Image Placeholder (Replace with actual image loading)
                            AsyncImage(url: user.profilePhotoURL) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else if phase.error != nil {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                        .foregroundColor(.gray)
                                } else {
                                    ProgressView()
                                        .frame(width: 40, height: 40)
                                }
                            }

                            
                            VStack(alignment: .leading) {
                                Text(user.fullName)
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
