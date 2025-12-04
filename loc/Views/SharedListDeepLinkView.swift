//
//  SharedListDeepLinkView.swift
//  loc
//
//  View for displaying a shared list from a deep link
//

import SwiftUI

struct SharedListDeepLinkView: View {
    let sharedListData: SharedListData
    @ObservedObject var userProfileViewModel: UserProfileViewModel
    @ObservedObject var selectedPlaceVM: SelectedPlaceViewModel
    
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentListIndex: Int
    @State private var placeColors: [String: Color] = [:]
    
    init(sharedListData: SharedListData, userProfileViewModel: UserProfileViewModel, selectedPlaceVM: SelectedPlaceViewModel) {
        self.sharedListData = sharedListData
        self.userProfileViewModel = userProfileViewModel
        self.selectedPlaceVM = selectedPlaceVM
        self._currentListIndex = State(initialValue: sharedListData.initialIndex)
    }
    
    private var currentList: PlaceList {
        sharedListData.lists[currentListIndex]
    }
    
    private var isOwnList: Bool {
        sharedListData.ownerProfile.id == userSession.currentUserId
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with owner info
                headerView
                
                // List content
                TabView(selection: $currentListIndex) {
                    ForEach(sharedListData.lists.indices, id: \.self) { index in
                        ListPlacesPopUpListView(list: sharedListData.lists[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Close button and title
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Page indicator
                if sharedListData.lists.count > 1 {
                    Text("\(currentListIndex + 1) of \(sharedListData.lists.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // List info
            VStack(spacing: 8) {
                // List emoji and name
                HStack(spacing: 8) {
                    if !currentList.emoji.isEmpty {
                        Text(currentList.emoji)
                            .font(.title)
                    }
                    
                    Text(currentList.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Owner info (only show if not own list)
                if !isOwnList {
                    HStack(spacing: 6) {
                        // Profile photo
                        if let profileImage = detailPlaceViewModel.userProfilePicture[sharedListData.ownerProfile.id] {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(sharedListData.ownerProfile.fullName.prefix(1))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        Text("by \(sharedListData.ownerProfile.fullName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        // View profile button
                        Button(action: viewOwnerProfile) {
                            Text("View Profile")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // City
                if !currentList.city.isEmpty {
                    Text(currentList.city)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Place count
                Text("\(currentList.places.count) places")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 12)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    private func viewOwnerProfile() {
        guard let currentUserId = userSession.currentUserId else { return }
        
        // Dismiss the sheet
        dismiss()
        
        // Navigate to the owner's profile
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            userProfileViewModel.selectUser(sharedListData.ownerProfile, currentUserId: currentUserId)
        }
    }
}

