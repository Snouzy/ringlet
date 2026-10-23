import CoreGraphics

/// Clic droit maintenu : un clic rapide garde le menu habituel (il est rejoué), un appui tenu au-delà du délai
/// ou un déplacement au-delà du seuil ouvre l'anneau, et le relâché choisit.
public struct RightClickHold: Sendable, Equatable {
    public enum Decision: Sendable, Equatable {
        /// Ouvrir l'anneau maintenant.
        case openRing
        /// Relâché après ouverture : choisir le secteur visé.
        case releaseRing
        /// Clic rapide : rejouer appui et relâché pour que l'app sous la souris montre son menu.
        case replayClick
        /// Rien à voir avec un appui suivi : laisser passer l'évènement.
        case passThrough
    }

    private enum Phase: Sendable, Equatable { case idle, pending(CGPoint), open }

    public var moveThreshold: Double
    private var phase = Phase.idle

    public init(moveThreshold: Double = 6) { self.moveThreshold = moveThreshold }

    public var isPending: Bool { if case .pending = phase { true } else { false } }

    public mutating func down(at point: CGPoint) { phase = .pending(point) }

    public mutating func move(to point: CGPoint) -> Decision? {
        guard case .pending(let start) = phase,
              hypot(point.x - start.x, point.y - start.y) > moveThreshold else { return nil }
        phase = .open
        return .openRing
    }

    public mutating func timerFired() -> Decision? {
        guard isPending else { return nil }
        phase = .open
        return .openRing
    }

    public mutating func up() -> Decision {
        defer { phase = .idle }
        switch phase {
        case .idle: return .passThrough
        case .pending: return .replayClick
        case .open: return .releaseRing
        }
    }
}

/// Taille de l'anneau choisie dans les réglages (rayon extérieur en points).
public enum RingSize: String, Sendable, CaseIterable, Identifiable {
    case small, medium, large
    public var id: String { rawValue }
    public var radius: Double {
        switch self {
        case .small: 96
        case .medium: 114
        case .large: 134
        }
    }
    public var label: String {
        switch self {
        case .small: "Petit"
        case .medium: "Moyen"
        case .large: "Grand"
        }
    }
}
