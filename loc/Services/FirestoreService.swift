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
    
    func saveUserProfile(uid: String, profileData: ProfileData, completion: @escaping (Error?) -> Void) {
        do {
            try db.collection("users").document(uid)
                .setData(from: profileData, merge: true, completion: completion)
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

    func createNewList(placeList: PlaceList,userID: String) {
        do {
            try db.collection("users").document(userID)
                .collection("placeLists").document(placeList.name)
                .setData(from: placeList) { error in
                    if let error = error {
                        print("Error creating new list: \(error.localizedDescription)")
                    } else {
                        print("List successfully created: \(placeList.name)")
                    }
                }
        } catch {
            print("Error encoding listData: \(error.localizedDescription)")
        }
    }
    
    
    func fetchList(userId: String, listName: String, completion: @escaping (Result<PlaceList, Error>) -> Void) {
        db.collection("users").document(userId)
            .collection("placeLists").document(listName)
            .getDocument { document, error in
                if let error = error {
                    print("Error fetching list: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let document = document, document.exists else {
                    let notFoundError = NSError(domain: "FirestoreError", code: 404, userInfo: [NSLocalizedDescriptionKey: "List not found"])
                    completion(.failure(notFoundError))
                    return
                }

                do {
                    let placeList = try document.data(as: PlaceList.self)
                    completion(.success(placeList))
                } catch {
                    print("Error decoding list: \(error.localizedDescription)")
                    completion(.failure(error))
                }
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
