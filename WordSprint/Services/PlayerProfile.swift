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
    
    init(streak: Int = 0,
         lastPlayed: Timestamp = .init(seconds: 0, nanoseconds: 0),
         xp: Int = 0) {
        self.streak = streak
        self.lastPlayed = lastPlayed
        self.xp = xp
    }

    private enum CodingKeys: String, CodingKey {
        case streak, lastPlayed, xp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streak     = try c.decodeIfPresent(Int.self,        forKey: .streak)     ?? 0
        xp         = try c.decodeIfPresent(Int.self,        forKey: .xp)         ?? 0
        lastPlayed = try c.decodeIfPresent(Timestamp.self,  forKey: .lastPlayed) ?? .init(seconds: 0, nanoseconds: 0)
    }
    
}


enum ProfileService {
    private static let db = Firestore.firestore()

    static func load(for nick: String) async throws -> PlayerProfile {
        let ref  = db.document("profiles/\(nick)")
        let snap = try await ref.getDocument()

        guard snap.exists else { return PlayerProfile() }

        do {
            return try snap.data(as: PlayerProfile.self)
        } catch {
            print("🔥 Decode Profile failed for \(nick):", error)
            print("🔥 Raw data:", snap.data() ?? [:])
            throw error
        }
    }

    static func save(_ profile: PlayerProfile, for nick: String) async throws {
        try await db.document("profiles/\(nick)").setData([
            "streak"     : profile.streak,
            "lastPlayed" : profile.lastPlayed,
            "xp"         : profile.xp
        ], merge: true)
    }
}

struct XPGrant {
    let amount: Int
    let key: String
}


struct LevelUpResult {
    let oldLevel: Int
    let newLevel: Int
}

extension Notification.Name {
    static let leveledUp = Notification.Name("leveledUp")
    static let xpChanged  = Notification.Name("xpChanged")
    static let scoreSubmitted = Notification.Name("scoreSubmitted")

}


enum XPService {

    static func award(_ grant: XPGrant, to nick: String) async -> LevelUpResult? {
        do {
            print("grant" + String(describing: grant))
            // 1) Load current profile
            var profile = try await ProfileService.load(for: nick)
            let oldLevel = profile.level

            // 2) DAILY branch: guard + streak & lastPlayed in one place
            if grant.key == "daily" {
                let cal     = ILTime.cal       // gregorian w/ Israel tz
                let todayIL = ILTime.startOfToday() // 00:00 in IL tz
                let last    = Date(timeIntervalSince1970: TimeInterval(profile.lastPlayed.seconds))

                // already played today → no XP, no streak change
                if cal.isDate(last, inSameDayAs: todayIL) {
                    return nil
                }

                // streak calc (yesterday = consecutive, otherwise reset to 1)
                if cal.isDate(last, inSameDayAs: cal.date(byAdding: .day, value: -1, to: todayIL)!) {
                    profile.streak += 1
                } else {
                    profile.streak = 1
                }

                profile.lastPlayed = Timestamp(date: todayIL)
            }

            // 3) Add XP
            profile.xp += grant.amount
            let newLevel = profile.level

            // 4) Persist once
            try await ProfileService.save(profile, for: nick)

            // 5) Notify UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .xpChanged, object: nil)
                if newLevel > oldLevel {
                    print("→ posting leveledUp new=\(newLevel)")
                    NotificationCenter.default.post(name: .leveledUp,
                                                    object: nil,
                                                    userInfo: ["old": oldLevel, "new": newLevel])
                }
            }

            return (newLevel > oldLevel)
                ? LevelUpResult(oldLevel: oldLevel, newLevel: newLevel)
                : nil

        } catch {
            print("⚠️ XP/Streak award failed:", error)
            return nil
        }
    }
}
