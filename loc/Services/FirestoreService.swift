//
//  FirestoreService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/6/24.
//


import FirebaseFirestore
import GooglePlaces

class FirestoreService {
    private let db = Firestore.firestore()

    func addPlaceToList(userId: String, listName: String, place: GMSPlace) {
        let placeData: [String: Any] = [
            "placeID": place.placeID ?? "",
            "name": place.name ?? "",
            "address": place.formattedAddress ?? ""
        ]

        db.collection("users").document(userId)
            .collection("placeLists").document(listName)
            .setData(["places": FieldValue.arrayUnion([placeData])], merge: true) { error in
                if let error = error {
                    print("Error adding place to list: \(error.localizedDescription)")
                } else {
                    print("Place successfully added to list: \(listName)")
                }
            }
    }

    func createNewList(userId: String, listName: String) {
        db.collection("users").document(userId)
            .collection("placeLists").document(listName)
            .setData(["places": []], merge: false) { error in
                if let error = error {
                    print("Error creating new list: \(error.localizedDescription)")
                } else {
                    print("List successfully created: \(listName)")
                }
            }
    }
}
