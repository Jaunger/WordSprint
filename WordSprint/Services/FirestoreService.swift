import FirebaseFirestore
import GameplayKit
import SwiftUI

// MARK: - Game models
struct GridSeed: Decodable {
    let seed: String          // e.g. "TARSLINEOBUHCPD"

    var grid: [[Character]] {
        let chars = Array(seed)
        guard chars.count == 16 else {
            assertionFailure("Seed must be 16 letters, got \(chars.count)")
            return Array(repeating: Array(repeating: "?", count: 4), count: 4)
        }
        return stride(from: 0, to: 16, by: 4).map { i in
            Array(chars[i ..< i + 4])
        }
    }
}

struct ScoreEntry: Identifiable, Decodable {
    @DocumentID var id: String?     // Firestore doc ID
    let nick: String
    let score: Int
    let createdAt: Timestamp?
}

// MARK: - Firestore wrapper
enum FSService {
    private static let db = Firestore.firestore()
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = .current
        return f
    }()

    // MARK: Seed -------------------------------------------------------------

    /// Fetch today's puzzle seed. If none exists and `fallbackToYesterday`
    /// is true, try yesterday's seed instead.
    static func fetchTodaySeed(fallbackToYesterday: Bool = false) async throws -> GridSeed {
        let todayID = dateID(Date())
        if let seed = try await getSeed(docID: todayID) { return seed }

        guard fallbackToYesterday,
              let ySeed = try await getSeed(docID: dateID(-86400)) else {
            throw NSError(domain: "SeedMissing", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Today's puzzle is not set"])
        }
        return ySeed
    }

    private static func getSeed(docID: String) async throws -> GridSeed? {
        let snap = try await db.document("puzzleSeeds/\(docID)").getDocument()
        return try snap.data(as: GridSeed?.self)          // nil if doc missing
    }
    
    // MARK: Scores -----------------------------------------------------------

    // (a) keep your existing submitScore(_:nick:)
    static func submitScore(_ score: Int, nick: String) async throws {
        let id = dateID(Date())
        try await db.collection("dailies/\(id)/scores").addDocument(data: [
            "nick": nick,
            "score": score,
            "createdAt": FieldValue.serverTimestamp()
        ])
        try? await submitWeekly(score: score, nick: nick)   // ← add this line
    }

    /* ── NEW ── upload / increment weekly score */
    private static func submitWeekly(score: Int, nick: String) async throws {
        let weekID = Date().isoWeekID                      // "2025-W29"
        try await db.collection("weekly/\(weekID)/scores")
            .document(nick)                                // one doc per nick
            .setData(["nick": nick,
                      "score": FieldValue.increment(Int64(score))],
                     merge: true)                          // upsert / add
    }

    /* ── NEW ── fetch weekly scores */
    static func fetchWeekScores(limit: Int = 25) async throws -> [ScoreEntry] {
        let weekID = Date().isoWeekID
        let snap = try await db.collection("weekly/\(weekID)/scores")
            .order(by: "score", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: ScoreEntry?.self) }
    }

    /// Fetch today's top N scores (default 25)
    static func fetchTodayScores(limit: Int = 25) async throws -> [ScoreEntry] {
        let id = dateID(Date())
        let snap = try await db.collection("dailies/\(id)/scores")
            .order(by: "score", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: ScoreEntry?.self) }
    }
    
    static func writeTodaySeed(_ grid: GridSeed) async throws {
        let id = dateID(Date())                      
        try await db.document("puzzleSeeds/\(id)")
            .setData(["seed": grid.seed])

    }

    // MARK: Utils ------------------------------------------------------------

    /// date offset helper (seconds can be negative)
    private static func dateID(_ secondsFromNow: TimeInterval) -> String {
        fmt.string(from: Date(timeIntervalSinceNow: secondsFromNow))
    }
    private static func dateID(_ date: Date) -> String { fmt.string(from: date) }
    

    /// Deterministic 16-letter seed for a given date
    static func dailySeedString(for date: Date) -> String {
        let id = dayFormatter.string(from: date)
        let arc4  = GKARC4RandomSource(seed: id.data(using: .utf8)!)
        // use *your* playableSeed() so grids are nice
        return playableSeed(using: arc4)
    }
    
    static func dailyGridSeed(for date: Date) -> GridSeed {
        GridSeed(seed: dailySeedString(for: date))
    }
}

private let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyyMMdd"
    f.timeZone   = .current
    return f
}()
extension Date {
    var isoWeekID: String {
        let cal = Calendar(identifier: .iso8601)
        let w   = cal.component(.weekOfYear,        from: self)
        let y   = cal.component(.yearForWeekOfYear, from: self)
        return String(format: "%04d-W%02d", y, w)   // 2025-W29
    }
}
