# WordSprint

A daily word-finding game built with SwiftUI and Firebase, inspired by Boggle-style gameplay. Players race against time to find words on a 4x4 grid, competing on daily and weekly leaderboards.

## 🎮 Game Features

### Core Gameplay
- **Daily 4x4 Word Grid**: Each day features a unique, deterministic puzzle
- **90-Second Timer**: Race against time to find as many words as possible
- **Touch & Drag**: Intuitive word selection by dragging across adjacent letters
- **Real-time Validation**: Instant feedback on valid/invalid words
- **Score System**: Points based on word length and complexity

### Social & Competitive Features
- **Daily Leaderboards**: Compare scores with players worldwide
- **Weekly Leaderboards**: Cumulative weekly scoring system
- **Player Profiles**: Track streaks, XP, and level progression
- **Customizable Nicknames**: Personalize your gaming identity

### Progression System
- **Experience Points**: Earn XP based on your score (score × 10)
- **Level System**: Unlock new features as you level up (300 XP per level)
- **Streak Tracking**: Maintain daily playing streaks
- **Theme Unlocks**: Unlock new visual themes at higher levels

### Visual & Audio Experience
- **Multiple Themes**: Classic, Dusk (level 3), and Neon (level 6) themes
- **Sound Effects**: Immersive audio feedback with BGM/SFX support
- **Haptic Feedback**: Tactile responses for enhanced gameplay
- **Smooth Animations**: Polished UI transitions and effects

### Practice Mode
- **Unlimited Play**: Practice with playability-checked seeds
- **No Time Pressure**: Focus on improving your word-finding skills
- **Optimized Boards**: Ensures each practice board has plenty of valid words
- **Background Generation**: Seeds are pre-generated for smooth experience

## 📱 Screenshots

| Main Menu | Daily Game |
|-----------|------------|
| <img width="45%" alt="Main Menu" src="https://github.com/user-attachments/assets/a20f1f16-abbf-4b21-911a-92620a04c3c8" /> | <img width="45%" alt="Daily Game" src="https://github.com/user-attachments/assets/13d2a02d-b5e2-4efe-8238-962e4fcf57f3" /> |

| Daily Game (Cleared) | Game Summary |
|----------------------|--------------|
| <img width="45%" alt="Daily Game Cleared" src="https://github.com/user-attachments/assets/f5c98018-a085-45bc-b4bd-1f3c7f1e3381" /> | <img width="45%" alt="Game Summary" src="https://github.com/user-attachments/assets/1d86ed4f-7b4b-4507-b233-3f38e4537891" /> |

| Leaderboard | Theme Selection |
|-------------|----------------|
| <img width="45%" alt="Leaderboard" src="https://github.com/user-attachments/assets/a785f134-c3e8-4840-af7b-6f572faccef5" /> | <img width="45%" alt="Theme Selection" src="https://github.com/user-attachments/assets/ca4fc4cf-61c2-4b30-b39d-c928b9b7bda4" /> |


## 🏗️ Technical Architecture

### Frontend
- **SwiftUI**: Modern declarative UI framework
- **MVVM Architecture**: Clean separation of concerns
- **Combine**: Reactive programming for state management
- **Core Animation**: Smooth transitions and effects

### Backend & Data
- **Firebase Firestore**: Real-time database for scores and profiles
- **Firebase Analytics**: Usage tracking and insights
- **Deterministic Seeds**: Daily puzzles generated from consistent seeds
- **Dictionary Service**: Curated word list with 25,000+ popular words

### Game Logic
- **WordFinder**: Efficient trie-based word search algorithm
- **Grid Validation**: Ensures all daily boards are playable
- **Score Calculation**: Balanced scoring system
- **Time Management**: Precise countdown timer

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Apple Developer Account (for device testing)
- Firebase project setup

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/WordSprint.git
   cd WordSprint
   ```

2. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Firestore Database
   - Download `GoogleService-Info.plist` and add it to the project root
   - Configure Firestore security rules for your use case

3. **Open in Xcode**
   ```bash
   open WordSprint.xcodeproj
   ```

4. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd+R` to build and run

### Project Structure

```
WordSprint/
├── Views/                 # SwiftUI view components
├── ViewModels/            # MVVM view models  
├── Services/              # Business logic and data
├── Assets.xcassets/       # Theme colors and assets
├── Theme.swift            # Theme management
├── WordFinder.swift       # Word search algorithm
└── WordSprintApp.swift    # App entry point
```

## 🎯 Game Rules

1. **Word Formation**: Drag across adjacent letters (including diagonals) to form words
2. **Minimum Length**: Words must be at least 3 letters long
3. **Dictionary**: Only words from the curated popular word list are valid
4. **Scoring**: Longer words earn more points
5. **Daily Limit**: One attempt per day for the daily puzzle
6. **Practice Mode**: Unlimited attempts with different boards

## 🔧 Configuration

### Firebase Setup
The app requires Firebase for:
- Daily puzzle seeds (`puzzleSeeds/{dateID}`)
- Leaderboard data (`dailies/{dateID}/scores`, `weekly/{weekID}/scores`)
- Player profiles and progression (`profiles/{nickname}`)
- Analytics tracking

### Dictionary
The game uses a curated list of ~25,000 popular English words, filtered for:
- Minimum 3 letters
- Contains both vowels and consonants
- ASCII letters only
- Popular/common usage

## 🎨 Customization

### Themes
- **Classic**: Clean, traditional design (unlocked by default)
- **Dusk**: Dark, sophisticated theme (unlock at level 3)
- **Neon**: Vibrant, colorful theme (unlock at level 6)

### Sound Settings
- **Toggle Sound**: Global sound on/off switch in toolbar

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🙏 Acknowledgments

- Inspired by classic word games like Boggle
- Built with modern iOS development practices
- Uses Firebase for scalable backend services
- Dictionary curated from popular English words

## 📞 Support

For questions, issues, or feature requests, please:
- Open an issue on GitHub
- Check the existing documentation
- Review the code comments for implementation details

---

**WordSprint** - Challenge your vocabulary, compete with friends, and improve your word-finding skills daily! 🎯📚
