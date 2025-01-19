//
//  EndEditing.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//

import SwiftUI

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

