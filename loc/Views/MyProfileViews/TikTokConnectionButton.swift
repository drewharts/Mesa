//
//  TikTokConnectionButton.swift
//  loc
//
//  Created by Mesa on 7/7/25.
//

import SwiftUI

struct TikTokConnectionButton: View {
    @EnvironmentObject var tikTokAuthService: TikTokAuthService
    @State private var showDisconnectAlert = false
    @State private var isDisconnecting = false
    
    var body: some View {
        VStack(spacing: 8) {
            if tikTokAuthService.isCheckingStatus {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking TikTok status...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            } else if !tikTokAuthService.isConnected {
                Button(action: handleTikTokAction) {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(tikTokAuthService.isConnected ? .white : .pink)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tikTokAuthService.isConnected ? "TikTok Connected" : "Connect TikTok")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            if tikTokAuthService.isConnected {
                                Text("Enhanced place detection active")
                                    .font(.caption2)
                                    .opacity(0.8)
                            } else {
                                Text("For better place detection")
                                    .font(.caption2)
                                    .opacity(0.8)
                            }
                        }
                        
                        Spacer()
                        
                        if tikTokAuthService.isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.pink)
                                .font(.system(size: 14))
                        }
                    }
                    .foregroundColor(tikTokAuthService.isConnected ? .white : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tikTokAuthService.isConnected ? Color.pink : Color.gray.opacity(0.15))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if let expiresAt = tikTokAuthService.expiresAt {
                    Text("Expires: \(expiresAt, formatter: dateFormatter)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
            }
        }
        .alert("Disconnect TikTok?", isPresented: $showDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                Task {
                    await disconnectTikTok()
                }
            }
        } message: {
            Text("This will remove TikTok authorization. You can reconnect anytime.")
        }
    }
    
    private func handleTikTokAction() {
        if tikTokAuthService.isConnected {
            showDisconnectAlert = true
        } else {
            tikTokAuthService.connectTikTok()
        }
    }
    
    private func disconnectTikTok() async {
        isDisconnecting = true
        let success = await tikTokAuthService.disconnectTikTok()
        isDisconnecting = false
        
        if !success {
            // Handle error - could show an alert
            print("Failed to disconnect TikTok")
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct TikTokConnectionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Connected state
            TikTokConnectionButton()
                .environmentObject({
                    let service = TikTokAuthService()
                    service.isConnected = true
                    service.expiresAt = Date().addingTimeInterval(86400 * 7)
                    return service
                }())
            
            // Disconnected state
            TikTokConnectionButton()
                .environmentObject({
                    let service = TikTokAuthService()
                    service.isConnected = false
                    return service
                }())
            
            // Loading state
            TikTokConnectionButton()
                .environmentObject({
                    let service = TikTokAuthService()
                    service.isCheckingStatus = true
                    return service
                }())
        }
        .padding()
    }
}