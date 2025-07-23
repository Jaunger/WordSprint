import Foundation
import SwiftUI

@MainActor
final class LeaderboardViewModel: ObservableObject {

    // MARK: - Scope
    enum Scope: String, CaseIterable, Identifiable {
        case today = "Today"
        case week  = "Week"
        var id: String { rawValue }
    }

    // Persist last used scope
    @AppStorage("leaderScope") private var storedScope: String = Scope.today.rawValue
    var scope: Scope {
        get { Scope(rawValue: storedScope) ?? .today }
        set {
            guard storedScope != newValue.rawValue else { return }
            storedScope = newValue.rawValue
            Task { await load(scope: newValue, animated: true) }
        }
    }

    // MARK: - Data
    @Published private(set) var entries: [ScoreEntry] = []
    @Published var loading: Bool = true
    @Published var errorMessage: String?
    @Published var myRank: Int?
    @Published var myScore: Int?

    // For smooth row animations (simple diff trigger)
    @Published private(set) var reloadToken: UUID = .init()

    // MARK: - Public API
    func initialLoad() async {
        guard entries.isEmpty else { return }
        await load(scope: scope)
    }

    func refresh() async {
        await load(scope: scope, animated: false)
    }

    func load(scope: Scope, animated: Bool = false) async {
        loading = true
        errorMessage = nil
        do {
            let newEntries: [ScoreEntry]
            switch scope {
            case .today: newEntries = try await FSService.fetchTodayScores()
            case .week:  newEntries = try await FSService.fetchWeekScores()
            }
            // Rank extraction (only of those we fetched)
            if let me = newEntries.firstIndex(where: { $0.nick == Nickname.current }) {
                myRank = me + 1
                myScore = newEntries[me].score
            } else {
                myRank = nil; myScore = nil
            }

            if animated {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    entries = newEntries
                    reloadToken = UUID()
                }
            } else {
                entries = newEntries
                reloadToken = UUID()
            }
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
            entries = []
            myRank = nil; myScore = nil
        }
    }

    // MARK: - Week subtitle
    var weekSubtitle: String {
        guard scope == .week else { return "" }
        let cal = Calendar(identifier: .iso8601)
        // start of ISO week (Mon)
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let end   = cal.date(byAdding: .day, value: 6, to: start)!
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    var title: String {
        scope == .today ? "Today's Leaders" : "This Week"
    }

    var emptyMessage: String {
        scope == .today ? "No scores yet today." : "No weekly scores yet."
    }
}
