//
//  ListHeaderView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI
import UIKit

struct ListHeaderView: View {
    var onAddList: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: onAddList) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 20)
    }
}
