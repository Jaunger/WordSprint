import SwiftUI
import FirebaseFirestore           // for profile save

/* MARK: - HomeView */
struct HomeView: View {
    // ───────────────── internal state
    @State private var vm          = HomeViewModel()
    @State private var editingNick = false
    @State private var draftNick   = Nickname.current
    @State private var showThemes  = false

    // ───────────────── injected
    @EnvironmentObject private var tm: ThemeManager

    var body: some View {
        NavigationStack {
            Group {
                switch (vm.loading, vm.errorMessage, vm.dailySeed) {

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
            .padding()
            .task { vm.loadProfile() }          // once at launch
        }
        .background(tm.theme.background.ignoresSafeArea())

    }
}

// MARK: - Main menu
private extension HomeView {
    @ViewBuilder
    func mainMenu(seed: GridSeed) -> some View {
        VStack(spacing: 20) {
            
            /* ── Greeting & Theme ── */
            HStack {
                Text("Hey \(Nickname.current)").font(.headline)
                Button {
                    draftNick = Nickname.current
                    editingNick = true
                } label: {
                    Image(systemName: "pencil")
                }
                Spacer()
                Button("Theme") { showThemes = true }
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
            }
            
            Text("WordSprint")
                .font(.largeTitle.bold())
                .padding(.top, 4)
                .padding(.bottom, 128)
            
            /* ── Daily ── */
            NavigationLink(value: "daily") {
                Text("Play Daily")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            /* ── Practice ── */
            NavigationLink(value: "practice") {
                Text("Practice")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            /* ── Leaderboard ── */
            NavigationLink(value: "leaders") {
                Label("Leaderboard", systemImage: "trophy")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
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
                        .tint(tm.theme.tile)
                }
                .padding(.top, 8)
            }
        }
        .navigationDestination(for: String.self) { tag in
            switch tag {
            case "daily":
                GameView(seed: seed)
                    .environmentObject(tm)              // ← inject

            case "practice":
                PracticeGameView()
                    .environmentObject(tm)

            case "leaders":
                LeaderboardView()                       // uses ThemeManager? inject if needed
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

// MARK: - XP bar component
private struct XPBar: View {
    let xp: Int, cap: Int
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .frame(width: geo.size.width * min(CGFloat(xp)/CGFloat(cap), 1))
            }
        }
        .frame(height: 8)
    }
}
