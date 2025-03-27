//
//  MainView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//


import SwiftUI
import FirebaseAuth
import MapboxMaps
import MapboxSearch

struct MainView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @StateObject private var viewModel = SearchViewModel()
    @StateObject private var userProfileViewModel = UserProfileViewModel()
    @EnvironmentObject var locationManager: LocationManager

    @FocusState private var searchIsFocused: Bool
    @State private var isSearchBarMinimized = true
    @State private var sheetHeight: CGFloat = 200
    @State private var minSheetHeight: CGFloat = 250
    @State private var maxSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.85
    @State private var showProfileView = false
    @State private var triggerFocus = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                MapView(onMapTap: {
                    searchIsFocused = false
                    isSearchBarMinimized = true
                })
                .ignoresSafeArea()
                .edgesIgnoringSafeArea(.all)

                VStack(spacing: 16) {
                    if isSearchBarMinimized {
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
                                    // Delay focus to ensure TextField is rendered
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        searchIsFocused = true
                                    }
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.blue)
                                        .frame(width: 60, height: 60)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(Color.gray, lineWidth: 2)
                                        )
                                        .shadow(radius: 4)
                                }
                                .padding(.top, 10)
                                .padding(.trailing, 20)

                                // Profile Button (unchanged)
                                NavigationLink(destination: ProfileView(), isActive: $showProfileView) {
                                    Button(action: {
                                        showProfileView = true
                                        selectedPlaceVM.isDetailSheetPresented = false
                                    }) {
                                        if let profilePhoto = userSession.profileViewModel?.profilePhoto {
                                            profilePhoto
                                                .resizable()
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle().stroke(Color.gray, lineWidth: 2)
                                                )
                                                .shadow(radius: 4)
                                        } else {
                                            Image(systemName: "person.crop.circle")
                                                .resizable()
                                                .foregroundColor(.blue)
                                                .frame(width: 60, height: 60)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle().stroke(Color.gray, lineWidth: 2)
                                                )
                                                .shadow(radius: 4)
                                        }
                                    }
                                }
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
                                    userProfileViewModel.selectUser(user, currentUserId: profileViewModel.userId)
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
                }
                .sheet(isPresented: $userProfileViewModel.isUserDetailPresented) {
                    if let user = userProfileViewModel.selectedUser {
                        UserProfileView(userId: profileViewModel.userId, viewModel: userProfileViewModel)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))

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
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .onAppear {
                locationManager.requestLocationPermission()
                viewModel.selectedPlaceVM = selectedPlaceVM
                viewModel.searchText = ""
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
