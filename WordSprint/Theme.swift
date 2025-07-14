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


    var background: Color { Color("Theme\(rawValue.capitalized)BG") }
    var tile:       Color { Color("Theme\(rawValue.capitalized)Tile") }

    var label: String {
        switch self {
        case .classic: "Classic"
        case .dusk:    "Dusk"
        case .neon:    "Neon"
        }
    }
}

/* Global helper to access / change theme */
@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("theme") private var themeRaw: String = Theme.classic.rawValue
    var theme: Theme {
        get { Theme(rawValue: themeRaw) ?? .classic }
        set { themeRaw = newValue.rawValue; objectWillChange.send() }
    }
}

struct ThemePicker: View {
    @EnvironmentObject private var tm: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Theme.allCases) { t in
                HStack {
                    Circle().fill(t.tile).frame(width: 24, height: 24)
                    Text(t.label).padding(.leading, 8)
                    Spacer()
                    if tm.theme == t { Image(systemName: "checkmark") }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    tm.theme = t
                    dismiss()
                }
            }
        }
        .navigationTitle("Choose Theme")
    }
}
