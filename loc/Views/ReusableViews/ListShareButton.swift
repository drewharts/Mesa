import SwiftUI

struct ListShareButton: View {
    let placeList: PlaceList
    let userId: String
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    var body: some View {
        Button(action: {
            serviceContainer.placeShareService.shareList(placeList, userId: userId)
        }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 