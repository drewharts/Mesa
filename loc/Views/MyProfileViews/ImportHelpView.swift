//
//  ImportHelpView.swift
//  loc
//
//  Displays an infographic explaining how to import content into the app
//

import SwiftUI

struct ImportHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    stepsSection
                    tipsSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Import Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Save Places from Videos")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Discover a restaurant or place in a video? Save it directly to your collection!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Steps Section
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How It Works")
                .font(.headline)
                .fontWeight(.semibold)
            
            StepRow(
                stepNumber: 1,
                icon: "play.rectangle.fill",
                iconColor: .pink,
                title: "Find a Video",
                description: "Find a video featuring a place you want to save"
            )
            
            StepRow(
                stepNumber: 2,
                icon: "arrowshape.turn.up.right.fill",
                iconColor: .blue,
                title: "Tap Share",
                description: "Tap the share button on the video"
            )
            
            StepRow(
                stepNumber: 3,
                icon: "square.and.arrow.up",
                iconColor: .green,
                title: "Share to Mesa",
                description: "Select Mesa from the share sheet options"
            )
            
            StepRow(
                stepNumber: 4,
                icon: "mappin.circle.fill",
                iconColor: .orange,
                title: "Select the Place",
                description: "We'll detect places mentioned in the video. Pick the one you want to save!"
            )
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Tips Section
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tips")
                .font(.headline)
                .fontWeight(.semibold)
            
            TipRow(
                icon: "lightbulb.fill",
                text: "Videos with location tags or place names in captions work best"
            )
            
            TipRow(
                icon: "clock.fill",
                text: "Detection usually takes just a few seconds"
            )
            
            TipRow(
                icon: "questionmark.circle.fill",
                text: "If the wrong place is detected, you can flag it to help us improve"
            )
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Step Row Component

private struct StepRow: View {
    let stepNumber: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Step \(stepNumber)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Tip Row Component

private struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.yellow)
                .frame(width: 24)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    ImportHelpView()
}
