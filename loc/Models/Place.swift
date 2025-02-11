//
//  Place.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import Foundation
import FirebaseFirestore

struct Place: Codable,Identifiable {
    var id: UUID = UUID()
    let name: String
    let address: String

}
