//
//  ApprovalService.swift
//  loc
//
//  Invite/approval gate (migration 20261027_user_approval_gate.sql).
//  New signups are 'pending' until Drew approves them in the in-app review screen.
//

import Foundation
import Supabase

enum ApprovalStatus: String, Codable {
    case pending, approved, rejected
}

struct PendingUser: Decodable, Identifiable, Hashable {
    let id: String
    let fullName: String?
    let email: String?
    let phoneNumber: String?
    let profilePhotoUrl: String?
    let instagramUsername: String?
    let tiktokUsername: String?
    let accountType: String?
    let createdAt: String?
    let approvalStatus: String
    let signInProvider: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case phoneNumber = "phone_number"
        case profilePhotoUrl = "profile_photo_url"
        case instagramUsername = "instagram_username"
        case tiktokUsername = "tiktok_username"
        case accountType = "account_type"
        case createdAt = "created_at"
        case approvalStatus = "approval_status"
        case signInProvider = "sign_in_provider"
    }
}

@MainActor
final class ApprovalService {
    static let shared = ApprovalService()
    static let adminUserId = "C9DFA19E-B1B0-4EF1-8697-E448BC606CC7"
    private static let cacheKey = "cachedApprovalStatus"

    private let supabase = SupabaseManager.shared
    private init() {}

    static func isAdmin(_ userId: String?) -> Bool {
        userId?.uppercased() == adminUserId
    }

    /// The caller's status. Fails open to the last known value (or approved) so a network
    /// blip or a not-yet-applied migration never locks real users out; RLS is the server-side gate.
    func fetchMyStatus() async -> ApprovalStatus {
        do {
            let raw: String? = try await supabase.client
                .rpc("get_my_approval_status")
                .execute()
                .value
            let status = raw.flatMap(ApprovalStatus.init(rawValue:)) ?? .approved
            UserDefaults.standard.set(status.rawValue, forKey: Self.cacheKey)
            return status
        } catch {
            print("ℹ️ [Approval] status check failed: \(error.localizedDescription)")
            return UserDefaults.standard.string(forKey: Self.cacheKey).flatMap(ApprovalStatus.init(rawValue:)) ?? .approved
        }
    }

    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    // MARK: Admin

    func listUsers(status: ApprovalStatus = .pending) async throws -> [PendingUser] {
        struct Params: Encodable { let p_status: String }
        return try await supabase.client
            .rpc("admin_list_users_for_review", params: Params(p_status: status.rawValue))
            .execute()
            .value
    }

    func setStatus(userId: String, to status: ApprovalStatus) async throws {
        struct Params: Encodable { let p_user_id: String; let p_status: String }
        try await supabase.client
            .rpc("admin_set_user_approval", params: Params(p_user_id: userId, p_status: status.rawValue))
            .execute()
    }
}
