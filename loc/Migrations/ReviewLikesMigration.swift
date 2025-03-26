//
//  ReviewLikesMigration.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/14/25.
//

import Foundation
import FirebaseFirestore

class ReviewLikesMigration {
    private let db = Firestore.firestore()
    
    func migrate(completion: @escaping (Error?) -> Void) {
        print("Starting ReviewLikesMigration...")
        // First get all places
        db.collection("places").getDocuments { (placesSnapshot, error) in
            if let error = error {
                print("❌ Error fetching places: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            guard let places = placesSnapshot?.documents else {
                print("⚠️ No places found in database")
                completion(nil)
                return
            }
            
            print("📝 Found \(places.count) places to process")
            
            let group = DispatchGroup()
            var migrationError: Error?
            var processedPlaces = 0
            var totalReviewsProcessed = 0
            
            // For each place, get its reviews subcollection
            for place in places {
                group.enter()
                
                let reviewsRef = self.db.collection("places").document(place.documentID).collection("reviews")
                print("Processing reviews for place: \(place.documentID)")
                
                reviewsRef.getDocuments { (reviewsSnapshot, error) in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error fetching reviews for place \(place.documentID): \(error.localizedDescription)")
                        migrationError = error
                        return
                    }
                    
                    guard let reviews = reviewsSnapshot?.documents else {
                        print("ℹ️ No reviews found for place \(place.documentID)")
                        return
                    }
                    
                    print("📝 Processing \(reviews.count) reviews for place \(place.documentID)")
                    
                    let batch = self.db.batch()
                    var reviewsUpdated = 0
                    
                    for review in reviews {
                        if review.data()["likes"] == nil {
                            let reviewRef = reviewsRef.document(review.documentID)
                            batch.updateData(["likes": 0], forDocument: reviewRef)
                            reviewsUpdated += 1
                        }
                    }
                    
                    if reviewsUpdated > 0 {
                        batch.commit { error in
                            if let error = error {
                                print("❌ Error updating reviews for place \(place.documentID): \(error.localizedDescription)")
                                migrationError = error
                            } else {
                                print("✅ Successfully updated \(reviewsUpdated) reviews for place \(place.documentID)")
                                totalReviewsProcessed += reviewsUpdated
                            }
                        }
                    }
                    
                    processedPlaces += 1
                    print("Progress: \(processedPlaces)/\(places.count) places processed")
                }
            }
            
            group.notify(queue: .main) {
                if let error = migrationError {
                    print("❌ Migration completed with errors: \(error.localizedDescription)")
                } else {
                    print("✅ Migration completed successfully!")
                    print("📊 Summary:")
                    print("   - Processed \(processedPlaces) places")
                    print("   - Updated \(totalReviewsProcessed) reviews")
                }
                completion(migrationError)
            }
        }
    }
} 