//
//  LeaderboardVM.swift
//  WordSprint
//
//  Created by daniel raby on 14/07/2025.
//


import Foundation

@MainActor
final class LeaderboardViewModel: ObservableObject {
    enum Scope: String, CaseIterable { case today = "Today", week = "Week" }

    @Published var entries: [ScoreEntry] = []
    @Published var loading = true
    @Published var errorMessage: String?

    func load(scope: Scope) async {
        loading = true; errorMessage = nil
        do {
            switch scope {
            case .today: entries = try await FSService.fetchTodayScores()
            case .week:  entries = try await FSService.fetchWeekScores()
            }
            loading = false
        } catch { errorMessage = error.localizedDescription; loading = false }
    }
}
