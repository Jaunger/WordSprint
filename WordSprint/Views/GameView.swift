import SwiftUI
import Combine

enum Haptics {
    static let soft   = UIImpactFeedbackGenerator(style: .soft)
    static let rigid  = UIImpactFeedbackGenerator(style: .rigid)
    static let notify = UINotificationFeedbackGenerator()
    static func prepare() { soft.prepare(); rigid.prepare(); notify.prepare() }
    static func success() { notify.notificationOccurred(.success) }
    static func warning() { notify.notificationOccurred(.warning) }
    static func error()   { notify.notificationOccurred(.error) }
}

struct GameView: View {
    // MARK: - State
    @State private var viewModel: GameViewModel
    @State private var gridDropped = false

    // daily lock state
    @State private var alreadyDoneToday = false
    @State private var secsLeft = ILTime.secondsUntilTomorrow()
    @State private var countdownCancellable: AnyCancellable?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sm: SoundManager
    @EnvironmentObject private var tm: ThemeManager
    @EnvironmentObject private var router: NavRouter

    // MARK: - Inits
    init(seed: GridSeed, alreadyClearedToday: Bool = false) {
        let vm = GameViewModel(seed: seed)
        if alreadyClearedToday { vm.freeze() }          // timer never runs
        _viewModel        = State(wrappedValue: vm)
        _alreadyDoneToday = State(initialValue: alreadyClearedToday)
    }
    init(seed: GridSeed) {
        _viewModel = State(wrappedValue: GameViewModel(seed: seed))
    }

    init(viewModel: GameViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    // MARK: - Helpers
    private func point(in geo: GeometryProxy, from location: CGPoint) -> GameViewModel.GridPoint? {
        let size = geo.size.width / 4
        let r = Int(location.y / size)
        let c = Int(location.x / size)
        guard (0..<4).contains(r), (0..<4).contains(c) else { return nil }
        return .init(row: r, col: c)
    }

    private var isLoadingPractice: Bool {
        let flat = viewModel.grid.flatMap { $0 }
        return flat.count == 16 && flat.allSatisfy { $0 == "#" }
    }

    // MARK: - Body
    var body: some View {
        ZStack {                                  // ← allows overlay
            VStack(spacing: 12) {

                if !isLoadingPractice {
                    Text("Time: \(viewModel.timeLeft)")
                        .font(.title2)
                        .monospacedDigit()
                        .transition(.opacity)
                }

                // GRID / LOADING
                ZStack {
                    if isLoadingPractice {
                        VStack(spacing: 16) {
                            ProgressView("Building board…")
                                .controlSize(.large)
                            Text("Optimizing letters for playable words")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    } else {
                        GeometryReader { geo in
                            let tileSize = geo.size.width / 4
                            ZStack {
                                ForEach(0..<4, id: \.self) { r in
                                    ForEach(0..<4, id: \.self) { c in
                                        let ch = viewModel.grid[r][c]
                                        TileView(char: ch,
                                                 highlighted: viewModel.selected
                                                    .contains(.init(row: r, col: c)))
                                        .position(x: (CGFloat(c) + 0.5) * tileSize,
                                                  y: (CGFloat(r) + 0.5) * tileSize)
                                    }
                                }
                            }
                            .offset(y: gridDropped ? 0 : -400)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7),
                                       value: gridDropped)
                            .gesture(
                                (viewModel.isFinished || isLoadingPractice || alreadyDoneToday)
                                ? nil
                                : DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if let p = point(in: geo, from: value.location) {
                                            if viewModel.selected.isEmpty {
                                                viewModel.begin(at: p)
                                                Haptics.soft.impactOccurred()
                                            } else {
                                                viewModel.extend(to: p)
                                            }
                                        }
                                    }
                                    .onEnded { _ in viewModel.endDrag() }
                            )
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)

                // Current word + Submit
                if !isLoadingPractice {
                    HStack {
                        Text(viewModel.currentWord)
                            .font(.title2)
                            .padding(.leading)
                            .animation(.default, value: viewModel.currentWord)
                        Spacer()
                        Button("Submit") {
                            viewModel.submit()
                            Haptics.rigid.impactOccurred()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isFinished || alreadyDoneToday)
                    }
                    .transition(.opacity)
                }

                // Accepted list
                if !isLoadingPractice {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.accepted, id: \.self) { w in
                                Text(w)
                                    .font(.body.monospaced())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                    }
                    .frame(height: 120)
                    .animation(.easeInOut, value: viewModel.accepted)
                }

                // Score
                if !isLoadingPractice {
                    Text("Score: \(viewModel.score)")
                        .font(.headline)
                        .transition(.opacity)
                }

                Spacer(minLength: 4)
            }
            .padding()
            .navigationBarBackButtonHidden(true)
            .background(tm.theme.background.ignoresSafeArea())
            .navigationDestination(isPresented: $viewModel.showSummary) {
                SummaryView(score: viewModel.score,
                            words: viewModel.accepted) {
                    viewModel.showSummary = false
                    router.popToRoot()
                }
                .environmentObject(tm)
            }
            .soundToolbarItem()
            .toolbar {
                ToolbarItem(placement: .topBarLeading){
                    Button { dismiss() } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Home")
                        }
                    }
                }
                if let practiceVM = viewModel as? PracticeGameViewModel {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            practiceVM.newBoard()
                            Haptics.soft.impactOccurred()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .disabled(practiceVM.loadingSeed)
                        .help("Generate a new practice board")
                    }
                }
            }
            .onAppear {
                Haptics.prepare()
                withAnimation { gridDropped = true }
                if alreadyDoneToday {
                    viewModel.freeze()
                    countdownCancellable = Timer.publish(every: 1, on: .main, in: .common)
                        .autoconnect()
                        .sink { _ in secsLeft = ILTime.secondsUntilTomorrow() }
                    
                }
            }
            .onDisappear {
                countdownCancellable?.cancel()
                viewModel.stopTimer()    // ensure nothing keeps ticking
            }
            .onChange(of: viewModel.showSummary) { _, nowShown in
                if nowShown { viewModel.stop() } 
            }

            /* ───────── Overlay when daily already played ───────── */
            if alreadyDoneToday {
                VStack(spacing: 12) {
                    Text("You already cleared today's puzzle!")
                        .font(.headline)
                    Text("Come back in \(hhmmss(secsLeft))")
                        .font(.subheadline)
                        .monospacedDigit()
                    Button("Back to Home") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
                .onChange(of: secsLeft) { _, newValue in
                    if newValue <= 0 {
                        // new Israeli day rolled in – let Home fetch a fresh seed
                        countdownCancellable?.cancel()
                        dismiss()   // pop to Home, which will refetch
                    }
                }
            }
        }
    }
}

// MARK: - TileView
private struct TileView: View {
    let char: Character
    let highlighted: Bool
    @EnvironmentObject private var tm: ThemeManager

    var body: some View {
        Text(String(char))
            .font(.title.weight(.bold))
            .foregroundColor(highlighted ? .white :
                             (tm.theme == .classic ? .primary : tm.theme.tile))
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(highlighted ? tm.theme.tile : tm.theme.tile.opacity(0.12))
            )
            .shadow(radius: 2, y: 1)
            .animation(.easeInOut(duration: 0.12), value: highlighted)
    }
}


