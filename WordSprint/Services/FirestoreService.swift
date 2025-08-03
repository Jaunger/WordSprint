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
    static func dailySeedString(for date: Date = Date()) -> String {
        // Normalize the date to IL midnight so every client agrees on “today”
        let startOfILDay = ILTime.cal.startOfDay(for: date)
        let id = ilDayFormatter.string(from: startOfILDay)

        let arc4 = GKARC4RandomSource(seed: Data(id.utf8))

        return playableSeed(using: arc4)
    }

}

/// Quick console dump of a seed + the words it contains.
func debugDumpSeed(_ seed: String, depthLimit: Int? = nil, limit: Int = 80) {
    let all: [String]
    if let depthLimit {
        all = Array(WordFinder.shared.words(in: seed, depthLimit: depthLimit))
    } else {
        all = Array(WordFinder.shared.words(in: seed))
    }

    let sorted = all.sorted { ($0.count, $0) > ($1.count, $1) } // longest first
    let long   = all.filter { $0.count >= 5 }.count
    let avgLen = all.isEmpty ? 0 :
        Double(all.reduce(0) { $0 + $1.count }) / Double(all.count)

    print("🧩 Seed: \(seed)")
    print("   words: \(all.count), long(>=5): \(long), avgLen: \(String(format: "%.2f", avgLen))")
    print("   top \(min(limit, sorted.count)) words:")
    for w in sorted.prefix(limit) {
        print("     • \(w)")
    }
    
}

private let ilDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyyMMdd"
    f.timeZone   = ILTime.tz          // ← Israel TZ, not device TZ
    return f
}()
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

enum ILTime {
    static let tz = TimeZone(identifier: "Asia/Jerusalem")!

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }

    static func startOfTomorrow() -> Date {
        cal.date(byAdding: .day, value: 1, to: startOfToday())!
    }
    static func secondsUntilTomorrow() -> Int {
        max(Int(startOfTomorrow().timeIntervalSinceNow), 0)
    }
    static func startOfToday() -> Date {
        cal.startOfDay(for: Date())
    }

}

func hhmmss(_ secs: Int) -> String {
    let h = secs / 3600
    let m = (secs % 3600) / 60
    let s = secs % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
}

enum LocalNotifs {
    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { set in
            guard set.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge]) { _,_ in }
        }
    }

    static func scheduleNextDailyReminder() {
        let fireDate = ILTime.startOfTomorrow()
        var comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: fireDate)
        comps.timeZone = ILTime.tz

        let content = UNMutableNotificationContent()
        content.title = "New WordSprint puzzle!"
        content.body  = "Your next daily is ready. Come play 🎉"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: "dailyReady", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
