import AppKit
import OSLog
import RingletCore

private let log = Logger(subsystem: "io.snouzy.ringlet", category: "souris")

/// Ouvre l'anneau depuis la souris (autorisation Accessibilité) : clic droit maintenu dans le Finder,
/// ou un bouton central / latéral n'importe où. Les clics qui ne concernent pas Ringlet passent sans délai.
@MainActor final class MouseTriggerTap {
    var mode: MouseTrigger = .none { didSet { if mode != oldValue { refresh() } } }
    var holdDelay = 0.28
    var onPress: (TriggerContext) -> Void = { _ in }
    var onRelease: () -> Void = {}

    /// Marque nos clics rejoués pour ne pas les intercepter une seconde fois.
    private static let replayMarker: Int64 = 0x524E_4C54
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var hold = RightClickHold()
    private var holdTimer: Timer?
    private var pendingDown: CGEvent?
    private var pendingContext = TriggerContext.selection
    private var otherButtonDown = false
    private var loggedUntrusted = false

    var isRunning: Bool { tap != nil }

    /// (Ré)installe l'interception selon le mode ; ne fait rien tant que l'Accessibilité n'est pas accordée.
    func refresh() {
        stop()
        guard mode != .none else { return }
        guard AXIsProcessTrusted() else {
            if !loggedUntrusted {
                log.notice("Accessibilité non accordée, souris inactive (mode \(self.mode.rawValue, privacy: .public))")
            }
            loggedUntrusted = true
            return
        }
        loggedUntrusted = false
        let types: [CGEventType] = [.rightMouseDown, .rightMouseUp, .rightMouseDragged, .otherMouseDown, .otherMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<MouseTriggerTap>.fromOpaque(userInfo).takeUnretainedValue()
            // Le tap est ajouté à la boucle du fil principal ; CGEvent n'étant pas Sendable, le résultat sort par une variable.
            nonisolated(unsafe) var result: Unmanaged<CGEvent>? = Unmanaged.passUnretained(event)
            MainActor.assumeIsolated { result = owner.handle(type, event) }
            return result
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            log.error("Création de l'interception de la souris refusée par macOS")
            return
        }
        log.notice("Souris active (mode \(self.mode.rawValue, privacy: .public))")
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        holdTimer?.invalidate()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        hold = RightClickHold()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        default: break
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.replayMarker else { return pass }

        if let button = mode.otherButtonNumber {
            guard type == .otherMouseDown || type == .otherMouseUp,
                  event.getIntegerValueField(.mouseEventButtonNumber) == button else { return pass }
            if type == .otherMouseDown {
                otherButtonDown = true
                later { $0.onPress(.selection) }
            } else if otherButtonDown {
                otherButtonDown = false
                later { $0.onRelease() }
            }
            return nil
        }

        guard mode == .holdRight else { return pass }
        switch type {
        case .rightMouseDown:
            guard FinderHitTest.isFinder(at: event.location) else { return pass }
            pendingDown = event.copy()
            pendingContext = FinderHitTest.fileURL(at: event.location).map(TriggerContext.file)
                ?? .emptyArea(isDesktop: FinderHitTest.isDesktop(at: event.location))
            hold.down(at: event.location)
            holdTimer?.invalidate()
            holdTimer = Timer.scheduledTimer(withTimeInterval: holdDelay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.holdTimerFired() }
            }
            return nil
        case .rightMouseDragged:
            if hold.move(to: event.location) == .openRing { openFromHold() }
            return pass
        case .rightMouseUp:
            switch hold.up() {
            case .replayClick:
                holdTimer?.invalidate()
                if let down = pendingDown, let up = event.copy() { replay(down, up) }
                pendingDown = nil
                return nil
            case .releaseRing:
                pendingDown = nil
                later { $0.onRelease() }
                return nil
            case .openRing, .passThrough:
                return pass
            }
        default:
            return pass
        }
    }

    private func holdTimerFired() {
        if hold.timerFired() == .openRing { openFromHold() }
    }

    private func openFromHold() {
        holdTimer?.invalidate()
        let context = pendingContext
        later { $0.onPress(context) }
    }

    /// Clic rapide : on rejoue appui puis relâché, le Finder ouvre son menu comme d'habitude.
    private func replay(_ down: CGEvent, _ up: CGEvent) {
        for event in [down, up] {
            event.setIntegerValueField(.eventSourceUserData, value: Self.replayMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }

    /// Hors du rappel du tap : lire la sélection du Finder peut prendre du temps, et un tap trop lent est coupé.
    private func later(_ work: @escaping @MainActor (MouseTriggerTap) -> Void) {
        DispatchQueue.main.async { [weak self] in if let self { work(self) } }
    }
}
