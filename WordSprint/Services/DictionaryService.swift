import Foundation
import Compression   // for .gz loading

enum DictionaryService {
    private(set) static var wordSet: Set<String> = []

    static func load() {
        if wordSet.isEmpty {
            guard let url = Bundle.main.url(forResource: "popular", withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else { fatalError("words.txt missing") }

            // Keep only pure alphabetic words with at least 1 vowel and 1 consonant
            let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")

            wordSet = Set(
                text.split(separator: "\n").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                }
                .filter { word in
                    guard word.count >= 3 else { return false }
                    guard word.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
                    let vowels     = word.filter { "AEIOU".contains($0) }.count
                    let consonants = word.count - vowels
                    return vowels > 0 && consonants > 0            // kills AAA, ADA, AZS
                }
            )
            print("Dictionary loaded: \(wordSet.count) words")
        }
        WordFinder.warmUp()                // ← guarantees trie exists right now
    }
    
    static func isValid(_ word: String) -> Bool {
        wordSet.contains(word)
    }
}


