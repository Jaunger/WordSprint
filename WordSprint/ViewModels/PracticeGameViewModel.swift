//
//  PracticeGameViewModel.swift
//  WordSprint
//

import Foundation
import GameplayKit

//-------------------------------------------------------------------------
// 1. GKRandom → RandomNumberGenerator bridge
//-------------------------------------------------------------------------
struct GKRandomAdapter: RandomNumberGenerator {
    private var base: GKRandom
    init(_ base: GKRandom) { self.base = base }
    mutating func next() -> UInt64 { UInt64(bitPattern: Int64(base.nextInt())) }
}

//-------------------------------------------------------------------------
// Alternative: Force maximum diversity (for testing)
//-------------------------------------------------------------------------
func maxDiversitySeed(using gk: GKRandom = GKRandomSource.sharedRandom()) -> String {
    var generator = GKRandomAdapter(gk)
    
    // Use most common English letters with good distribution
    let commonLetters = Array("ETAOINSHRDLCUMWFGYPBVKJXQZ")
    let vowels = Array("AEIOU")
    
    var result: [Character] = []
    var usedLetters: Set<Character> = []
    
    // Ensure we have good vowels first
    for _ in 0..<4 {
        let vowel = vowels.randomElement(using: &generator)!
        result.append(vowel)
        usedLetters.insert(vowel)
    }
    
    // Fill rest with diverse consonants
    for letter in commonLetters {
        if result.count >= 16 { break }
        if !usedLetters.contains(letter) {
            result.append(letter)
            usedLetters.insert(letter)
        }
    }
    
    // Fill any remaining slots (shouldn't happen)
    while result.count < 16 {
        result.append("N")
    }
    
    result.shuffle(using: &generator)
    return String(result)
}

//-------------------------------------------------------------------------
// REAL Boggle dice configuration - this is the key!
//-------------------------------------------------------------------------
let officialBoggleDice = [
    "AEANEG", "AHSPCO", "ASPFFK", "OBJOAB", "IOTMUC", "RYVDEL",
    "LRYTTE", "EGHWNE", "SEOTIS", "ANAEEG", "IDSYTT", "OATTOW",
    "MTOICU", "AFPKFS", "XLDERI", "HCPOAS"
]

// Alternative modern dice set (post-1987)
let modernBoggleDice = [
    "AAEEGN", "ELRTTY", "AOOTTW", "ABBJOO", "EHRTVW", "CIMOTU",
    "DISTTY", "EIOSST", "DELRVY", "ACHOPS", "HIMNQU", "EEINSU",
    "EEGHNW", "AFFKPS", "HLNNRZ", "DEILRX"
]

//-------------------------------------------------------------------------
// Generate grid using actual Boggle dice
//-------------------------------------------------------------------------
func randomSeed(using gk: GKRandom = GKRandomSource.sharedRandom()) -> String {
    var generator = GKRandomAdapter(gk)
    
    // Use the modern dice set - make a copy so we don't modify the original
    var availableDice = modernBoggleDice
    var result: [Character] = []
    var usedDice: [String] = []
    
    // Roll each die once (no repeats!)
    for i in 0..<16 {
        let dieIndex = Int.random(in: 0..<availableDice.count, using: &generator)
        let die = availableDice.remove(at: dieIndex)
        let face = die.randomElement(using: &generator)!
        result.append(face)
        usedDice.append(die)
        
        // Debug: print first few to check
        if i < 3 {
            print("Die \(i+1): \(die) → \(face)")
        }
    }
    
    // Convert to string and shuffle the positions
    result.shuffle(using: &generator)
    let finalResult = String(result)
    
    // Debug: check for duplicates
    let letterCounts = finalResult.reduce(into: [:]) { counts, letter in
        counts[letter, default: 0] += 1
    }
    let duplicates = letterCounts.filter { $0.value > 1 }
    if !duplicates.isEmpty {
        print("⚠️  Found duplicates in \(finalResult): \(duplicates)")
    }
    
    return finalResult
}

//-------------------------------------------------------------------------
// Much better playability check with realistic expectations
//-------------------------------------------------------------------------
func playableSeed(using gk: GKRandom = GKRandomSource.sharedRandom(),
                  attemptCap: Int = 200,
                  minWordCount: Int = 12) -> String {

    var bestCandidate = ""
    var bestScore = 0

    for attempt in 0..<attemptCap {
        let s = randomSeed(using: gk)

        // Basic sanity checks
        let vowels = s.filter { "AEIOU".contains($0) }.count
        let uniqueLetters = Set(s).count
        
        // More realistic constraints
        guard vowels >= 3 && vowels <= 8,     // Reasonable vowel count
              uniqueLetters >= 8              // Enough variety
        else { continue }

        // First decent grid is our fallback
        if bestCandidate.isEmpty { bestCandidate = s }

        let wordCount = WordFinder.shared.words(in: s).count
        
        // Print more details for first few attempts
        if attempt < 5 {
            let words = WordFinder.shared.words(in: s)
            print("Attempt \(attempt + 1): Seed \(s) ⇒ \(wordCount) words")
            if wordCount > 0 {
                print("  Words found: \(words.sorted().prefix(10))")
            }
        } else {
            print("Attempt \(attempt + 1): Seed \(s) ⇒ \(wordCount) words")
        }

        if wordCount >= minWordCount { return s }
        
        if wordCount > bestScore {
            bestScore = wordCount
            bestCandidate = s
        }
    }
    
    print("Best found after \(attemptCap) attempts: \(bestCandidate) with \(bestScore) words")
    return bestCandidate
}

//-------------------------------------------------------------------------
// Generate multiple grids and pick the best
//-------------------------------------------------------------------------
func bestOfMultipleGrids(count: Int = 50, using gk: GKRandom = GKRandomSource.sharedRandom()) -> String {
    var bestGrid = ""
    var bestScore = 0
    
    for i in 0..<count {
        let grid = randomSeed(using: gk)
        let wordCount = WordFinder.shared.words(in: grid).count
        
        if wordCount > bestScore {
            bestScore = wordCount
            bestGrid = grid
        }
        
        if i % 10 == 0 {
            print("Generated \(i) grids, best so far: \(bestScore) words")
        }
    }
    
    print("Final best grid: \(bestGrid) with \(bestScore) words")
    return bestGrid
}

//-------------------------------------------------------------------------
// Debug function to verify dice work correctly
//-------------------------------------------------------------------------
func testSingleGrid() {
    let grid = randomSeed()
    print("Generated grid: \(grid)")
    
    let letterCounts = grid.reduce(into: [:]) { counts, letter in
        counts[letter, default: 0] += 1
    }
    
    print("Letter counts:")
    for (letter, count) in letterCounts.sorted(by: { $0.key < $1.key }) {
        if count > 1 {
            print("  \(letter): \(count) ❌")
        } else {
            print("  \(letter): \(count)")
        }
    }
    
    let totalLetters = letterCounts.values.reduce(0, +)
    print("Total letters: \(totalLetters)")
    print("Unique letters: \(letterCounts.count)")
}

//-------------------------------------------------------------------------
// Quick test function to verify dice work
//-------------------------------------------------------------------------
func testDiceDistribution() {
    var letterCounts: [Character: Int] = [:]
    
    // Generate 1000 grids and count letters
    for _ in 0..<1000 {
        let grid = randomSeed()
        for char in grid {
            letterCounts[char, default: 0] += 1
        }
    }
    
    print("Letter distribution over 1000 grids:")
    for (letter, count) in letterCounts.sorted(by: { $0.key < $1.key }) {
        let percentage = Double(count) / 16000.0 * 100
        print("\(letter): \(count) times (\(String(format: "%.1f", percentage))%)")
    }
}
//-------------------------------------------------------------------------
// 4. Practice-mode ViewModel
//-------------------------------------------------------------------------
final class PracticeGameViewModel: GameViewModel {

    init() {
        super.init(seed: GridSeed(seed: "ABCDEFGHIJKLMNOP"))  // placeholder
        Task.detached(priority: .background) {
            let seed = playableSeed()                   // runs off-main
            await MainActor.run { [weak self] in
                self?.inject(seed: seed)
            }
        }
    }

    /// Swap in the real board & restart timer (MainActor context)
    @MainActor private func inject(seed seedString: String) {
        grid       = GridSeed(seed: seedString).grid
        selected   = []
        accepted   = []
        score      = 0
        timeLeft   = 90
        isFinished = false
        startTimer()
    }

    // Skip Firestore; update local practice PB
    override func finishGame() {
        isFinished = true
        timerCancellable?.cancel()     // note: `fileprivate` in base class

        let best = UserDefaults.standard.integer(forKey: "practiceBest")
        if score > best {
            UserDefaults.standard.set(score, forKey: "practiceBest")
        }
        showSummary = true
        Haptics.notify.notificationOccurred(.success)
    }
}
