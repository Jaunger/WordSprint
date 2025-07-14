import SwiftUI

struct LeaderboardView: View {
    @State private var scope: LeaderboardViewModel.Scope = .today
    @State private var vm   = LeaderboardViewModel()

    var body: some View {
        VStack {
            /* Picker always visible */
            Picker("", selection: $scope) {
                ForEach(LeaderboardViewModel.Scope.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: scope) { Task { await vm.load(scope: scope) } }

            ZStack {                     // ← put content & spinner in a stack
                content                  // list or error view

                if vm.loading {
                    ProgressView()
                        .controlSize(.large)
                        .padding()
                        .background(.thinMaterial)   // subtle blur behind
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .animation(.easeInOut, value: vm.loading) // fade spinner
        }
        .navigationTitle(scope == .today ? "Today's Leaders" : "This Week")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(scope: scope) }
    }

    // MARK: - Extracted view builder
    @ViewBuilder
    private var content: some View {
        if vm.loading {
            ProgressView("Loading…")
        } else if let err = vm.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(err).multilineTextAlignment(.center)
            }
            .padding(.top, 40)
        } else {
            List {
                ForEach(Array(vm.entries.enumerated()), id: \.1.id) { index, entry in
                    HStack {
                        Text("#\(index + 1)")
                            .frame(width: 32)

                        VStack(alignment: .leading) {
                            Text(entry.nick).bold()
                            Text("\(entry.score) pts")
                                .font(.subheadline)
                        }
                        Spacer()
                        if entry.nick == Nickname.current {
                            Image(systemName: "person.fill.checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }
}
