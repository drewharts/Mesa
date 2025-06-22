import SwiftUI

struct UserProfileListViewJustLists: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var placeLists: [PlaceList]
    @State private var placeColors: [UUID: Color] = [:]
    @State private var selectedList: PlaceList?
    @State private var showingPlacesPopup = false

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(placeLists.sorted(by: { $0.sortOrder < $1.sortOrder })) { list in
                UserProfileListRow(
                    viewModel: viewModel,
                    list: list,
                    placeColors: $placeColors,
                    selectedList: $selectedList,
                    showingPlacesPopup: $showingPlacesPopup
                )
            }
        }
        .sheet(isPresented: $showingPlacesPopup) {
            if let list = selectedList {
                UserProfileListPlacesPopupView(list: list, viewModel: viewModel, placeColors: $placeColors)
            }
        }
    }
}