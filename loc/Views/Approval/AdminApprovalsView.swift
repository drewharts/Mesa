//
//  AdminApprovalsView.swift
//  loc
//
//  Admin-only (Drew) review queue. The RPCs refuse anyone else server-side too.
//

import SwiftUI

struct AdminApprovalsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tab: ApprovalStatus = .pending
    @State private var users: [PendingUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Picker("", selection: $tab) {
                    Text("Pending").tag(ApprovalStatus.pending)
                    Text("Rejected").tag(ApprovalStatus.rejected)
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                if let errorMessage {
                    Text(errorMessage).foregroundColor(.red).font(.footnote)
                }
                if !isLoading && users.isEmpty && errorMessage == nil {
                    Text(tab == .pending ? "No one waiting. 🎉" : "No rejected users.")
                        .foregroundColor(.gray)
                }
                ForEach(users) { user in
                    row(user)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .overlay { if isLoading && users.isEmpty { ProgressView() } }
            .refreshable { await load() }
            .task(id: tab) { await load() }
        }
    }

    private func row(_ user: PendingUser) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: user.profilePhotoUrl.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.2))
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(user.fullName?.isEmpty == false ? user.fullName! : "No name").font(.headline)
                if let email = user.email, !email.isEmpty { detail(email) }
                if let phone = user.phoneNumber, !phone.isEmpty { detail(phone) }
                if let ig = user.instagramUsername, !ig.isEmpty { detail("IG @\(ig)") }
                if let tt = user.tiktokUsername, !tt.isEmpty { detail("TikTok @\(tt)") }
                detail([user.signInProvider.map { "via \($0.capitalized)" }, user.createdAt.map(Self.formatDate)]
                    .compactMap { $0 }.joined(separator: " · "))
                HStack(spacing: 10) {
                    if tab == .pending {
                        actionButton("Reject", color: .gray) { await decide(user, .rejected) }
                    }
                    actionButton("Approve", color: .black) { await decide(user, .approved) }
                }
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 6)
    }

    private func detail(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundColor(.gray).lineLimit(1)
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(color, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await ApprovalService.shared.listUsers(status: tab)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load users: \(error.localizedDescription)"
        }
    }

    private func decide(_ user: PendingUser, _ status: ApprovalStatus) async {
        let previous = users
        users.removeAll { $0.id == user.id }   // optimistic
        do {
            try await ApprovalService.shared.setStatus(userId: user.id, to: status)
            Analytics.track(status == .approved ? .userApproved : .userRejected)
        } catch {
            users = previous
            errorMessage = "Couldn't update \(user.fullName ?? "user"): \(error.localizedDescription)"
        }
    }

    private static func formatDate(_ raw: String) -> String {
        let prefix = String(raw.prefix(10))  // yyyy-MM-dd
        let input = DateFormatter(); input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: prefix) else { return raw }
        let out = DateFormatter(); out.dateStyle = .medium
        return "joined " + out.string(from: date)
    }
}
