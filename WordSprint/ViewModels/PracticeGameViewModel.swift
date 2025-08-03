//
//  PracticeGameViewModel.swift
//  WordSprint
//

import Foundation
import GameplayKit

// MARK: - GKRandom → RNG bridge
struct GKRandomAdapter: RandomNumberGenerator {
    private var base: GKRandom
    init(_ base: GKRandom) { self.base = base }
    mutating func next() -> UInt64 { UInt64(bitPattern: Int64(base.nextInt())) }
}

// MARK: - Modern Boggle dice (post-1987)
private let modernBoggleDice = [
    "AAEEGN", "ELRTTY", "AOOTTW", "ABBJOO", "EHRTVW", "CIMOTU",
    "DISTTY", "EIOSST", "DELRVY", "ACHOPS", "HIMNQU", "EEINSU",
    "EEGHNW", "AFFKPS", "HLNNRZ", "DEILRX"
]

// MARK: - Difficulty
enum Difficulty {
    case easy, normal, hard

    var attempts: Int {
        switch self {
        case .easy:   return 80
        case .normal: return 140
        case .hard:   return 220
        }
    }
    var earlyAcceptWordCount: Int {
        switch self {
        case .easy:   return 20
        case .normal: return 34
        case .hard:   return 48
        }
    }
    /// depth to use in the FAST pass
    var shallowDepth: Int { 7 }
    /// how many top shallow candidates to fully rescore
    var finalists: Int {
        switch self {
        case .easy:   return 3
        case .normal: return 5
        case .hard:   return 7
        }
    }
}

// MARK: - Seed generation

/// Roll 16 dice, one face each, shuffle board.
private func randomSeed(using gk: GKRandom = GKRandomSource.sharedRandom()) -> String {
    var generator = GKRandomAdapter(gk)
    var availableDice = modernBoggleDice
    var result: [Character] = []

    for _ in 0..<16 {
        let dieIndex = Int.random(in: 0..<availableDice.count, using: &generator)
        let die = availableDice.remove(at: dieIndex)
        let face = die.randomElement(using: &generator)!
        result.append(face)
    }
    result.shuffle(using: &generator)
    return String(result)
}

// MARK: - Metrics & scoring

private struct FastEval {
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

private struct FullMetrics {
    let seed: String
    let wordCount: Int
    let longCount: Int
    let maxLen: Int
    let uniqueStarts: Int
    let prefix2: Int
    let dupPenalty: Int
    let entropy: Double
}

private func fullScore(_ m: FullMetrics) -> Double {
    0.45 * Double(m.wordCount) +
    0.25 * Double(m.longCount) +
    0.08 * Double(m.maxLen) +
    0.08 * Double(m.uniqueStarts) +
    0.06 * Double(m.prefix2) +
    0.08 * m.entropy -
    0.20 * Double(m.dupPenalty)
}

private func entropy(of seed: String) -> Double {
    let n = Double(seed.count)
    let freq = Dictionary(grouping: seed, by: { $0 }).mapValues { Double($0.count) / n }
    return -freq.values.reduce(0) { $0 + $1 * log2($1) }
}

private func twoLetterPrefixCount(_ words: Set<String>) -> Int {
    var s = Set<String>()
    s.reserveCapacity(words.count)
    for w in words where w.count >= 2 {
        s.insert(String(w.prefix(2)))
    }
    return s.count
}

// MARK: - Public entry points

/// Deterministic (pass your own GKRandom) – used for dailies if you want.
func playableSeed<R: GKRandom>(
    using gk: R,
    difficulty: Difficulty = .normal
) -> String {
    return bestSeedInternal(using: gk, difficulty: difficulty)
}

/// Random convenience (practice).
func playableSeed(difficulty: Difficulty = .normal) -> String {
    bestSeedInternal(using: GKRandomSource.sharedRandom(), difficulty: difficulty)
}

// Core
private func bestSeedInternal<R: GKRandom>(
    using gk: R,
    difficulty: Difficulty
) -> String {

    var bestFast: [FastEval] = []
    bestFast.reserveCapacity(difficulty.finalists)

    // FAST PASS (shallow)
    for _ in 0..<difficulty.attempts {
        let seed = randomSeed(using: gk)

        // Quick constraints
        let freq = Dictionary(grouping: seed, by: { $0 }).mapValues(\.count)
        if freq.values.contains(where: { $0 > 4 }) { continue }
        let vowels = seed.filter { "AEIOU".contains($0) }.count
        if !(4...7).contains(vowels) { continue }
        if freq.count < 9 { continue }
        let rares = seed.filter { "QJXZ".contains($0) }
        if Set(rares).count > 2 { continue }

        let words = WordFinder.shared.words(in: seed, depthLimit: difficulty.shallowDepth)
        let total = words.count
        if total == 0 { continue }

        let longCount = words.filter { $0.count >= 5 }.count
        let starts = Set(words.compactMap(\.first))
        let avgLen = Double(words.reduce(0) { $0 + $1.count }) / Double(total)
        let dupPenalty = freq.values.reduce(0) { $0 + max(0, $1 - 2) }

        // Early accept very good fast results
        if total >= difficulty.earlyAcceptWordCount {
            return seed
        }

        let eval = FastEval(seed: seed,
                            wordCount: total,
                            longCount: longCount,
                            uniqueStarts: starts.count,
                            avgLen: avgLen,
                            duplicatePenalty: dupPenalty)

        // keep a small heap-like top list
        if bestFast.count < difficulty.finalists {
            bestFast.append(eval)
            bestFast.sort { $0.score > $1.score }
        } else if let last = bestFast.last, eval.score > last.score {
            bestFast.removeLast()
            bestFast.append(eval)
            bestFast.sort { $0.score > $1.score }
        }
    }

    // If fast pass found nothing, just return a random board
    guard !bestFast.isEmpty else { return randomSeed(using: gk) }

    // FULL PASS (no depth limit) for the best K
    var bestFinal: (seed: String, score: Double)? = nil

    for cand in bestFast {
        let allWords = WordFinder.shared.words(in: cand.seed, depthLimit: nil)
        guard !allWords.isEmpty else { continue }

        let freq = Dictionary(grouping: cand.seed, by: { $0 }).mapValues(\.count)
        let m = FullMetrics(
            seed: cand.seed,
            wordCount: allWords.count,
            longCount: allWords.filter { $0.count >= 5 }.count,
            maxLen: allWords.map(\.count).max() ?? 0,
            uniqueStarts: Set(allWords.compactMap(\.first)).count,
            prefix2: twoLetterPrefixCount(allWords),
            dupPenalty: freq.values.reduce(0) { $0 + max(0, $1 - 2) },
            entropy: entropy(of: cand.seed)
        )

        let s = fullScore(m)
        if bestFinal == nil || s > bestFinal!.score {
            bestFinal = (m.seed, s)
        }
    }

    return bestFinal?.seed ?? bestFast.first!.seed
}

// MARK: - Background seed pool

actor SeedPool {
    static let shared = SeedPool()

    private var cache: [String] = []

    /// Return a cached seed if we have one, otherwise generate one.
    func popOrGenerate(difficulty: Difficulty) -> String {
        if !cache.isEmpty { return cache.removeLast() }
        return playableSeed(difficulty: difficulty)
    }

    /// Make sure we have `target` items ready for next time.
    func ensure(target: Int = 2, difficulty: Difficulty = .normal) {
        while cache.count < target {
            let s = playableSeed(difficulty: difficulty)
            cache.append(s)
        }
    }
}

// MARK: - PracticeGameViewModel

final class PracticeGameViewModel: GameViewModel, ObservableObject {

    private static var cachedSeed: String?
    @Published private(set) var loadingSeed = false

    private var isGenerating = false
    private let practiceDuration = 90
    private let difficulty: Difficulty = .normal   // change if you want a toggle

    init() {
        if let cached = Self.cachedSeed {
            let seed = GridSeed(seed: cached)
            super.init(seed: seed, isPractice: true)
            reset(with: seed, time: practiceDuration)
            loadingSeed = false
        } else {
            super.init(seed: GridSeed(seed: "################"), isPractice: true)
            suspendForReload()
            loadingSeed = true
            generate(cacheResult: true)
        }

        Task.detached(priority: .background) {
            await SeedPool.shared.ensure(target: 2, difficulty: self.difficulty)
        }    }

    func newBoard() {
        guard !loadingSeed else { return }
        loadingSeed = true
        Self.cachedSeed = nil
        suspendForReload()
        setSeed(d: GridSeed(seed: "################"))
        generate(cacheResult: true)
    }

    private func generate(cacheResult: Bool) {
        guard !isGenerating else { return }
        isGenerating = true

        Task.detached(priority: .userInitiated) {
            let seedString = playableSeed()
            debugDumpSeed(seedString, depthLimit: nil)  
            let seed = GridSeed(seed: seedString)
            await MainActor.run {
                if cacheResult { Self.cachedSeed = seedString }
                self.loadingSeed = false
                self.isGenerating = false
                self.reset(with: seed, time: self.practiceDuration)
            }
        }
    }

    override func finishGame() {
        if isFinished { return }
        let prevSuppress = suppressFinishEffects
        super.finishGame()

        let best = UserDefaults.standard.integer(forKey: "practiceBest")
        if score > best { UserDefaults.standard.set(score, forKey: "practiceBest") }

        Task {
            let nick = Nickname.current
            let practiceGrant = XPGrant(amount: score * 10, key: "practice")
            _ = await XPService.award(practiceGrant, to: nick)
        }

        Self.cachedSeed = nil
        if prevSuppress { showSummary = false }
    }

    override func reset(with seed: GridSeed, time: Int = 90) {
        super.reset(with: seed, time: time)
    }

    override func startTimer() {
        if timer != nil {
            print("⛔️ timer already running for \(Unmanaged.passUnretained(self).toOpaque())")
            return
        }
        super.startTimer()
    }
}

// MARK: - Depth-limited evaluation support (WordFinder)
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
