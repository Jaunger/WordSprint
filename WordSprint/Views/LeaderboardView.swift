import SwiftUI

struct LeaderboardView: View {
    @StateObject private var vm = LeaderboardViewModel()
    @EnvironmentObject private var tm: ThemeManager   // (optional theming)

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { _ in
                ZStack(alignment: .top) {
                    // Main vertical stack fills height so we can pin top
                    VStack(spacing: 16) {

                        scopePicker

                        // Content area (fills remaining vertical space, aligns top)
                        Group {
                            if let err = vm.errorMessage, !vm.loading {
                                errorState(err)
                            } else if !vm.loading && vm.entries.isEmpty {
                                emptyState
                            } else {
                                scoreList
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .top)

                    if vm.loading {
                        ProgressView()
                            .controlSize(.large)
                            .padding(24)
                            .background(.ultraThinMaterial,
                                        in: RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 4, y: 2)
                            .transition(.opacity)
                            .frame(maxWidth: .infinity,
                                   maxHeight: .infinity,
                                   alignment: .center)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(vm.title).font(.headline)
                    if !vm.weekSubtitle.isEmpty {
                        Text(vm.weekSubtitle)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.initialLoad() }
        .refreshable { await vm.refresh() }
        .animation(.easeInOut(duration: 0.25), value: vm.loading)
        .animation(.default, value: vm.reloadToken)
        .background(tm.theme.background.ignoresSafeArea())   // optional theme
    }

    // MARK: - Subviews

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {

            if let rank = vm.myRank, let myScore = vm.myScore {
                // Rank chip on top (optional)
                HStack {
                    Text("You: #\(rank) • \(myScore) pts")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.thinMaterial))
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.horizontal)
            }

            Picker("", selection: Binding(
                get: { vm.scope },
                set: { vm.scope = $0 }
            )) {
                ForEach(LeaderboardViewModel.Scope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }

    private var scoreList: some View {
        // Only show list when we have entries (or loading, but loading overlays spinner)
        List {
            ForEach(Array(vm.entries.enumerated()), id: \.1.id) { index, entry in
                LeaderRow(index: index, entry: entry)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .frame(minHeight: 0, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.refresh() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(vm.emptyMessage)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }
}

// MARK: - Row (unchanged from last version)
private struct LeaderRow: View {
    let index: Int
    let entry: ScoreEntry

    var medal: String? {
        switch index {
        case 0: "🥇"
        case 1: "🥈"
        case 2: "🥉"
        default: nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let medal {
                Text(medal).font(.title3)
                    .frame(width: 34, alignment: .leading)
            } else {
                Text("#\(index + 1)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.nick)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(entry.score) pts")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            if entry.nick == Nickname.current {
                Image(systemName: "person.fill.checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.secondary.opacity(index < 3 ? 0.08 : 0.04))
        )
    }
}
