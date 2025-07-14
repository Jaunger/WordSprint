import SwiftUI

struct ContentView: View {
    @State private var seed: GridSeed?
    @State private var err: String?

    var body: some View {
        Group {
            if let s = seed {
                GameView(seed: s)
            } else if let e = err {
                Text(e).foregroundColor(.red)
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                seed = try await FSService.fetchTodaySeed()
            } catch let error {
                err = error.localizedDescription   // no “?”
            }
        }
    }
}
