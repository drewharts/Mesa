//
//  UserProfileActivityView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileActivityView: View {
    @ObservedObject var UserProfileVM: UserProfileViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Additional Info")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                // Activity Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Activity")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Text("Recent reviews, check-ins, and other activity will be displayed here.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                    
                    // Placeholder for future content
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 100)
                        .overlay(
                            Text("Coming Soon")
                                .foregroundColor(.gray)
                                .font(.headline)
                        )
                    
                    Text("Stats & Insights")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.top, 16)
                    
                    Text("User statistics and insights will be shown here.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                    
                    // Stats placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text("Analytics Coming Soon")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
    }
} 