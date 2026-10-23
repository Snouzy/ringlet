import AppKit
import OSLog
import RingletCore
import SwiftUI

private let log = Logger(subsystem: "io.snouzy.ringlet", category: "app")

@main
struct RingletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() { Screenshots.runIfAsked() }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(delegate: delegate)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let prefs = Preferences()
    let ring = RingController()
    private let hotKey = HotKey()
    private let mouse = MouseTriggerTap()
    private let services = ServiceProvider()
    private var settingsWindow: NSWindow?
    private var trustTimer: Timer?
    @Published private(set) var hotKeyRegistered = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // App de barre des menus : macOS ne doit jamais la fermer d'elle-même quand elle n'a pas de fenêtre.
        ProcessInfo.processInfo.disableAutomaticTermination("Ringlet attend son raccourci")
        ProcessInfo.processInfo.disableSuddenTermination()
        hotKey.onPress = { [weak self] in self?.ring.triggerPressed() }
        hotKey.onRelease = { [weak self] in self?.ring.triggerReleased() }
        mouse.onPress = { [weak self] context in self?.ring.triggerPressed(context) }
        mouse.onRelease = { [weak self] in self?.ring.triggerReleased() }
        services.onRun = { [weak self] kind, urls in self?.ring.run(kind, on: urls) }
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
        prefs.onChange = { [weak self] in self?.apply() }
        apply()
        // L'Accessibilité s'accorde dans Réglages Système, hors de l'app : on installe la souris dès qu'elle arrive.
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.prefs.mouseTrigger != .none, !self.mouse.isRunning else { return }
                self.mouse.refresh()
            }
        }
        if !prefs.hasSeenWelcome {
            prefs.hasSeenWelcome = true
            showSettings()
        }
    }

    /// Applique les réglages : raccourci, bouton de souris, taille, qualité.
    func apply() {
        hotKeyRegistered = hotKey.register(prefs.shortcut)
        log.notice("Raccourci \(self.prefs.shortcut.label, privacy: .public) : \(self.hotKeyRegistered ? "enregistré" : "refusé", privacy: .public)")
        mouse.holdDelay = prefs.holdDelay
        mouse.mode = prefs.mouseTrigger
        if prefs.mouseTrigger != .none, !mouse.isRunning { mouse.refresh() }
        ring.ringSize = prefs.ringSize
        ring.look = prefs.look
        ring.jpegQuality = prefs.jpegQuality
        ring.terminal = prefs.terminal
        ring.editor = prefs.editor
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = SettingsWindow.make(prefs: prefs, hotKeyRegistered: { [weak self] in self?.hotKeyRegistered ?? false },
                                             onRecordingShortcut: { [weak self] recording in
                // Pendant l'enregistrement, le raccourci actuel doit arriver jusqu'au champ.
                guard let self else { return }
                if recording { self.hotKey.unregister() } else { self.apply() }
            })
            window.center()
            settingsWindow = window
        }
        apply()
        // Depuis macOS 14, activate() n'est qu'une demande que l'app au premier plan peut refuser : la fenêtre
        // est donc aussi mise devant explicitement.
        NSApp.activate()
        settingsWindow?.orderFrontRegardless()
        settingsWindow?.makeKey()
    }
}

private struct MenuContent: View {
    @ObservedObject var delegate: AppDelegate

    var body: some View {
        if delegate.hotKeyRegistered {
            Text("Hold \(delegate.prefs.shortcut.title) on files in the Finder")
        } else {
            Text("\(delegate.prefs.shortcut.title) is already taken: change it in Settings")
        }
        Divider()
        Button("Settings…") { delegate.showSettings() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Ringlet") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
