import SwiftUI

struct LightweightListShareButton: View {
    let lightweightList: LightweightPlaceList
    let userId: String
    var style: ShareButtonStyle = .default
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    enum ShareButtonStyle {
        case `default`  // Original icon-only style
        case circular   // Matches avatar aesthetic (24px circle with white border)
    }
    
    private let circularSize: CGFloat = 24
    
    var body: some View {
        Button(action: {
            serviceContainer.placeShareService.shareLightweightList(lightweightList, userId: userId)
        }) {
            switch style {
            case .default:
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.primary)
            case .circular:
                Circle()
                    .fill(Color.black)
                    .frame(width: circularSize, height: circularSize)
                    .overlay(
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
