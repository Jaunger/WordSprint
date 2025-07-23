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


@Observable
class GameViewModel {
    // MARK: - Published (observable) state
    var showSummary = false

    private(set) var grid: [[Character]] = []
    private(set) var selected: [GridPoint] = []
    private(set) var accepted: [String] = []
    private(set) var score: Int = 0
    private(set) var isPractice = false
    var timeLeft: Int = 90
    private(set) var isFinished = false
    private var timer: Timer?
    deinit { stopTimer() }
    var suppressFinishEffects = false
    
    struct GridPoint: Hashable { let row: Int; let col: Int }

    // Throttle tap sound (avoid machine-gun while dragging)
    private var lastTapSoundTime: CFTimeInterval = 0

    init(seed: GridSeed, isPractice: Bool = false) {
        self.isPractice = isPractice
        
        timeLeft = 90
        grid = seed.grid
        
        if !isPractice {
            startTimer()
        }
    }
    
    func setIsFinished(b: Bool) {
        isFinished = b
    }

    func setTimeLeft(i: Int){
        timeLeft = i
    }
    
    // MARK: - Selection
    func begin(at p: GridPoint) {
        guard !isFinished else { return }
        selected = [p]
        playTapSound()                     // ★ SOUND
    }

    func extend(to p: GridPoint) {
        guard !isFinished else { return }
        guard !selected.contains(p),
              let last = selected.last,
              abs(p.row - last.row) <= 1,
              abs(p.col - last.col) <= 1
        else { return }
        selected.append(p)
        playTapSound()                     // ★ SOUND (throttled)
    }

    func endDrag() { } // kept for clarity

    // MARK: - Submit
    func submit() {
        guard !isFinished else { return }
        let word = currentWord
        let valid = DictionaryService.isValid(word)
        print("Attempt submit:", word, "valid?", valid)

        guard word.count >= 3, valid, !accepted.contains(word) else {
            selected.removeAll()
            return
        }
        accepted.append(word)
        score += word.count
        SoundManager.shared.playSFX(named: "word")
        withAnimation(.easeInOut(duration: 0.15)) {
            selected = []
        }
    }

    var currentWord: String {
        selected.map { grid[$0.row][$0.col] }.map(String.init).joined()
    }

    func startTimer() {
        guard timer == nil, !isFinished else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1,
                                     repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Invalidate & nil out
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func freeze() {
        suppressFinishEffects = true
        stopTimer()
        SoundManager.shared.stopSFX()
        isFinished = true
    }

    /// Shared “stop and zero” used by reload paths
    func stop() {
        stopTimer()
        timeLeft = -1
    }

    private func tick() {
        guard !isFinished else { return }
        if timeLeft > 1 {
            timeLeft -= 1
            print(timeLeft)
        } else {
            stopTimer()
            finishGame()
        }
    }


    // MARK: - Finish
    func finishGame() {
        // ensure we don’t double-fire
        guard !isFinished else { return }

        // always invalidate here
        stopTimer()
        isFinished = true

        // play SFX only if not suppressed
        if !suppressFinishEffects {
            SoundManager.shared.playSFX(named: "finish")
            Haptics.notify.notificationOccurred(.success)
        }
        // … your save/profile code …
        showSummary = !suppressFinishEffects
        suppressFinishEffects = false
        
        Task {
            let nick = Nickname.current



            let dailyGrant   = XPGrant(amount:  score * 10, key: "daily")

            // ---- XP AWARD GOES HERE ----
            _ = await XPService.award(dailyGrant, to: nick)
        }
        LocalNotifs.scheduleNextDailyReminder()
        stopTimer()

    }
    

    // MARK: - Helpers
    private func playTapSound() {
        let now = CACurrentMediaTime()
        if now - lastTapSoundTime > 0.07 {        // 70 ms throttle
            lastTapSoundTime = now
            SoundManager.shared.playSFX(named : "tap")       // ★ SOUND (tile selection)
        }
    }
    
    func setSeed(d: GridSeed){
        grid = d.grid
    }
    
    func reset(with seed: GridSeed, time: Int = 90) {
        // tear down any old timer
        stopTimer()

        // reset board state…
        grid       = seed.grid
        selected   = []
        accepted   = []
        score      = 0
        timeLeft   = time
        isFinished = false

        // re-allow real finish effects
        suppressFinishEffects = false

        // then start fresh
        startTimer()
    }

    func suspendForReload() {
        // 1) prevent any finish SFX/haptics
        suppressFinishEffects = true

        // 2) kill the timer
        stopTimer()

        // 3) kill any in-flight SFX if you added stopSFX()
        SoundManager.shared.stopSFX()

        // 4) mark finished so finishGame guard blocks
        isFinished = true
    }


    /// Start a completely fresh game with a new seed & duration.
    func startNewGame(with seed: GridSeed, duration: Int = 90) {
        grid       = seed.grid
        selected   = []
        accepted   = []
        score      = 0
        timeLeft   = duration
        isFinished = false
        startTimer()
    }
}

// MARK: - Profile helpers
extension PlayerProfile {
    var level: Int   { xp / 300 }
    var nextCap: Int { (level + 1) * 300 }
    
    func canUse(theme: Theme) -> Bool {
        switch theme {
        case .classic: return true
        case .dusk:    return level >= ThemeGate.dusk
        case .neon:    return level >= ThemeGate.neon
        }
    }
    
    
}


