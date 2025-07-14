//
//  PracticeGameView.swift
//  WordSprint
//
//  Created by daniel raby on 15/07/2025.
//


import SwiftUI

/// Thin wrapper: constructs `PracticeGameViewModel` and feeds it to GameView.
struct PracticeGameView: View {
    @State private var viewModel = PracticeGameViewModel()
    var body: some View {
        GameView(viewModel: viewModel)
    }
}

