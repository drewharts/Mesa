import SwiftUI

struct LightweightListShareButton: View {
    let lightweightList: LightweightPlaceList
    let userId: String
    var style: ShareButtonStyle = .default
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    enum ShareButtonStyle {
        case `default`  // Original icon-only style
        case apple      // Clean Apple-style with larger tap target
    }
    
    var body: some View {
        Button(action: {
            serviceContainer.placeShareService.shareLightweightList(lightweightList, userId: userId)
        }) {
            switch style {
            case .default:
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.primary)
            case .apple:
                // Clean Apple-style share button
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44) // Apple HIG minimum tap target
                    .contentShape(Rectangle()) // Ensure full frame is tappable
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
