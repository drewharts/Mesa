import SwiftUI

struct UserProfileListViewJustListsPlaces: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var placeColors: [UUID: Color]

    @ObservedObject var viewModel: UserProfileViewModel
    var places: [DetailPlace]
    var body: some View {
        HStack {
            ForEach(places, id: \.id) { place in
                Button(action: {
                    selectedPlaceVM.selectPlaceAndFetchDetails(place)
                    selectedPlaceVM.isDetailSheetPresented = true
                    
                    // Dismiss the user profile sheet properly
                    viewModel.isUserDetailPresented = false
                    
                    // Also call presentationMode dismiss as backup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    VStack(spacing: 4) {
                        if let image = viewModel.placeImages[place.id.uuidString] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 85, height: 85)
                                .cornerRadius(50)
                                .clipped()
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                        .frame(width: 85, height: 85)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        } else {
                            Circle()
                                .frame(width: 85, height: 85)
                                .foregroundColor(placeColors[place.id] ?? .gray)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                        .frame(width: 85, height: 85)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                        
                        Text(place.name.prefix(15))
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(width: 85)
                        
                        if let type = detailPlaceViewModel.placeTypes[place.id.uuidString] {
                            Text(type.prefix(15))
                                .foregroundColor(.black)
                                .font(.caption)
                                .fontWeight(.light)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 85)
                        } else if let city = place.city {
                            Text(city.prefix(15))
                                .foregroundColor(.black)
                                .font(.caption)
                                .fontWeight(.light)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 85)
                        }
                    }
                    .padding(.trailing, 10)
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            for place in places {
                if placeColors[place.id] == nil {
                    placeColors[place.id] = randomColor()
                }
            }
        }
    }
    
    private func randomColor() -> Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}