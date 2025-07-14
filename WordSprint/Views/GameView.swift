import SwiftUI

enum Haptics {
    static let soft   = UIImpactFeedbackGenerator(style: .soft)
    static let rigid  = UIImpactFeedbackGenerator(style: .rigid)
    static let notify = UINotificationFeedbackGenerator()
    static func prepare() {
        soft.prepare(); rigid.prepare(); notify.prepare()
    }
}

struct GameView: View {
    // MARK: - State
    @State private var viewModel: GameViewModel
    @State private var gridDropped = false        // for intro animation
    
    init(seed: GridSeed) {
        _viewModel = State(wrappedValue: GameViewModel(seed: seed))
    }
    
    init(viewModel: GameViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    // Convert touch-location → GridPoint
    private func point(in geo: GeometryProxy,
                       from location: CGPoint) -> GameViewModel.GridPoint? {
        let size = geo.size.width / 4
        let r = Int(location.y / size)
        let c = Int(location.x / size)
        guard (0..<4).contains(r), (0..<4).contains(c) else { return nil }
        return .init(row: r, col: c)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Timer
            Text("Time: \(viewModel.timeLeft)")
                .font(.title2)
                .monospacedDigit()

            // MARK: Grid ----------------------------------------------------
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
                .offset(y: gridDropped ? 0 : -400) // intro animation
                .animation(.spring(response: 0.6,
                                   dampingFraction: 0.7),
                           value: gridDropped)
                .gesture(
                    viewModel.isFinished ? nil :
                    DragGesture(minimumDistance: 0)
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

            // MARK: Current word + Submit ----------------------------------
            HStack {
                Text(viewModel.currentWord)
                    .font(.title2)
                    .padding(.leading)
                Spacer()
                Button("Submit") {
                    viewModel.submit()
                    Haptics.rigid.impactOccurred()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isFinished)
            }

            // MARK: Accepted list ------------------------------------------
            ScrollView {
                ForEach(viewModel.accepted, id: \.self) { w in
                    Text(w)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 120)

            Text("Score: \(viewModel.score)")
                .font(.headline)
        }
        .padding()
        .navigationTitle("WordSprint")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $viewModel.showSummary) {
            SummaryView(score: viewModel.score,
                        words: viewModel.accepted)
        }
        .onAppear {
            Haptics.prepare()          // pre-warm haptics
            gridDropped = true         // trigger intro drop
        }
    }
}

 private struct TileView: View {
    let char: Character
    let highlighted: Bool
    @EnvironmentObject private var tm: ThemeManager     // ← current theme

    var body: some View {
        Text(String(char))
            .font(.title.weight(.bold))
            .foregroundColor(highlighted ? .white
                            : tm.theme == .classic ? .primary : tm.theme.tile)
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(highlighted ? tm.theme.tile
                                      : tm.theme.tile.opacity(0.12))
            )
            .shadow(radius: 2, y: 1)
    }
}
