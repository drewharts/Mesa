//
//  CommentsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/18/25.
//

import SwiftUI

struct Comment: Identifiable {
    let id = UUID()
    let username: String
    let profileImage: String
    let commentText: String
    let timestamp: String
    var likes: Int
}

struct CommentsView: View {
    @State private var comments: [Comment] = [
        Comment(username: "elleniven6", profileImage: "profile1", commentText: "Shout out to Elon Musk !", timestamp: "11h", likes: 12),
        Comment(username: "ladytheastonehouse", profileImage: "profile2", commentText: "🙏😊", timestamp: "12h", likes: 2),
        Comment(username: "pedro_juizbh", profileImage: "profile3", commentText: "3 Stakin", timestamp: "13h", likes: 3),
        Comment(username: "jeffjanapetty", profileImage: "profile4", commentText: "Trump!! 👏👏", timestamp: "7h", likes: 1),
        Comment(username: "rita4everr", profileImage: "profile5", commentText: "🙏", timestamp: "10h", likes: 1),
        Comment(username: "alliforssted", profileImage: "profile6", commentText: "🔥👏❤️", timestamp: "11h", likes: 1),
        Comment(username: "bravubravu_blancu", profileImage: "profile7", commentText: "❤️👏🔥👏😢😍😊😂", timestamp: "12h", likes: 1)
    ]
    @State private var newComment: String = ""

    var body: some View {
        VStack {
            // Comments List
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(comments) { comment in
                        HStack(alignment: .top, spacing: 8) {
                            Image(comment.profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(comment.username)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text(comment.timestamp)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Button(action: {
                                        // Handle like action
                                        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                                            comments[index].likes += 1
                                        }
                                    }) {
                                        Image(systemName: "heart")
                                            .foregroundColor(.gray)
                                    }
                                    Text("\(comment.likes)")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                Text(comment.commentText)
                                    .font(.body)
                                Button(action: {
                                    // Handle reply action
                                }) {
                                    Text("Reply")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
            }

            // Add Comment Section
            HStack {
                Image("profile8") // Placeholder for current user profile
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())

                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                    .padding(.leading, 5)

                Button(action: {
                    // Handle comment submission
                    if !newComment.isEmpty {
                        let newCommentObject = Comment(username: "currentUser", profileImage: "profile8", commentText: newComment, timestamp: "Now", likes: 0)
                        comments.append(newCommentObject)
                        self.newComment = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 10)
            }
            .padding()
        }
        .navigationTitle("Comments")
        .padding(.horizontal, -50)

    }
}

// Preview Provider
struct CommentsView_Previews: PreviewProvider {
    static var previews: some View {
        CommentsView()
    }
}

// Placeholder images (replace with actual image assets)
let placeholderImages = ["profile1", "profile2", "profile3", "profile4", "profile5", "profile6", "profile7", "profile8"]
