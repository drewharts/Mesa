//
//  MainView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//


import SwiftUI
import FirebaseAuth
import MapboxSearch

struct MainView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var viewModel: SearchViewModel
    @EnvironmentObject var placeTypeFilterVM: PlaceTypeFilterViewModel

    @FocusState private var searchIsFocused: Bool
    @State private var isSearchBarMinimized = true
    @State private var sheetHeight: CGFloat = 200
    @State private var minSheetHeight: CGFloat = 250
    @State private var maxSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.85
    @State private var shouldNavigateToProfile = false
    @State private var triggerFocus = false
    @State private var recenterMap = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Map layer
                MapView(recenterMap: $recenterMap, onMapTap: handleMapTap)
                .ignoresSafeArea()
                .edgesIgnoringSafeArea(.all)
                
                // UI overlay layer
                VStack(spacing: 16) {
                    if isSearchBarMinimized {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                Button(action: {
                                    recenterMap = true
                                }) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .padding(.top, 10)
                                .padding(.trailing, 20)
                            }
                        }
                    } else {
                        TextField("Search here...", text: $viewModel.searchText)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .foregroundStyle(Color.gray)
                            .focused($searchIsFocused)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, -10)
                            .onChange(of: viewModel.searchText) { oldValue, newValue in
                                Task { @MainActor in
                                    placeTypeFilterVM.filterBySearchText(newValue)
                                }
                            }
                        
                        // Place type filter buttons
                        if !placeTypeFilterVM.mostFrequentTypes.isEmpty {
                            PlaceTypeFilterButtonsView(filterVM: placeTypeFilterVM)
                                .padding(.top, 10)
                        }
                        
                        if !viewModel.searchResults.isEmpty || !viewModel.userResults.isEmpty {
                            SearchResultsView(
                                placeResults: viewModel.searchResults,
                                userResults: viewModel.userResults,
                                onSelectPlace: { prediction in
                                    viewModel.selectSuggestion(prediction)
                                    withAnimation {
                                        isSearchBarMinimized = true
                                        searchIsFocused = false
                                    }
                                },
                                onSelectUser: { user in
                                    guard let currentUserId = userSession.currentUserId else { return }
                                    userProfileViewModel.selectUser(user, currentUserId: currentUserId)
                                    withAnimation {
                                        isSearchBarMinimized = true
                                        searchIsFocused = false
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 50)
                        }
                    }
                    Spacer()
                }
                .navigationBarHidden(true)
                
                if selectedPlaceVM.isDetailSheetPresented {
                    BottomSheetView(
                        isPresented: $selectedPlaceVM.isDetailSheetPresented,
                        sheetHeight: $sheetHeight,
                        maxSheetHeight: maxSheetHeight
                    ) {
                        PlaceDetailView(
                            sheetHeight: $sheetHeight,
                            minSheetHeight: minSheetHeight
                        )
                        .environmentObject(userProfileViewModel)
                        .environmentObject(notificationManager)
                        .frame(maxWidth: .infinity)
                    }
                }

                // Overlay profile and search buttons (bottom right)
                if isSearchBarMinimized && !searchIsFocused && !selectedPlaceVM.isDetailSheetPresented {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                Button(action: {
                                    withAnimation {
                                        if sheetHeight == maxSheetHeight {
                                            sheetHeight = minSheetHeight
                                        }
                                        isSearchBarMinimized.toggle()
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        searchIsFocused = true
                                    }
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.blue)
                                        .frame(width: 60, height: 60)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                        .shadow(radius: 4)
                                }
                                
                                Button(action: {
                                    shouldNavigateToProfile = true
                                    selectedPlaceVM.isDetailSheetPresented = false
                                }) {
                                    if let profilePhoto = profileViewModel.userPicture {
                                        Image(uiImage: profilePhoto)
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                            .shadow(radius: 4)
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .foregroundColor(.blue)
                                            .frame(width: 60, height: 60)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                            .shadow(radius: 4)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                            .padding(.trailing, 20)
                        }
                    }
                }
            }
            .sheet(isPresented: $userProfileViewModel.isUserDetailPresented) {
                if let currentUserId = userSession.currentUserId {
                    UserProfileView(userId: currentUserId, UserProfileVM: userProfileViewModel)
                }
            }
            .navigationDestination(isPresented: $shouldNavigateToProfile) {
                ProfileView()
                    .environmentObject(userProfileViewModel)
            }
        }
        .onAppear {
            locationManager.requestLocationPermission()
            viewModel.selectedPlaceVM = selectedPlaceVM
            viewModel.placeTypeFilterVM = placeTypeFilterVM
            viewModel.searchText = ""
            
            // Trigger immediate calculation of most frequent types
            placeTypeFilterVM.refreshMostFrequentTypes()
        }
        .onChange(of: selectedPlaceVM.isDetailSheetPresented) { _, newValue in
            if newValue {
                isSearchBarMinimized = true
                searchIsFocused = false
            }
        }
        .onChange(of: profileViewModel.userFavorites) {
            // Recalculate filters when user favorites change
            placeTypeFilterVM.refreshMostFrequentTypes()
        }
        .onChange(of: profileViewModel.userListsPlaces) {
            // Recalculate filters when user lists change
            placeTypeFilterVM.refreshMostFrequentTypes()
        }
    }

    private func handleMapTap() {
        withAnimation {
            searchIsFocused = false
            viewModel.searchResults = []
            isSearchBarMinimized = true
            viewModel.searchText = ""
        }
    }
}
