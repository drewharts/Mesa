//
//  GroupPickInviteView.swift
//  loc
//
//  Sub-screen of the group pick sheet: pick friends to add to the vote.
//  They get a push saying they were added.
//

import SwiftUI

struct GroupPickInviteView: View {
    @ObservedObject var viewModel: GroupPickViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { viewModel.mode = .vote } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                Text("Invite friends")
                    .font(.title2.weight(.bold))
                Spacer()
            }
            .padding(.horizontal, 12)

            if let error = viewModel.errorMessage {
                Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, 20)
            }

            let friends = viewModel.invitableFriends
            if friends.isEmpty {
                Text("Everyone you follow is already in.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(friends, id: \.id) { friend in
                            friendRow(friend)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                Button {
                    Task { await viewModel.sendInvites() }
                } label: {
                    Text(viewModel.inviteSelection.isEmpty ? "Pick friends" : "Invite \(viewModel.inviteSelection.count)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inviteSelection.isEmpty || viewModel.isWorking)
                .opacity(viewModel.inviteSelection.isEmpty ? 0.4 : 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .padding(.top, 8)
    }

    private func friendRow(_ friend: TonightFriend) -> some View {
        let selected = viewModel.inviteSelection.contains(friend.id)
        return Button { viewModel.toggleInvite(friend.id) } label: {
            HStack(spacing: 12) {
                Text(String(friend.firstName.prefix(1)).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.primary.opacity(0.75)))
                Text(friend.firstName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? .green : .secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}
