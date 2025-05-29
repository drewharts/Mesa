//
//  CustomAnnotation.swift
//  loc
//
//  Created by Andrew Hartsfield II
//

import UIKit
import MapKit

class CustomAnnotation: NSObject, MKAnnotation {
    
    // This property must be key-value observable, which the `@objc dynamic` attributes provide.
    @objc dynamic var coordinate: CLLocationCoordinate2D
    
    var title: String?
    
    var subtitle: String?
    
    var imageName: String?
    
    // Additional properties specific to Loc app
    var placeID: UUID?
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
    
    // Convenience initializer for creating from DetailPlace
    convenience init(place: DetailPlace) {
        guard let geoPoint = place.coordinate else {
            self.init(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
            return
        }
        
        let coordinate = CLLocationCoordinate2D(
            latitude: geoPoint.latitude,
            longitude: geoPoint.longitude
        )
        
        self.init(coordinate: coordinate)
        self.title = place.name
        self.subtitle = place.description
        self.placeID = place.id
    }
}

// Custom annotation view for use with UIKit maps if needed
class CustomAnnotationView: MKAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }
    
    private func setupUI() {
        // Common setup
        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        centerOffset = CGPoint(x: 0, y: -20)
        canShowCallout = true
        
        if let customAnnotation = annotation as? CustomAnnotation {
            if let imageName = customAnnotation.imageName {
                image = UIImage(named: imageName)
            } else {
                // Default pin image
                image = UIImage(named: "DestPin")
            }
        }
    }
    
    // Update image if annotation changes
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        if let customAnnotation = annotation as? CustomAnnotation {
            if let imageName = customAnnotation.imageName {
                image = UIImage(named: imageName)
            } else {
                image = UIImage(named: "DestPin")
            }
        }
    }
} 
