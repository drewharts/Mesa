//
//  SelectedPlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//

import Foundation
import GooglePlaces

class SelectedPlaceViewModel: ObservableObject {
    @Published var selectedPlace: GMSPlace? = nil
    @Published var isDetailSheetPresented: Bool = false
}
