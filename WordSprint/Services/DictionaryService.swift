import Foundation
import Compression   // for .gz loading

enum DictionaryService {
    private(set) static var wordSet: Set<String> = []
    
    static func load() {
        if wordSet.isEmpty {
            guard let url = Bundle.main.url(forResource: "popular", withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else { fatalError("popular.txt missing") }
            
            wordSet = Set(
                text.split(separator: "\n").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                }
                    .filter { word in
                        guard word.count >= 3,
                              word.allSatisfy({ $0.isLetter && $0.isASCII && $0.isUppercase }) else { return false }
                        
                        let classicVowelCount = word.filter { "AEIOU".contains($0) }.count
                        let hasVowel = classicVowelCount > 0 || word.contains("Y")   // <- allow Y-only words
                        let hasConsonant = word.contains { !"AEIOUY".contains($0) }  // at least one consonant
                        
                        return hasVowel && hasConsonant
                    }
            )
            print("Dictionary loaded: \(wordSet.count) words")
        }
        WordFinder.warmUp()
    }
    
    static func isValid(_ word: String) -> Bool {
        wordSet.contains(word.uppercased())
    }
}


