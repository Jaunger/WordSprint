import SwiftUI

struct SummaryView: View {
    let score: Int
    let words: [String]
    let onHome: () -> Void

    @EnvironmentObject private var tm: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            Text("Time’s Up!")
                .font(.largeTitle).bold()
                .foregroundColor(tm.theme.text)

            Text("Score: \(score)")
                .font(.title)
                .foregroundColor(tm.theme.text)

            List(words, id: \.self) {
                Text($0).foregroundColor(tm.theme.text)
            }
            .scrollContentBackground(.hidden)
            .background(tm.theme.listBG)

            NavigationLink("Leaderboard") {
                LeaderboardView()
                    .environmentObject(tm)
            }
            .buttonStyle(ThemedButtonStyle(prominent: true))
        }
        .padding()
        .background(tm.theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onHome()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Home")
                    }
                }
                .foregroundColor(tm.theme.accent)
            }
        }
    }
}
