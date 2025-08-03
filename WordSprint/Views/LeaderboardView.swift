import SwiftUI

struct LeaderboardView: View {
    @StateObject private var vm = LeaderboardViewModel()
    @EnvironmentObject private var tm: ThemeManager

    var body: some View {
        GeometryReader { _ in
            ScrollViewReader { _ in
                ZStack(alignment: .top) {
                    VStack(spacing: 16) {

                        scopePicker

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
                    .foregroundColor(tm.theme.text)

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
                        .foregroundColor(tm.theme.text)
                    if !vm.weekSubtitle.isEmpty {
                        Text(vm.weekSubtitle)
                            .font(.caption2)
                            .foregroundStyle(tm.theme.text.opacity(0.6))
                    }
                }
            }
        }
        .tint(tm.theme.accent)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.initialLoad() }
        .refreshable { await vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .scoreSubmitted)) { _ in
            Task { await vm.refresh() }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.loading)
        .animation(.default, value: vm.reloadToken)
        .background(tm.theme.background.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {

            if let rank = vm.myRank, let myScore = vm.myScore {
                HStack {
                    Text("You: #\(rank) • \(myScore) pts")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(tm.theme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(tm.theme.tile.opacity(0.15)))
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
            .tint(tm.theme.accent)
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }

    private var scoreList: some View {
        List {
            ForEach(Array(vm.entries.enumerated()), id: \.1.id) { index, entry in
                LeaderRow(index: index, entry: entry)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(tm.theme.listBG)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .scrollContentBackground(.hidden)
        .background(tm.theme.listBG)
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
                .foregroundColor(tm.theme.text)
            Button {
                Task { await vm.refresh() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(ThemedButtonStyle(prominent: true))
        }
        .padding(.top, 40)
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundColor(tm.theme.text.opacity(0.4))
            Text(vm.emptyMessage)
                .foregroundStyle(tm.theme.text.opacity(0.6))
        }
        .padding(.top, 40)
    }
}

private struct LeaderRow: View {
    let index: Int
    let entry: ScoreEntry
    @EnvironmentObject private var tm: ThemeManager

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
                    .foregroundStyle(tm.theme.text.opacity(0.6))
                    .frame(width: 34, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.nick)
                    .fontWeight(.semibold)
                    .foregroundColor(tm.theme.text)
                    .lineLimit(1)
                Text("\(entry.score) pts")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(tm.theme.text.opacity(0.6))
                    .contentTransition(.numericText())
            }

            Spacer()

            if entry.nick == Nickname.current {
                Image(systemName: "person.fill.checkmark")
                    .foregroundColor(tm.theme.accent)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tm.theme.tile.opacity(index < 3 ? 0.10 : 0.05))
        )
    }
}
