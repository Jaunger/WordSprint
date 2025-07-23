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
    @EnvironmentObject private var sm: SoundManager
    @EnvironmentObject private var tm: ThemeManager
    @EnvironmentObject private var router: NavRouter

    var body: some View {
        GameView(viewModel: viewModel)
    }
    
    
}

