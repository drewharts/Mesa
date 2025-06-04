import SwiftUI

struct UserProfileListRow: View {
    @ObservedObject var viewModel: UserProfileViewModel
    let list: PlaceList
    @Binding var placeColors: [UUID: Color]
    @Binding var selectedList: PlaceList?
    @Binding var showingPlacesPopup: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                selectedList = list
                showingPlacesPopup = true
            }) {
                HStack {
                    Text(list.name)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .padding(.leading, 20)
                    Text("\(viewModel.placeListMapboxPlaces[list.id]?.count ?? 0) \(viewModel.placeListMapboxPlaces[list.id]?.count == 1 ? "place" : "places")")
                        .font(.caption)
                        .foregroundStyle(.black)
                }
            }

            if let places = viewModel.placeListMapboxPlaces[list.id] {
                ScrollView(.horizontal, showsIndicators: false) {
                    UserProfileListViewJustListsPlaces(placeColors: $placeColors, viewModel: viewModel, places: places)
                }
            } else {
                Text("Loading places...")
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }
        }
    }
}