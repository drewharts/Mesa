//
//  UserSession.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//


import Combine

class UserSession: ObservableObject {
    @Published var isUserLoggedIn: Bool = false
}
