//
//  YourAppCheckProviderFactory.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/12/24.
//


import Firebase

class YourAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
    }
}
