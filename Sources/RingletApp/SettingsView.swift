import Combine
import RingletCore
import ServiceManagement
import SwiftUI

/// Fenêtre des réglages : Général, Déclencheurs, Conversion, Autorisations.
struct SettingsView: View {
    @Bindable var prefs: Preferences
    let hotKeyRegistered: () -> Bool
    var onRecordingShortcut: (Bool) -> Void = { _ in }

    var body: some View {
        TabView {
            GeneralTab(prefs: prefs).tabItem { Label("Général", systemImage: "circle.dashed") }
            TriggersTab(prefs: prefs, hotKeyRegistered: hotKeyRegistered, onRecordingShortcut: onRecordingShortcut)
                .tabItem { Label("Déclencheurs", systemImage: "cursorarrow.click.2") }
            ActionsTab(prefs: prefs).tabItem { Label("Actions", systemImage: "circle.grid.cross") }
            PermissionsTab().tabItem { Label("Autorisations", systemImage: "lock.shield") }
        }
        .frame(width: 540, height: 380)
    }
}

private struct GeneralTab: View {
    @Bindable var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let isBundled = Bundle.main.bundleURL.pathExtension == "app"

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sélectionne des fichiers dans le Finder, maintiens \(prefs.shortcut.label), pars vers une action et relâche.")
                    Text("Relâcher sans viser laisse l'anneau ouvert : un clic choisit, Échap ferme.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 4)
            }
            Section {
                Picker("Taille de l'anneau", selection: $prefs.ringSize) {
                    ForEach(RingSize.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Lancer Ringlet à l'ouverture de session", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                    .disabled(!isBundled)
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

private struct TriggersTab: View {
    @Bindable var prefs: Preferences
    let hotKeyRegistered: () -> Bool
    let onRecordingShortcut: (Bool) -> Void
    @State private var trusted = Permissions.accessibility == .granted
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Clavier") {
                LabeledContent("Raccourci à maintenir") {
                    ShortcutRecorder(combo: $prefs.shortcut, onRecording: onRecordingShortcut)
                }
                if !hotKeyRegistered() {
                    Text("Ce raccourci est déjà pris par macOS ou une autre app : choisis-en un autre.")
                        .foregroundStyle(.orange).font(.callout)
                }
            }
            Section("Souris") {
                Picker("Bouton", selection: $prefs.mouseTrigger) {
                    ForEach(MouseTrigger.allCases) { Text($0.label).tag($0) }
                }
                if prefs.mouseTrigger == .holdRight {
                    LabeledContent("Délai avant l'anneau") {
                        HStack {
                            Slider(value: $prefs.holdDelay, in: 0.15...0.6, step: 0.01).frame(width: 160)
                            Text("\(Int(prefs.holdDelay * 1000)) ms").monospacedDigit().frame(width: 56, alignment: .trailing)
                        }
                    }
                    Text("Un clic droit rapide garde le menu habituel du Finder.").foregroundStyle(.secondary).font(.callout)
                }
                if prefs.mouseTrigger != .none && !trusted {
                    HStack {
                        Label("La souris a besoin de l'autorisation Accessibilité.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Autoriser…") {
                            Permissions.requestAccessibility()
                            Permissions.openAccessibilitySettings()
                        }
                    }
                    .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in trusted = Permissions.accessibility == .granted }
    }
}

private struct ActionsTab: View {
    @Bindable var prefs: Preferences

    var body: some View {
        Form {
            Section("Apps") {
                AppPicker(title: "Terminal", choice: $prefs.terminal, candidates: AppChoice.terminals)
                AppPicker(title: "Éditeur", choice: $prefs.editor, candidates: AppChoice.editors)
            }
            Section("Photos") {
                LabeledContent("Qualité des JPG") {
                    HStack {
                        Slider(value: $prefs.jpegQuality, in: 0.5...1, step: 0.05).frame(width: 180)
                        Text("\(Int((prefs.jpegQuality * 100).rounded())) %").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                Text("Les fichiers créés (JPG, PNG, copie sans GPS, vidéos) vont à côté des originaux, qui ne sont jamais modifiés.")
                    .foregroundStyle(.secondary).font(.callout)
            }
        }
        .formStyle(.grouped)
    }
}

/// Liste des apps installées connues, plus « Autre… » pour en choisir une dans /Applications.
private struct AppPicker: View {
    let title: String
    @Binding var choice: AppChoice
    let candidates: [AppChoice]

    var body: some View {
        let options = candidates.filter(\.isInstalled) + (candidates.contains(choice) ? [] : [choice])
        Picker(title, selection: Binding(get: { choice.bundleID }, set: { id in
            if id == "autre" { choice = AppChoice.pick() ?? choice } else { choice = AppChoice(bundleID: id) }
        })) {
            ForEach(options) { Text($0.name).tag($0.bundleID) }
            Divider()
            Text("Autre…").tag("autre")
        }
    }
}

private struct PermissionsTab: View {
    @State private var finder = Permissions.finder
    @State private var accessibility = Permissions.accessibility
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                row("Finder (Automatisation)", "Lire les fichiers sélectionnés. Demandée au premier usage de l'anneau.",
                    state: finder, action: Permissions.openAutomationSettings)
                row("Accessibilité", "Seulement pour ouvrir l'anneau à la souris (clic droit maintenu, boutons).",
                    state: accessibility) {
                    Permissions.requestAccessibility()
                    Permissions.openAccessibilitySettings()
                }
            }
            Section {
                Text("Ringlet ne se connecte à rien : tout se passe sur ton Mac.").foregroundStyle(.secondary).font(.callout)
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in
            finder = Permissions.finder
            accessibility = Permissions.accessibility
        }
    }

    private func row(_ title: String, _ detail: String, state: Permissions.State, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail).foregroundStyle(.secondary).font(.callout)
            }
            Spacer()
            switch state {
            case .granted: Label("Accordée", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .denied: Button("Refusée — ouvrir les réglages", action: action)
            case .notAsked, .unknown: Button("Ouvrir les réglages", action: action)
            }
        }
    }
}
