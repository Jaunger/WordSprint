//
//  SoundManager.swift
//  WordSprint
//
//  Created by daniel raby on 19/07/2025.
//  Revised to support separate BGM/SFX with ducking.
//

import AVFoundation
import SwiftUI

final class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    @AppStorage("soundOn") var soundOn: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    private var bgmPlayer: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?
    private var originalBGMVolume: Float = 0.3
    
    private init() {
        // allow background audio and mixing
        try? AVAudioSession.sharedInstance().setCategory(.ambient,
                                                         mode: .default,
                                                         options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    /// Play looping background music (BGM).
    /// - Parameters:
    ///   - name: filename (without extension)
    ///   - ext: file extension (default "mp3")
    ///   - volume: 0.0–1.0 volume level
    func playBGM(named name: String, ext: String = "mp3", volume: Float = 0.3) {
        guard soundOn else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("BGM file \(name).\(ext) not found.")
            return
        }
        do {
            originalBGMVolume = volume
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = volume
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()
        } catch {
            print("SoundManager: error playing BGM –", error)
        }
    }
    
    /// Stop and clear the current BGM.
    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }
    
    /// Play a one-shot SFX, optionally ducking BGM.
    /// - Parameters:
    ///   - name: filename (without extension)
    ///   - ext: file extension (default "mp3")
    ///   - volume: 0.0–1.0 volume level
    ///   - duckBGM: whether to lower BGM while SFX plays
    func playSFX(named name: String,
                 ext: String = "wav",
                 volume: Float = 0.5,
                 duckBGM: Bool = true) {
        guard soundOn else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("SFX file \(name).\(ext) not found.")
            return
        }
        do {
            if duckBGM {
                bgmPlayer?.setVolume(originalBGMVolume * 0.4, fadeDuration: 0.1)
            }
            
            sfxPlayer = try AVAudioPlayer(contentsOf: url)
            sfxPlayer?.volume = volume
            sfxPlayer?.prepareToPlay()
            sfxPlayer?.play()
            
            if duckBGM, let duration = sfxPlayer?.duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    self.bgmPlayer?.setVolume(self.originalBGMVolume, fadeDuration: 0.2)
                }
            }
        } catch {
            print("SoundManager: error playing SFX –", error)
        }
    }
    
    func stopSFX() {
        sfxPlayer?.stop()
        sfxPlayer = nil
        // restore BGM volume in case you ducked it
        bgmPlayer?.setVolume(originalBGMVolume, fadeDuration: 0)
    }
}

struct SoundToggleButton: View {
    @EnvironmentObject private var sm: SoundManager
    
    var size: CGFloat = 22
    var body: some View {
        Button {
            sm.soundOn.toggle()
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.prepare()
            gen.impactOccurred(intensity: 0.6)
        } label: {
            Image(systemName: sm.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: size, weight: .semibold))
                .contentShape(Rectangle())
                .accessibilityLabel(sm.soundOn ? "Mute sound" : "Unmute sound")
        }
        .buttonStyle(.plain)
        .padding(6)
        .background(.ultraThinMaterial, in: Circle())
    }
}

extension View {
    func soundToolbarItem() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SoundToggleButton()
            }
        }
    }
}
