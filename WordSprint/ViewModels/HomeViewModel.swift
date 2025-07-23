//
//  HomeViewModel.swift
//  WordSprint
//
//  Created by daniel raby on 14/07/2025.
//


import Foundation

@Observable
final class HomeViewModel : ObservableObject{
    private(set) var dailySeed: GridSeed?
    private(set) var loading  = true
    private(set) var errorMessage: String?
    private(set) var seedError: String?
    private var loadingProfile: Bool = false
    private var didLoadProfile: Bool = false
    var profile: PlayerProfile?

    init() {
        Task { await fetchSeed()}
            Task { await loadProfile(force: true) }
        
    }
    
    
    func loadProfile(force: Bool = false) async {
        if didLoadProfile && !force { return }
        loadingProfile = true
        do {
            profile = try await ProfileService.load(for: Nickname.current)
            didLoadProfile = true
        } catch {
            errorMessage = error.localizedDescription
        }
        loadingProfile = false
    }

    /// Force-refresh just nickname on Firestore
    func reloadProfileNick(_ newNick: String) async {
        didLoadProfile = false
        await loadProfile(force: true)
    }

    @MainActor func fetchSeed() async {
        do {
            dailySeed = try await FSService.fetchTodaySeed()   // normal path
            loading = false
        } catch {
            let generated = GridSeed(seed: FSService.dailySeedString(for: Date()))
            
            print(generated)
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
    
}
