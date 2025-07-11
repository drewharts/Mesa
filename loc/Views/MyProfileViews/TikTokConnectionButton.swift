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
    @State private var showSuccessMessage = false
    @State private var showErrorMessage = false
    @State private var messageText = ""
    
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
            } else {
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
                
                if let connectedAt = tikTokAuthService.connectedAt {
                    Text("Connected: \(connectedAt, formatter: dateFormatter)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
                
                if tikTokAuthService.isCompletingConnection {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Completing connection...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
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
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("OK") { }
        } message: {
            Text(messageText)
        }
        .alert("Error", isPresented: $showErrorMessage) {
            Button("OK") { }
        } message: {
            Text(messageText)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TikTokAuthSuccess"))) { notification in
            if let message = notification.userInfo?["message"] as? String {
                messageText = message
                showSuccessMessage = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TikTokAuthError"))) { notification in
            if let message = notification.userInfo?["message"] as? String {
                messageText = message
                showErrorMessage = true
            }
        }
        .onAppear {
            // Refresh status when view appears (e.g., returning from Safari)
            Task {
                await tikTokAuthService.checkConnectionStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Also refresh when app becomes active (returning from Safari)
            Task {
                await tikTokAuthService.checkConnectionStatus()
            }
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
                    service.connectedAt = Date().addingTimeInterval(-86400 * 7)
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