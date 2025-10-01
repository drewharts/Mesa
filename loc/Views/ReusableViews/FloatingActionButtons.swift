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
                .foregroundColor(.secondary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(radius: 4)
        }
    }
    
    private var profileButton: some View {
        Button(action: {
            shouldNavigateToProfile = true
        }) {
            if let profilePhoto = profileViewModel.userPicture {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .shadow(radius: 4)
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .shadow(radius: 4)
            }
        }
    }
} 