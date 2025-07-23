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
            //let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")

            wordSet = Set(
                text.split(separator: "\n").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                }
                    .filter { word in
                        guard word.count >= 3,
                              word.allSatisfy({ $0.isLetter && $0.isASCII && $0.isUppercase }) else { return false }
                        let vowels = word.filter { "AEIOU".contains($0) }.count
                        return vowels >= 1 && vowels < word.count      // at least one vowel & one consonant
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


