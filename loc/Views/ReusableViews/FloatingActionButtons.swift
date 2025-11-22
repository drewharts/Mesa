import SwiftUI

struct FloatingActionButtons: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Binding var isSearchBarMinimized: Bool
    @Binding var searchIsFocused: Bool
    @Binding var sheetHeight: CGFloat
    @Binding var shouldNavigateToProfile: Bool
    
    let maxSheetHeight: CGFloat
    let minSheetHeight: CGFloat
    
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
            // ✅ Remove animation block here - let MainView's .opacity transition handle it
            // This prevents fighting animations and layout thrashing
            if sheetHeight == maxSheetHeight {
                sheetHeight = minSheetHeight
            }
            isSearchBarMinimized = false
            
            // ✅ Focus now handled by SearchContainerView.onChange (staff engineer: single source of truth)
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