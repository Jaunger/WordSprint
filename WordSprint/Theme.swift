//
//  Theme.swift
//  WordSprint
//
//  Created by daniel raby on 18/07/2025.
//


import SwiftUI

enum Theme: String, CaseIterable, Identifiable, Codable {
    case classic, dusk, neon
    var id: String { rawValue }

    // base you already had
    var background: Color { Color("Theme\(rawValue.capitalized)BG") }
    var tile:       Color { Color("Theme\(rawValue.capitalized)Tile") }
    var tileHighlight: Color { Color("Theme\(rawValue.capitalized)TileHighlight") }

    // NEW semantic slots
    var accent:     Color { Color("Theme\(rawValue.capitalized)Accent") }
    var text:       Color { Color("Theme\(rawValue.capitalized)Text") }
    var buttonBG:   Color { Color("Theme\(rawValue.capitalized)ButtonBG") }
    var buttonText: Color { Color("Theme\(rawValue.capitalized)ButtonText") }
    var listBG:     Color { Color("Theme\(rawValue.capitalized)ListBG") }


    var label: String {
        switch self {
        case .classic: "Classic"
        case .dusk:    "Dusk"
        case .neon:    "Neon"
        }
    }
}

enum ThemeGate {
    static let dusk = 3
    static let neon = 6
}

@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("theme") private var themeRaw: String = Theme.classic.rawValue
    var theme: Theme {
        get { Theme(rawValue: themeRaw) ?? .classic }
        set { themeRaw = newValue.rawValue; objectWillChange.send() }
    }
    
    func setTheme(_ t: Theme, allowed: Bool) {
        guard allowed else { return }
        theme = t
    }
}

struct ThemePicker: View {
    @EnvironmentObject private var tm: ThemeManager
    @EnvironmentObject private var homeVM: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var lockedMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                ForEach(Theme.allCases) { t in
                    let unlocked = homeVM.profile?.canUse(theme: t) ?? true
                    HStack {
                        Circle().fill(t.tile).frame(width: 24, height: 24)
                        Text(t.label).padding(.leading, 8)
                        Spacer()
                        if !unlocked {
                            Image(systemName: "lock.fill").foregroundColor(.secondary)
                        } else if tm.theme == t {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if unlocked {
                            tm.theme = t
                            dismiss()
                        } else {
                            // show toast
                            let gate = t.requiredLevel ?? 0
                            lockedMessage = "Reach level \(gate) to unlock \(t.label)"
                            Haptics.warning()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(tm.theme.listBG)

            if let msg = lockedMessage {
                ToastBanner(message: msg)
                    .onDisappear { lockedMessage = nil }
            }
        }
        .navigationTitle("Choose Theme")
        .background(tm.theme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.22), value: lockedMessage != nil)
    }
}

struct ThemedButtonStyle: ButtonStyle {
    @EnvironmentObject private var tm: ThemeManager
    var prominent = false
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(prominent ? tm.theme.buttonText : tm.theme.accent)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                prominent
                ? tm.theme.buttonBG
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tm.theme.accent.opacity(prominent ? 0 : 0.6), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}




