//
//  SwipeBack.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/16/25.
//

import Foundation

import UIKit

extension UINavigationController: UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return gestureRecognizer == self.interactivePopGestureRecognizer
    }
}

