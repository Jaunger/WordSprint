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


// MARK: Tuned seed scoring
private let scoringDepthLimit: Int? = 7   // shallow enumeration for speed

private struct SeedEval {
    let seed: String
    let wordCount: Int
    let longCount: Int
    let uniqueStarts: Int
    let avgLen: Double
    let duplicatePenalty: Int
    var score: Double {
        Double(wordCount) * 4.5 +
        Double(longCount) * 7.0 +
        Double(uniqueStarts) * 2.2 +
        avgLen * 1.2 -
        Double(duplicatePenalty) * 3.0
    }
}

/// Deterministic variant (pass a GKRandom)
func playableSeed<R: GKRandom>(
    using gk: R,
    attempts: Int = 140,
    earlyAcceptWordCount: Int = 34
) -> String {

    var best: SeedEval?

    for _ in 0..<attempts {
        // reuse your dice-based generator
        let seed = randomSeed(using: gk)

        // Cheap constraints
        let freq = Dictionary(grouping: seed, by: { $0 }).mapValues(\.count)
        if freq.values.contains(where: { $0 > 4 }) { continue }
        let vowels = seed.filter { "AEIOU".contains($0) }.count
        if !(4...7).contains(vowels) { continue }
        if freq.count < 9 { continue }
        let rares = seed.filter { "QJXZ".contains($0) }
        if Set(rares).count > 2 { continue }

        // Depth-limited words
        let words = WordFinder.shared.words(in: seed, depthLimit: scoringDepthLimit)
        let total = words.count
        if total == 0 { continue }

        let longCount = words.filter { $0.count >= 5 }.count
        let starts = Set(words.compactMap(\.first))
        let avgLen = Double(words.reduce(0) { $0 + $1.count }) / Double(total)
        let dupPenalty = freq.values.reduce(0) { $0 + max(0, $1 - 2) }

        if total >= earlyAcceptWordCount {
            return seed
        }

        let eval = SeedEval(seed: seed,
                            wordCount: total,
                            longCount: longCount,
                            uniqueStarts: starts.count,
                            avgLen: avgLen,
                            duplicatePenalty: dupPenalty)

        if let b = best {
            if eval.score > b.score { best = eval }
        } else {
            best = eval
        }
    }

    return best?.seed ?? randomSeed(using: gk)
}

/// Convenience random variant (practice)
func playableSeed(
    attempts: Int = 120,
    earlyAcceptWordCount: Int = 34
) -> String {
    playableSeed(using: GKRandomSource.sharedRandom(),
                      attempts: attempts,
                      earlyAcceptWordCount: earlyAcceptWordCount)
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
    private static var cachedSeed: String?
    private var isReloading = false
    private var suppressSummaryOnce = false
    @Published private(set) var loadingSeed = false
    private var isGenerating = false
    private let practiceDuration = 90

    init() {
        if let cached = Self.cachedSeed {
            // We already have a board — don’t generate again
            super.init(seed: GridSeed(seed: cached), isPractice: true)
        } else {
            // First time ever: show placeholder and go fetch
            super.init(seed: GridSeed(seed: "################"), isPractice: true)
            suspendForReload()
            loadingSeed = true
            generate(cacheResult: true)
        }
    }

    func newBoard() {
        // only one reload at a time
        guard !loadingSeed else { return }
        loadingSeed = true
        isReloading = true
        Self.cachedSeed = nil           // clear cache to allow generate
        suspendForReload()
        setSeed(d: GridSeed(seed: "################"))
        generate(cacheResult: true)
    }

    private func generate(cacheResult: Bool) {
        // bail if we’re already mid-generate
        guard !isGenerating else { return }
        isGenerating = true

        Task.detached(priority: .userInitiated) {
            let seedString = playableSeed()
            let seed = GridSeed(seed: seedString)
            await MainActor.run {
                if cacheResult {
                    Self.cachedSeed = seedString
                }
                self.isReloading = false
                self.loadingSeed = false
                self.reset(with: seed, time: self.practiceDuration)
                self.isGenerating = false      // allow future generates (via newBoard)
            }
        }
    }

    override func finishGame() {
        if isFinished { return }
        let prevSuppress = suppressFinishEffects
        super.finishGame()          // base handles sound/summary if not suppressed

        // Practice-only PB (after base sets isFinished)
        let best = UserDefaults.standard.integer(forKey: "practiceBest")
        if score > best { UserDefaults.standard.set(score, forKey: "practiceBest") }

        Task {
            let nick = Nickname.current
            let practiceGrant = XPGrant(amount: score * 10, key: "practice")

            _ = await XPService.award(practiceGrant, to: nick)
        }
        
        // If we suppressed, also clear showSummary just in case base set it
        if prevSuppress {
            showSummary = false
        }
    }
}

// MARK: Depth-limited evaluation support (extension for WordFinder)
extension WordFinder {
    func words(in seed: String, depthLimit: Int?) -> Set<String> {
        guard seed.count == 16 else { return [] }
        let grid = Array(seed)
        var results = Set<String>(), visited = Array(repeating: false, count: 16)
        var buffer = [Character]()

        func dfs(_ idx: Int, _ node: Node) {
            visited[idx] = true
            buffer.append(grid[idx])
            if node.isWord { results.insert(String(buffer)) }
            if let limit = depthLimit, buffer.count >= limit {
                visited[idx] = false
                buffer.removeLast()
                return
            }
            let (r, c) = (idx / 4, idx % 4)
            for dr in -1...1 {
                for dc in -1...1 where !(dr == 0 && dc == 0) {
                    let nr = r + dr, nc = c + dc
                    guard (0..<4).contains(nr), (0..<4).contains(nc) else { continue }
                    let nIdx = nr * 4 + nc
                    guard !visited[nIdx] else { continue }
                    if let next = trie.children[grid[nIdx]] { dfs(nIdx, next) }
                }
            }
            visited[idx] = false
            buffer.removeLast()
        }

        for i in 0..<16 {
            if let first = trie.children[grid[i]] { dfs(i, first) }
        }
        return results
    }
}


