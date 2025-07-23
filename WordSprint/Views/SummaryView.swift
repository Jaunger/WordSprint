//
//  SummaryView.swift
//  WordSprint
//
//  Created by daniel raby on 14/07/2025.
//


import SwiftUI

struct SummaryView: View {
    let score: Int
    let words: [String]
    @EnvironmentObject private var tm: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let onHome: () -> Void


    var body: some View {
        VStack(spacing: 16) {
            Text("Time’s Up!").font(.largeTitle).bold()
            Text("Score: \(score)").font(.title)

            List(words, id: \.self) { Text($0) }

            NavigationLink("Leaderboard") {
                LeaderboardView()
                    .environmentObject(tm)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
            }
        }

        }

    }

