//
//  HomeViewModel.swift
//  WordSprint
//
//  Created by daniel raby on 14/07/2025.
//


import Foundation

@Observable final class HomeViewModel {
    private(set) var dailySeed: GridSeed?
    private(set) var loading  = true
    private(set) var errorMessage: String?
    var profile: PlayerProfile?

    init() {
        Task { await fetchSeed() }
    }
    
    func loadProfile() {
        Task {
            profile = try? await ProfileService.load(for: Nickname.current)
        }
    }

    @MainActor private func fetchSeed() async {
        do {
            dailySeed = try await FSService.fetchTodaySeed()   // normal path
            loading = false
        } catch {
            let generated = FSService.dailyGridSeed(for: Date())
            do {
                try await FSService.writeTodaySeed(generated)  // might fail if race
                print("🌐 Uploaded new daily seed")
            } catch {
                print("Seed already uploaded by another client")  // benign
            }
            dailySeed = generated
            loading = false
        }
    }
    
    @MainActor
    func reloadProfileNick(_ newNick: String) async {
        // local profile already loaded?
        if let prof = profile {
            try? await ProfileService.save(prof, for: newNick)   // move doc
            profile = prof                                       // refresh binding
        }
    }
}
