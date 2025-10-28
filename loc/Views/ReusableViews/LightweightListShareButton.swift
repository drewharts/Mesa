import SwiftUI

struct LightweightListShareButton: View {
    let lightweightList: LightweightPlaceList
    let userId: String
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    var body: some View {
        Button(action: {
            serviceContainer.placeShareService.shareLightweightList(lightweightList, userId: userId)
        }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
