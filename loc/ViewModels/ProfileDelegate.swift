//
//  ProfileDelegate.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/6/24.
//


import Foundation
import GooglePlaces

protocol ProfileDelegate: AnyObject {
    func didAddPlace(toList listName: String, place: GMSPlace)
}
