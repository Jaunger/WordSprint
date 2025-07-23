import Foundation

/// Thread-safe, once-only Boggle-style word finder.
final class WordFinder {

    // MARK: - Singleton handle
    static let shared = WordFinder()        // ← one global instance
    private init() {    // ← build once, synchronously, on first access
         buildTrie()
     }
    
    static func warmUp() { _ = WordFinder.shared }

    // MARK: - Public API


    /// Return all valid words in a 16-letter uppercase seed.
    func words(in seed: String) -> Set<String> {
        guard seed.count == 16 else { return [] }
        let grid = Array(seed)                   // [Character]
        var results = Set<String>(), visited = Array(repeating: false, count: 16)
        var buffer  = [Character]()

        func dfs(_ idx: Int, _ node: Node) {
            visited[idx] = true
            buffer.append(grid[idx])
            if node.isWord { results.insert(String(buffer)) }

            let (r, c) = (idx / 4, idx % 4)
            for dr in -1...1 {
                for dc in -1...1 where !(dr == 0 && dc == 0) {
                    let nr = r + dr, nc = c + dc
                    guard (0..<4).contains(nr), (0..<4).contains(nc) else { continue }
                    let nIdx = nr * 4 + nc
                    guard !visited[nIdx] else { continue }
                    if let next = node.children[grid[nIdx]] { dfs(nIdx, next) }
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

    /// For debug (“root children count”).
    var rootChildCount: Int { trie.children.count }

    // MARK: - Private trie
    // MARK: - Private trie
    class Node { var children = [Character: Node](); var isWord = false }
    let trie = Node()

    private func buildTrie() {
        guard !DictionaryService.wordSet.isEmpty else {
            fatalError("Dictionary must load before WordFinder")
        }

        // Populate the trie once
        for word in DictionaryService.wordSet where word.count >= 3 {
            insert(word: word)                     // ← USE the helper
        }

        precondition(trie.children.count > 0, "Trie failed to build")
        print("✅ WordFinder trie built with \(trie.children.count) root letters")
    }

    // Correct insert(word:) already present; no changes needed
    private func insert(word: String) {
        var node = trie
        for ch in word {
            if let next = node.children[ch] {
                node = next
            } else {
                let newNode = Node()
                node.children[ch] = newNode        // store
                node = newNode
            }
        }
        node.isWord = true
    }
}
