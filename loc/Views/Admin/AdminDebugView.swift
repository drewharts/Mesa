//
//  AdminDebugView.swift
//  loc
//
//  Admin debug view for logging in as any user
//  Only available in DEBUG builds
//

import SwiftUI

struct AdminDebugView: View {
    @StateObject private var adminService = AdminService.shared
    @EnvironmentObject var userSession: UserSession
    let dataManager: DataManager?
    @State private var users: [AdminUser] = []
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    init(dataManager: DataManager? = nil) {
        self.dataManager = dataManager
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Warning banner
                warningBanner
                
                // User list
                if adminService.isLoading || isSearching {
                    loadingView
                } else if users.isEmpty {
                    emptyStateView
                } else {
                    userList
                }
            }
            .navigationTitle("Admin Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search users...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await performSearch(newValue)
                }
            }
            .alert("Admin Login", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .task {
            await loadUsers()
        }
    }
    
    // MARK: - Subviews
    
    private var warningBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Admin Debug Mode")
                    .font(.headline)
            }
            
            Text("⚠️ This allows logging in as ANY user")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.orange.opacity(0.1))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading users...")
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Users Found")
                .font(.headline)
            
            if let error = adminService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Retry") {
                Task {
                    await loadUsers()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var userList: some View {
        List(users) { user in
            // Check if user ID looks like a UUID (Supabase) vs Firebase ID
            let isSupabaseUser = user.id.contains("-") && user.id.count > 30
            
            if isSupabaseUser {
                Button {
                    Task {
                        await loginAs(user)
                    }
                } label: {
                    AdminUserRow(user: user)
                }
            } else {
                HStack {
                    AdminUserRow(user: user)
                    Spacer()
                    Text("No Auth")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
                .opacity(0.5)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func loadUsers() async {
        do {
            users = try await adminService.fetchAllUsers()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    private func performSearch(_ query: String) async {
        isSearching = true
        defer { isSearching = false }
        
        do {
            users = try await adminService.searchUsers(query: query)
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    private func loginAs(_ user: AdminUser) async {
        do {
            print("🔍 [AdminDebugView] Logging in as user from public.users:")
            print("   - ID: \(user.id)")
            print("   - Name: \(user.fullName ?? "nil") (first: \(user.firstName ?? "nil"), last: \(user.lastName ?? "nil"))")
            print("   - Email: \(user.email ?? "nil")")
            print("   - Photo: \(user.profilePhotoUrl ?? "nil")")
            
            try await adminService.loginAsUser(user)
            
            // Update UserSession to trigger view change
            await MainActor.run {
                userSession.setUserLoggedIn(uid: user.id)
            }
            
            print("✅ [AdminDebugView] UserSession updated with ID: \(user.id)")
            
            // Initialize profile data if DataManager is available
            if let dataManager = dataManager {
                print("🔄 [AdminDebugView] Initializing profile data for user ID: \(user.id)")
                Task.detached(priority: .background) {
                    await dataManager.initializeProfileData(userId: user.id)
                }
            } else {
                print("⚠️ [AdminDebugView] No DataManager available - profile data won't load")
            }
            
            // Dismiss immediately - user is now logged in
            dismiss()
            
        } catch {
            alertMessage = "Failed to login: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Admin User Row Component

private struct AdminUserRow: View {
    let user: AdminUser
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile photo
            if let photoUrl = user.profilePhotoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                // Placeholder
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.title3)
                            .foregroundColor(.white)
                    }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                
                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No email • ID: \(user.id.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if let createdAt = user.createdAt {
                    Text("Joined \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Login indicator
            Image(systemName: "person.fill.checkmark")
                .foregroundColor(.blue)
                .font(.caption)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#if DEBUG
struct AdminDebugView_Previews: PreviewProvider {
    static var previews: some View {
        AdminDebugView()
    }
}
#endif

