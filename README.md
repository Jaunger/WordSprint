# WordSprint

Daily 4x4 word sprint game (SwiftUI + Firebase).

## Features
- Deterministic daily board (Firestore seed fallback)
- Practice mode with playability-checked seeds
- Daily & weekly leaderboards (Firestore)
- Streak + XP (score * 10) + theme picker
- Clean dictionary (popular / ENABLE1 filtered)

## Roadmap (In Progress)
- Leaderboard polish (medals, rank chip, pull-to-refresh)
- Seed generator duplicate & bias tuning
- More themes / button + text style polish
- Share card export + sound toggle

## Setup
1. Clone repo
2. Add `GoogleService-Info.plist` (not committed) to project root.
3. Run `pod install` or `swift build` (if you add dependencies later).
4. Open `WordSprint.xcodeproj` (or workspace) and run.

## License
MIT
