import AppKit
import OSLog
import RingletCore
import SwiftUI

private let log = Logger(subsystem: "io.snouzy.ringlet", category: "anneau")

/// Panneau transparent, non activant : il couvre l'écran du curseur pendant que l'anneau est ouvert,
/// pour recevoir la souris et Échap sans voler le premier plan au Finder.
final class RingPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
}

/// Ouverture, suivi et choix de l'anneau. Raccourci maintenu : relâcher sur un secteur l'exécute ;
/// relâcher sans avoir visé laisse l'anneau ouvert, un clic choisit, Échap ou un clic au centre ferme.
/// D'où vient l'ouverture : le raccourci (sélection du Finder), un fichier sous le curseur, ou le vide d'une fenêtre.
enum TriggerContext: Equatable {
    case selection
    case file(URL)
    case emptyArea(isDesktop: Bool)
}

/// Sur quoi portent les actions de l'anneau ouvert.
enum RingTarget: Equatable {
    case files([URL])
    case folder(URL, isDesktop: Bool)
}

@MainActor final class RingController {
    var jpegQuality = 0.9
    var ringSize = RingSize.medium
    var look = RingLook()
    var terminal = AppChoice(bundleID: "com.apple.Terminal")
    var editor = AppChoice(bundleID: "com.microsoft.VSCode")

    private let model = RingModel()
    private let panel = RingPanel()
    private var target = RingTarget.files([])
    private var isHolding = false
    private var hasAimed = false
    private var monitors: [Any] = []
    private var hideTask: Task<Void, Never>?

    init() {
        let host = NSHostingView(rootView: RingView(model: model))
        host.sizingOptions = []
        panel.contentView = host
    }

    var isOpen: Bool { model.showsRing }

    // MARK: - Déclencheurs

    /// Fichier sous le curseur : s'il fait partie de la sélection du Finder, l'action porte sur toute la sélection,
    /// sinon sur lui seul. Vide d'une fenêtre, ou raccourci sans sélection : anneau du dossier.
    func triggerPressed(_ context: TriggerContext = .selection) {
        guard !isOpen else { return log.notice("Déclencheur ignoré : anneau déjà ouvert") }
        isHolding = true
        open(context)
    }

    func triggerReleased() {
        guard isHolding else { return }
        isHolding = false
        guard isOpen, hasAimed else { return }
        if model.hot != nil { runHot() } else { close() }   // sur la croix ou hors de l'anneau : annuler
    }

    /// Lance une action sans anneau (Services du clic droit) et montre le résultat sous le curseur.
    func run(_ kind: ActionKind, on files: [URL]) {
        guard let point = placeUnderMouse() else { return }
        perform(kind, on: .files(files), messageAt: point)
    }

    // MARK: - Ouverture

    private func placeUnderMouse() -> CGPoint? {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return nil }
        place(on: screen)
        return viewPoint(mouse)
    }

    private func open(_ context: TriggerContext) {
        guard let point = placeUnderMouse() else { return }
        let resolved = resolve(context)
        log.notice("Ouverture \(String(describing: context), privacy: .public) → \(String(describing: resolved), privacy: .public)")
        switch resolved {
        case .success(let resolved): show(resolved, at: point)
        case .failure(.notAuthorized):
            showMessage("Autorise Ringlet dans Réglages Système › Confidentialité › Automatisation › Finder",
                        isError: true, at: point, duration: 4)
        case .failure(.failed):
            showMessage("Impossible de lire le Finder", isError: true, at: point)
        }
    }

    private func resolve(_ context: TriggerContext) -> Result<RingTarget, FinderScript.Failure> {
        switch context {
        case .emptyArea(isDesktop: true):
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            return .success(.folder(desktop, isDesktop: true))
        case .emptyArea(isDesktop: false):
            return FinderScript.frontFolder().map { .folder($0.url, isDesktop: $0.isDesktop) }
        case .file(let url):
            let selection = (try? FinderSelection.read().get()) ?? []
            let inSelection = selection.contains { $0.standardizedFileURL.path == url.standardizedFileURL.path }
            return .success(.files(inSelection ? selection : [url]))
        case .selection:
            switch FinderSelection.read() {
            case .success(let selection) where !selection.isEmpty: return .success(.files(selection))
            case .success: return FinderScript.frontFolder().map { .folder($0.url, isDesktop: $0.isDesktop) }
            case .failure(.notAuthorized): return .failure(.notAuthorized)
            case .failure: return .failure(.failed)
            }
        }
    }

    private func show(_ resolved: RingTarget, at point: CGPoint) {
        log.notice("Anneau en \(point.x), \(point.y) dans un panneau de \(self.panel.frame.width)×\(self.panel.frame.height)")
        let actions: [FileAction]
        switch resolved {
        case .files(let urls):
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.standardizedFileURL.path
            let onDesktop = FolderTargets.containing(urls)?.standardizedFileURL.path == desktop
            actions = ActionCatalog.actions(for: urls, terminal: terminal.name, editor: editor.name, canGoUp: !onDesktop)
        case .folder(_, let isDesktop):
            actions = ActionCatalog.folderActions(isDesktop: isDesktop, terminal: terminal.name, editor: editor.name)
        }
        guard !actions.isEmpty else { return showMessage("Aucune action ici", isError: true, at: point) }

        target = resolved
        hasAimed = false
        hideTask?.cancel()
        model.message = nil
        model.actions = actions
        model.geometry = .standard(count: actions.count, size: ringSize)
        model.look = look
        model.center = RingGeometry.clampedCenter(point, outerRadius: model.geometry.radius + 40,
                                                  in: CGRect(origin: .zero, size: panel.frame.size))
        model.hot = nil
        model.cancelHot = false
        model.isOpen = false
        model.showsRing = true
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        panel.makeKey()
        startMonitoring()
        DispatchQueue.main.async { [model] in model.isOpen = true }
    }

    private func place(on screen: NSScreen) {
        if panel.frame != screen.frame { panel.setFrame(screen.frame, display: false) }
    }

    /// Point écran AppKit (origine en bas à gauche de l'écran principal) → point de la vue (origine en haut à gauche).
    private func viewPoint(_ screenPoint: NSPoint) -> CGPoint {
        CGPoint(x: screenPoint.x - panel.frame.minX, y: panel.frame.maxY - screenPoint.y)
    }

    // MARK: - Suivi

    private func startMonitoring() {
        stopMonitoring()
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: moves.union([.leftMouseDown, .keyDown])) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        } as Any)
        // Souris au-dessus d'une autre fenêtre ou d'un autre écran : le moniteur global prend le relais.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }) { monitors.append(global) }
    }

    private func stopMonitoring() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    /// true si l'évènement est consommé.
    private func handle(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            if event.keyCode == 53 { close(); return true }                       // Échap
            if event.keyCode == 36 || event.keyCode == 76 { runHot(); return true } // Entrée
            return false
        case .leftMouseDown:
            track()
            // Hors de l'anneau ou sur la croix, rien n'est visé : le clic ferme.
            if model.hot != nil { runHot() } else { close() }
            return true
        default:
            track()
            return false
        }
    }

    private func track() {
        guard isOpen else { return }
        let point = viewPoint(NSEvent.mouseLocation)
        let dx = point.x - model.center.x, dy = point.y - model.center.y
        let hot = model.geometry.sector(dx: dx, dy: dy)
        if model.geometry.isAiming(dx: dx, dy: dy) { hasAimed = true }
        if hot != model.hot { model.hot = hot }
        let cancel = hasAimed && hot == nil
        if cancel != model.cancelHot { model.cancelHot = cancel }
    }

    // MARK: - Choix

    private func runHot() {
        guard let hot = model.hot, model.actions.indices.contains(hot) else { return }
        let kind = model.actions[hot].kind, center = model.center
        close()
        perform(kind, on: target, messageAt: center)
    }

    private func perform(_ kind: ActionKind, on target: RingTarget, messageAt center: CGPoint) {
        let urls: [URL]
        switch target {
        case .files(let files): urls = files
        case .folder(let folder, _): urls = [folder]
        }
        switch kind {
        case .copyPath:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(PathCopy.text(for: urls), forType: .string)
            showMessage(PathCopy.summary(count: urls.count), isError: false, at: center)
        case .openTerminal:
            open(FolderTargets.folders(for: urls), with: terminal, messageAt: center)
        case .openEditor:
            open(urls, with: editor, messageAt: center)
        case .quickLook:
            QuickLook.shared.show(urls)
        case .goUp:
            // Comme ⌘↑ dans la fenêtre qui montre l'élément, fichier ou dossier ; pour l'anneau d'un dossier,
            // l'élément est ce dossier, que montre sa propre fenêtre.
            if case .folder(let folder, _) = target {
                report(FinderScript.goUp(showing: folder.path + "/", fallback: folder), at: center)
            } else if let item = urls.first, let shown = FolderTargets.containing(urls) {
                report(FinderScript.goUp(showing: item.path, fallback: shown), at: center)
            }
        case .newFolder:
            report(FinderScript.newFolder(in: urls[0]), at: center)
            // Avec l'Accessibilité, on entre directement dans le renommage, comme ⇧⌘N.
            if AXIsProcessTrusted() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Self.pressReturn() }
            }
        default:
            createFiles(kind, from: urls, messageAt: center)
        }
    }

    private func createFiles(_ kind: ActionKind, from files: [URL], messageAt center: CGPoint) {
        let quality = jpegQuality
        if kind.videoPreset != nil {
            showMessage(files.count == 1 ? "Export de \(files[0].lastPathComponent)…" : "Export de \(files.count) vidéos…",
                        isError: false, at: center, busy: true)
        }
        Task { [weak self] in
            let results = await Task.detached(priority: .userInitiated) {
                await ActionRunner.run(kind, on: files, jpegQuality: quality)
            }.value
            let summary = ResultSummary(results: results)
            self?.showMessage(summary.text, isError: summary.hasFailures, at: center)
        }
    }

    private func open(_ folders: [URL], with app: AppChoice, messageAt center: CGPoint) {
        guard let appURL = app.url else {
            return showMessage("\(app.name) introuvable : choisis une autre app dans les réglages", isError: true, at: center)
        }
        NSWorkspace.shared.open(folders, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func report(_ result: Result<Void, FinderScript.Failure>, at center: CGPoint) {
        guard case .failure(let failure) = result else { return }
        showMessage(failure == .notAuthorized ? "Autorise Ringlet à piloter le Finder dans Réglages Système"
                                              : "Le Finder n'a pas pu le faire", isError: true, at: center)
    }

    private static func pressReturn() {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: down)?.post(tap: .cghidEventTap)
        }
    }

    /// Retire toujours le panneau : resté devant, ce calque plein écran prendrait les clics et le clavier
    /// (aperçu, terminal…). La bulle d'un résultat le remet devant, sans clics.
    private func close() {
        stopMonitoring()
        isHolding = false
        model.isOpen = false
        model.hot = nil
        model.cancelHot = false
        model.showsRing = false
        panel.ignoresMouseEvents = true
        panel.orderOut(nil)
    }

    /// Bulle sous le curseur. `busy` : action longue, la bulle reste jusqu'au message suivant.
    private func showMessage(_ text: String, isError: Bool, at point: CGPoint, duration: Double = 1.6, busy: Bool = false) {
        withAnimation(.easeOut(duration: 0.15)) {
            model.message = text
            model.messageIsError = isError
            model.messageIsBusy = busy
        }
        model.center = point
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        hideTask?.cancel()
        guard !busy else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, !Task.isCancelled, !self.isOpen else { return }
            self.model.message = nil
            self.panel.orderOut(nil)
        }
    }
}
