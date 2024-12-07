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
    
    func saveUserProfile(uid: String, profile: Profile, completion: @escaping (Error?) -> Void) {
        do {
            // Note the usage of profile.data here, which is Codable
            try db.collection("profiles").document(uid).setData(from: profile.data) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }


    func addPlaceToList(userId: String, listName: String, place: GMSPlace) {
        let placeDict: [String: Any] = [
            "placeID": place.placeID ?? "",
            "name": place.name ?? "",
            "address": place.formattedAddress ?? ""
        ]

        db.collection("users").document(userId)
            .collection("placeLists").document(listName)
            .setData(["places": FieldValue.arrayUnion([placeDict])], merge: true) { error in
                if let error = error {
                    print("Error adding place to list: \(error.localizedDescription)")
                } else {
                    print("Place successfully added to list: \(listName)")
                }
            }
    }

    func createNewList(userId: String, listName: String) {
        let listData = PlaceList(name: listName)
        do {
            try db.collection("users").document(userId)
                .collection("placeLists").document(listName)
                .setData(from: listData) { error in
                    if let error = error {
                        print("Error creating new list: \(error.localizedDescription)")
                    } else {
                        print("List successfully created: \(listName)")
                    }
                }
        } catch {
            print("Error encoding listData: \(error.localizedDescription)")
        }
    }

    
    func fetchLists(userId: String, completion: @escaping ([PlaceList]) -> Void) {
        db.collection("users").document(userId)
            .collection("placeLists").getDocuments { result, error in
                if let error = error {
                    print("Error fetching lists: \(error.localizedDescription)")
                    completion([]) // Return an empty array if there's an error
                } else {
                    print("Document count: \(result?.documents.count ?? 0)")
                    let placeLists = result?.documents.compactMap { document in
                        try? document.data(as: PlaceList.self)
                    } ?? []
                    completion(placeLists) // Return the fetched place lists
                }
            }
    }

}
