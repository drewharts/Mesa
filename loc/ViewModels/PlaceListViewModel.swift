//
//  PlaceListViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import Foundation
import UIKit
import FirebaseStorage
import Combine

class PlaceListViewModel: ObservableObject, Identifiable {
    @Published var placeList: PlaceList
    @Published var placeViewModels: [PlaceViewModel] = []
    
    private let placeService: PlaceService
    private let imageService: ImageService
    private let userId: String
    @Published var image: UIImage?
    private var cancellables = Set<AnyCancellable>()


    init(placeList: PlaceList, placeService: PlaceService, imageService: ImageService, userId: String) {
        self.placeList = placeList
        self.placeService = placeService
        self.imageService = imageService
        self.userId = userId
        // Initialize placeViewModels directly from the provided placeList
        self.placeViewModels = placeList.places.map { place in
            PlaceViewModel(place: place)
        }
        loadImage()
    }
    
    func getImage() -> UIImage? {
        return image
    }

    // Load the place lists from Firestore.
    func loadPlaceLists() {
        print("📋 Loading place list: \(placeList.name) for user: \(userId)")
        placeService.fetchList(userId: userId, listName: placeList.name) { [weak self] result in
            switch result {
            case .success(let fetchedPlaceList):
                print("✅ Successfully loaded list: \(fetchedPlaceList.name) with \(fetchedPlaceList.places.count) places")
                DispatchQueue.main.async {
                    self?.placeList = fetchedPlaceList
                    self?.placeViewModels = fetchedPlaceList.places.map { place in
                        PlaceViewModel(place: place)
                    }
                }
            case .failure(let error):
                print("❌ Failed to load list: \(self?.placeList.name ?? "unknown") - Error: \(error.localizedDescription)")
            }
        }
    }


    
    func loadImage() {
        guard let imageURLString = placeList.image,
              let imageURL = URL(string: imageURLString) else {
            self.image = nil
            return
        }
        
        fetchImage(from: imageURL) { [weak self] fetchedImage in
            self?.image = fetchedImage
        }
    }

    private func fetchImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                print("Failed to fetch image: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }

    func addPhotoToList(image: UIImage) {
        self.image = image // Set the image in the view model

        // Upload image to Firestore
        imageService.uploadImageAndUpdatePlaceList(userId: userId, placeList: placeList, image: image) { [weak self] error in
            if let error = error {
                print("Error adding photo to list: \(error.localizedDescription)")
                // Handle error (e.g., display an error message to the user)
            } else {
                print("Photo added to list successfully")
                self?.loadPlaceLists() // Reload the list to get the new image URL
            }
        }
    }
}

extension String {
    func toImage() -> UIImage? {
        if let data = Data(base64Encoded: self, options: .ignoreUnknownCharacters){
            return UIImage(data: data)
        }
        return nil
    }
}
