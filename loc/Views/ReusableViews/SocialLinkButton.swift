//
//  SocialLinkButton.swift
//  loc
//
//  A tappable social media icon that deep links to the app or falls back to web.
//
//  Single Responsibility: Display a social link icon and handle opening the link.
//

import SwiftUI
import UIKit

/// A tappable social media icon that opens the app or falls back to a web URL.
struct SocialLinkButton: View {
    let imageName: String
    let systemFallback: String
    let appURL: String
    let webURL: String

    var body: some View {
        Button {
            if let app = URL(string: appURL), UIApplication.shared.canOpenURL(app) {
                UIApplication.shared.open(app)
            } else if let web = URL(string: webURL) {
                UIApplication.shared.open(web)
            }
        } label: {
            Group {
                if UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: systemFallback)
                }
            }
            .frame(width: 18, height: 18)
        }
    }
}
