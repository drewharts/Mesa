import SwiftUI
import MapboxSearch

struct SearchResultsView: View {
    let placeResults: [SearchSuggestion]
    let userResults: [ProfileData]
    let onSelectPlace: (SearchSuggestion) -> Void
    let onSelectUser: (ProfileData) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 10) {
                    UserResultsView(userResults: userResults, onSelectUser: onSelectUser)
                    PlaceResultsView(placeResults: placeResults, onSelectPlace: onSelectPlace)
                }
            }
            .frame(height: CGFloat((userResults.count + placeResults.count) * 120))
        }
    }
}

struct PlaceResultsView: View {
    let placeResults: [SearchSuggestion]
    let onSelectPlace: (SearchSuggestion) -> Void

    var body: some View {
        if !placeResults.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
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

                            if let secondaryText = prediction.address?.formattedAddress(style: .medium) {
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
