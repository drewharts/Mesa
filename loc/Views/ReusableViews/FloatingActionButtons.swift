import SwiftUI

struct FloatingActionButtons: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    let searchCoordinator: SearchCoordinatorViewModel
    @Binding var isSearchBarMinimized: Bool
    @Binding var sheetHeight: CGFloat
    @Binding var shouldNavigateToProfile: Bool
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    searchButton
                    profileButton
                }
                .padding(.bottom, 20)
                .padding(.trailing, 20)
            }
        }
    }
    
    private var searchButton: some View {
        Button(action: {
            // ✅ No animation for instant response
            sheetHeight = searchCoordinator.calculateCollapsedHeight(currentHeight: sheetHeight)
            isSearchBarMinimized = false
            
            // ✅ Focus handled by SearchContainerView.onChange
        }) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(radius: 4)
        }
    }
    
    private var profileButton: some View {
        Group {
            if let profilePhoto = profileViewModel.userPicture {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .shadow(radius: 4)
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .foregroundColor(.secondary)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .shadow(radius: 4)
            }
        }
        .contentShape(Circle()) // Make entire circle tappable
        .gesture(
            TapGesture()
                .onEnded { _ in
                    // Exclusive gesture - takes priority over map tap
                    shouldNavigateToProfile = true
                },
            including: .all // This gesture blocks all lower-priority gestures
        )
    }
} 