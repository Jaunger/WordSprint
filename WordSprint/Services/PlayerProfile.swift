//
//  PlayerProfile.swift
//  WordSprint
//
//  Created by daniel raby on 18/07/2025.
//


import FirebaseFirestore

struct PlayerProfile: Codable {
    var streak: Int = 0
    var lastPlayed: Timestamp = .init(seconds: 0, nanoseconds: 0)
    var xp: Int = 0
}

enum ProfileService {
    private static let db = Firestore.firestore()

    static func load(for nick: String) async throws -> PlayerProfile {
        let ref = db.document("profiles/\(nick)")
        let snap = try await ref.getDocument()
        return (try? snap.data(as: PlayerProfile.self)) ?? PlayerProfile()
    }

    static func save(_ profile: PlayerProfile, for nick: String) async throws {
        try await db.document("profiles/\(nick)").setData([
            "streak"     : profile.streak,
            "lastPlayed" : profile.lastPlayed,
            "xp"         : profile.xp
        ], merge: true)
    }
}
