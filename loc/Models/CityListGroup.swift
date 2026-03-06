import Foundation

/// Groups lightweight place lists by their derived city for section display.
struct CityListGroup: Identifiable {
    let city: String
    let lists: [LightweightPlaceList]
    var id: String { city }
}
