//
//  CityDetailViewModel.swift
//  loc
//
//  ViewModel for the city detail sheet showing lists and top places in a city.
//

import Foundation

@MainActor
class CityDetailViewModel: ObservableObject {
    @Published var lists: [CityDetailListRecord] = []
    @Published var topPlaces: [CityTopPlace] = []
    @Published var isLoading: Bool = false

    private let placeService = ServiceContainer.shared.placeService
    private let cityName: String

    init(cityName: String) {
        self.cityName = cityName
    }

    /// Loads lists and top places for the city.
    func loadContent(userId: String) async {
        isLoading = true

        async let listsResult = placeService.fetchCityDetailLists(userId: userId, cityName: cityName)
        async let placesResult = placeService.fetchCityTopPlaces(userId: userId, cityName: cityName)

        do {
            let (fetchedLists, fetchedPlaces) = try await (listsResult, placesResult)
            self.lists = fetchedLists
            self.topPlaces = fetchedPlaces
        } catch {
            print("❌ [CityDetailVM] Error loading city content: \(error.localizedDescription)")
        }

        isLoading = false
    }
}
