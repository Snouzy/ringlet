import Combine
import RingletCore
import ServiceManagement
import SwiftUI

/// Fenêtre des réglages : Général, Apparence, Déclencheurs, Actions, Autorisations.
struct SettingsView: View {
    @Bindable var prefs: Preferences
    let hotKeyRegistered: () -> Bool
    var onRecordingShortcut: (Bool) -> Void = { _ in }

    var body: some View {
        TabView {
            GeneralTab(prefs: prefs).tabItem { Label("Général", systemImage: "circle.dashed") }
            AppearanceTab(prefs: prefs).tabItem { Label("Apparence", systemImage: "paintpalette") }
            TriggersTab(prefs: prefs, hotKeyRegistered: hotKeyRegistered, onRecordingShortcut: onRecordingShortcut)
                .tabItem { Label("Déclencheurs", systemImage: "cursorarrow.click.2") }
            ActionsTab(prefs: prefs).tabItem { Label("Actions", systemImage: "circle.grid.cross") }
            PermissionsTab().tabItem { Label("Autorisations", systemImage: "lock.shield") }
        }
        .frame(width: 640, height: 430)
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

/// Style, taille et couleurs de l'anneau, avec un anneau d'exemple à viser à la souris.
struct AppearanceTab: View {
    @Bindable var prefs: Preferences
    @State private var hot: Int?
    @State private var cancelHot = false

    /// `hot` : secteur allumé d'entrée, pour les captures du README.
    init(prefs: Preferences, hot: Int? = nil) {
        self.prefs = prefs
        _hot = State(initialValue: hot)
    }
    @State private var isOpen = true
    private let sample = ActionCatalog.actions(for: [URL(fileURLWithPath: "/Users/exemple/IMG_8271.HEIC")],
                                               terminal: "Terminal", editor: "VS Code", canGoUp: true)

    var body: some View {
        HStack(spacing: 0) {
            preview.frame(width: 320)
            Divider()
            Form {
                Section("Anneau") {
                    Picker("Style", selection: $prefs.ringStyle) {
                        ForEach(RingStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Taille", selection: $prefs.ringSize) {
                        ForEach(RingSize.allCases) { Text($0.label).tag($0) }
                    }
                    LabeledContent("Couleur") { AccentPicker(accent: $prefs.accent) }
                    if prefs.ringStyle == .glass {
                        LabeledContent("Opacité du verre") {
                            HStack {
                                Slider(value: $prefs.glassOpacity, in: GlassOpacity.range, step: 0.01).frame(width: 110)
                                Text("\(Int((prefs.glassOpacity * 100).rounded())) %").monospacedDigit().frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
                Section {
                    Toggle("Réduire les animations", isOn: $prefs.reduceMotion)
                    Button("Rejouer l'ouverture", action: replay)
                }
            }
            .formStyle(.grouped)
        }
    }

    private var preview: some View {
        GeometryReader { proxy in
            let geometry = RingGeometry.standard(count: sample.count, size: prefs.ringSize)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2 - 18)
            ZStack {
                Wallpaper()
                RingFace(actions: sample, geometry: geometry, hot: hot, cancelHot: cancelHot, isOpen: isOpen, look: prefs.look)
                    .position(center)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hot = geometry.sector(dx: point.x - center.x, dy: point.y - center.y)
                    cancelHot = hot == nil
                case .ended:
                    hot = nil
                    cancelHot = false
                }
            }
        }
        .clipped()
        .accessibilityLabel("Aperçu de l'anneau")
    }

    private func replay() {
        isOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isOpen = true }
    }
}

/// Fond d'écran d'exemple derrière l'aperçu, pour juger le verre et le flou.
private struct Wallpaper: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors: [Color] = scheme == .dark
            ? [Color(red: 0.12, green: 0.24, blue: 0.47), Color(red: 0.05, green: 0.06, blue: 0.11), Color(red: 0.29, green: 0.12, blue: 0.37)]
            : [Color(red: 0.79, green: 0.87, blue: 0.99), Color(red: 0.95, green: 0.93, blue: 0.96), Color(red: 1, green: 0.84, blue: 0.76)]
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            // Quelques lignes de fichiers, comme une fenêtre du Finder derrière l'anneau.
            VStack(alignment: .leading, spacing: 7) {
                ForEach(["IMG_8271-sans-gps.HEIC", "IMG_8271.HEIC", "IMG_8271.jpg", "IMG_8271.png", "plage-ete.HEIC"], id: \.self) { name in
                    Text(name)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(name == "IMG_8271.HEIC" ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(name == "IMG_8271.HEIC" ? Color.white : Color.primary.opacity(0.75))
                }
            }
            .padding(12)
            .frame(width: 210, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
        }
    }
}

/// Pastilles des couleurs d'accent de macOS ; la première suit le réglage du système.
private struct AccentPicker: View {
    @Binding var accent: RingAccent

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RingAccent.allCases) { option in
                Button { accent = option } label: {
                    Circle()
                        .fill(option == .system
                              ? AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red], center: .center))
                              : AnyShapeStyle(option.color))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5))
                        .padding(2)
                        .overlay(Circle().strokeBorder(option == accent ? option.color : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .help(option.label)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(option == accent ? .isSelected : [])
            }
        }
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
