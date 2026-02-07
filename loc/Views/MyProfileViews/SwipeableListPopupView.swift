//
//  SwipeableListPopupView.swift
//  loc
//
//  Created by Claude Code on 1/9/25.
//

import SwiftUI

struct SwipeableListPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    @ObservedObject var listsVM: ProfileListsViewModel
    @ObservedObject var reviewsVM: ProfileReviewsViewModel

    @StateObject private var viewModel: SwipeableListPopupViewModel
    @Binding var placeColors: [UUID: Color]

    private let lists: [PlaceList]
    private let initialListIndex: Int

    init(lists: [PlaceList], initialListIndex: Int, placeColors: Binding<[UUID: Color]>, listsVM: ProfileListsViewModel, reviewsVM: ProfileReviewsViewModel) {
        self.lists = lists
        self.initialListIndex = initialListIndex
        self._placeColors = placeColors
        self.listsVM = listsVM
        self.reviewsVM = reviewsVM
        self._viewModel = StateObject(wrappedValue: SwipeableListPopupViewModel(
            lists: lists,
            initialListIndex: initialListIndex
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SwipeableListPopupHeaderView(
                    list: viewModel.currentList,
                    currentIndex: viewModel.currentListIndex,
                    totalLists: viewModel.lists.count,
                    onDelete: { viewModel.showDeleteConfirmation() }
                )
                
                TabView(selection: $viewModel.currentListIndex) {
                    ForEach(viewModel.lists.indices, id: \.self) { index in
                        ListPlacesPopUpListView(list: viewModel.lists[index], listsVM: listsVM, reviewsVM: reviewsVM)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: viewModel.currentListIndex) { _, _ in
                    viewModel.onListIndexChanged()
                    viewModel.generateColorsForCurrentList(
                        placeColors: &placeColors,
                        profileViewModel: profile,
                        detailPlaceViewModel: detailPlaceViewModel
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.generateColorsForCurrentList(
                placeColors: &placeColors,
                profileViewModel: profile,
                detailPlaceViewModel: detailPlaceViewModel
            )
        }
        .alert("Delete List", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let shouldClose = viewModel.deleteCurrentList(profileViewModel: profile)
                if shouldClose {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(viewModel.currentList.name)'? This action cannot be undone.")
        }
    }
}

struct SwipeableListPopupHeaderView: View {
    let list: PlaceList
    let currentIndex: Int
    let totalLists: Int
    let onDelete: () -> Void
    
    @EnvironmentObject private var profile: ProfileViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Top bar with delete button and share button
            HStack {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if let userId = profile.user?.id {
                    ListShareButton(placeList: list, userId: userId)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // List name and simple counter
            VStack(spacing: 4) {
                Text(list.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                if totalLists > 1 {
                    Text("\(currentIndex + 1) of \(totalLists)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemBackground))
    }
}

