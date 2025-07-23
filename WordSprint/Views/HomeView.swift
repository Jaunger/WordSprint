import SwiftUI
import FirebaseFirestore           // for profile save

/* MARK: - HomeView */
struct HomeView: View {
    // ───────────────── internal state
    @State private var vm          = HomeViewModel()
    @State private var editingNick = false
    @State private var draftNick   = Nickname.current
    @State private var showThemes  = false
    @State private var justLeveledTo: Int?


    // ───────────────── injected
    @EnvironmentObject private var tm: ThemeManager
    @EnvironmentObject private var sm: SoundManager
    @EnvironmentObject private var router: NavRouter

    var body: some View {
        NavigationStack (path:$router.path) {
            Group {
                switch (vm.loading, vm.seedError, vm.dailySeed) {

                case (true, _, _):
                    ProgressView("Loading Daily Puzzle…")
                    

                case (_, let err?, _):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(err).multilineTextAlignment(.center)
                    }

                case (false, _, let seed?):
                    mainMenu(seed: seed)

                default:
                    EmptyView()
                }
            }
            .task {                                  
                await vm.loadProfile(force: true)
            }
            .soundToolbarItem()
            .padding()
        }

        .background(tm.theme.background.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .xpChanged)) { _ in
            Task { await vm.loadProfile(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .leveledUp)) { note in
            if let new = note.userInfo?["new"] as? Int {
                justLeveledTo = new
                Task { await vm.loadProfile(force: true) }
            }
        }
        .overlay(alignment: .top) {
            if let lvl = justLeveledTo {
                LevelUpBanner(level: lvl)
                    .transition(.opacity)
            }
        }

    }
}

// MARK: - Main menu
private extension HomeView {
    @ViewBuilder
    func mainMenu(seed: GridSeed) -> some View {
        VStack(spacing: 20) {
            
            /* ── Greeting & Theme ── */
            HStack(spacing: 16) {
                Button {
                    draftNick = Nickname.current; editingNick = true
                } label: {
                    HStack {
                        Text("Hey \(Nickname.current)")
                        Image(systemName: "pencil")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundColor(tm.theme.buttonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
   
                }
                Spacer()
                Button("Theme") { showThemes = true }
                    .font(.callout.weight(.semibold))
                    .foregroundColor(tm.theme.buttonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

            }
            
            .alert("Edit Nickname", isPresented: $editingNick) {
                TextField("Nickname", text: $draftNick)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) { }
                Button("Save") { saveNickname() }
            }
            .sheet(isPresented: $showThemes) {
                NavigationStack { ThemePicker() }
                    .environmentObject(tm)
                    .environmentObject(vm)
            }
            
            Text("WordSprint")
                .font(.largeTitle.bold())
                .foregroundColor(tm.theme.text)
                .padding(.top, 4)
                .padding(.bottom, 128)
            
            /* ── Daily ── */
            NavigationLink(value: "daily") {
                Text("Play Daily")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ThemedButtonStyle(prominent: true))
            
            /* ── Practice ── */
            NavigationLink(value: "practice") {
                Text("Practice")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ThemedButtonStyle(prominent: false))
            
            /* ── Leaderboard ── */
            NavigationLink(value: "leaders") {
                Label("Leaderboard", systemImage: "trophy")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ThemedButtonStyle(prominent: false))
            
            /* ── Practice PB ── */
            if UserDefaults.standard.integer(forKey: "practiceBest") > 0 {
                Text("Practice PB: \(UserDefaults.standard.integer(forKey: "practiceBest")) pts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            /* ── Streak & XP ── */
            if let p = vm.profile {
                VStack(spacing: 4) {
                    Text("🔥 Streak \(p.streak)  •  Lv \(p.level)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    XPBar(xp: p.xp % 300, cap: 300)
                        .tint(tm.theme.tile)   // optional; bar uses accentColor otherwise
                }
                .padding(.top, 8)
            }
        }
        .navigationDestination(for: String.self) { tag in
            switch tag {
            case "daily":
                GameView(seed: seed, alreadyClearedToday: vm.profile?.playedTodayIL() == true)
                    .environmentObject(tm)              // ← inject
                    .environmentObject(sm)
                    .environmentObject(router)

            case "practice":
                PracticeGameView()
                    .environmentObject(tm)
                    .environmentObject(sm)
                    .environmentObject(router)


            case "leaders":
                LeaderboardView()
                    .environmentObject(tm)

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity,          // ← fills width
               maxHeight: .infinity,         // ← fills height
               alignment: .top)              // ← stick to top
        .padding(.horizontal, 32)
    }

    // MARK: helper
    func saveNickname() {
        let trimmed = draftNick.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        Nickname.current = trimmed
        let model = vm        // capture reference
        Task { await model.reloadProfileNick(trimmed) }
    }
}

struct XPBar: View {
    let xp: Int          // current XP inside this level (0..<cap)
    let cap: Int         // XP needed to level up

    @State private var progress: CGFloat = 0   // 0...1 width
    @State private var flashing = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))

                Capsule()
                    .fill(flashing ? Color.yellow : Color.accentColor)
                    .frame(width: geo.size.width * progress)
                    .animation(.easeOut(duration: 0.6), value: progress)
                    .animation(.linear(duration: 0.15), value: flashing)
            }
        }
        .frame(height: 8)
        .onAppear {
            // initial fill
            progress = min(CGFloat(xp) / CGFloat(cap), 1)
        }
        .onChange(of: xp) { oldXP, newXP in
            // Simple increase
            guard cap > 0 else { return }
            let newProg = min(CGFloat(newXP) / CGFloat(cap), 1)

            if newXP < oldXP {
                // We wrapped (leveled). Animate to 100%, flash, reset, then to remainder
                withAnimation(.easeOut(duration: 0.35)) {
                    progress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                    flashing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        flashing = false
                        progress = 0
                        withAnimation(.easeOut(duration: 0.5)) {
                            progress = newProg
                        }
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.6)) {
                    progress = newProg
                }
            }
        }
    }
}

struct LevelUpBanner: View {
    let level: Int
    @State private var visible = true

    var body: some View {
        VStack {
            if visible {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Level \(level)!")
                        .bold()
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { visible = false }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .allowsHitTesting(false)
    }
}

extension PlayerProfile {
    func playedTodayIL() -> Bool {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ILTime.tz
        let last = Date(timeIntervalSince1970: TimeInterval(lastPlayed.seconds))
        return cal.isDate(last, inSameDayAs: Date())
    }
}
