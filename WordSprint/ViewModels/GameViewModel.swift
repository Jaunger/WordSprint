//
//  GameViewModel.swift
//  WordSprint
//
//  Created by daniel raby on 14/07/2025.
//


import Foundation
import Combine
import SwiftUI
import FirebaseFirestore    

enum Nickname {
    static var current: String {
        get { UserDefaults.standard.string(forKey: "nick") ?? "Player\(Int.random(in: 100...999))" }
        set { UserDefaults.standard.set(newValue, forKey: "nick") }
    }
}

struct NicknameEditor: View {
    @Binding var isPresented: Bool
    @State private var draft = Nickname.current

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nickname", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Edit Nickname")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Nickname.current = draft.trimmingCharacters(in: .whitespaces)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}


@Observable class GameViewModel {
    var showSummary = false
    // seed supplied by parent
     var grid: [[Character]] = []
     var selected: [GridPoint] = []
     var accepted: [String] = []
     var score: Int = 0
      var timeLeft: Int = 90
    var isFinished = false
    var timerCancellable: AnyCancellable?

    struct GridPoint: Hashable { let row: Int; let col: Int }

    init(seed: GridSeed) {
        grid = seed.grid
        startTimer()
    }

    // MARK: - Selection
    func begin(at p: GridPoint) {
        guard !isFinished else { return }
        selected = [p]
    }
    func extend(to p: GridPoint) {
        guard !isFinished else { return }
        guard !selected.contains(p),
              let last = selected.last,
              abs(p.row - last.row) <= 1, abs(p.col - last.col) <= 1      // adjacency
        else { return }
        selected.append(p)
    }
    func endDrag() { /* no-op, kept for clarity */ }

    // MARK: - Submit
    func submit() {
        guard !isFinished else { return }

        let word = currentWord
        guard word.count >= 3,
              DictionaryService.isValid(word),
              !accepted.contains(word)
        else { selected = []; return }

        accepted.append(word)
        score += word.count   // simple scoring: 1 pt per letter
        withAnimation(.easeInOut(duration: 0.15)) {
            selected = []
        }
    }

    var currentWord: String {
        selected.map { grid[$0.row][$0.col] }.map(String.init).joined()
    }

    func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if timeLeft > 0 { timeLeft -= 1 } else { finishGame() }
            }
    }


     func finishGame() {
        isFinished = true
        timerCancellable?.cancel()

        Task {
            let nick = Nickname.current

            // 1. submit scores
            try? await FSService.submitScore(score, nick: nick)

            // 2. streak + XP
            var profile = try await ProfileService.load(for: nick)
            let today   = Calendar.current.startOfDay(for: Date())
            let lastDay = Date(timeIntervalSince1970: TimeInterval(profile.lastPlayed.seconds))

            if Calendar.current.isDate(lastDay, inSameDayAs: today) {
                // already played today → no streak change
            } else if Calendar.current.isDate(lastDay, inSameDayAs: today.addingTimeInterval(-86400)) {
                profile.streak += 1     // consecutive
            } else {
                profile.streak = 1      // reset
            }

            profile.lastPlayed = Timestamp(date: today)
            profile.xp        += (score * 10)

            try? await ProfileService.save(profile, for: nick)
        }

        showSummary = true
        Haptics.notify.notificationOccurred(.success)
    }
    
}

extension PlayerProfile {
    var level: Int   { xp / 300 }                 
    var nextCap: Int { (level + 1) * 300 }
}
