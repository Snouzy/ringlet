import CoreGraphics
import Foundation

/// Géométrie du camembert, en coordonnées écran (y vers le bas, angles en degrés, 0° à droite, sens horaire).
/// Chaque secteur a son angle (son heure) ; on choisit par la direction, entre la zone morte et le bord de l'anneau.
/// Au-delà du bord, rien n'est visé : relâcher là annule, comme sur la croix.
public struct RingGeometry: Sendable, Equatable {
    /// Un secteur : son angle (celui de l'icône et de l'heure choisie) et ses bornes, en degrés.
    public struct Sector: Sendable, Equatable {
        public var mid: Double
        public var start: Double
        public var end: Double
    }

    public var sectors: [Sector]
    /// Rayon extérieur des secteurs.
    public var radius: Double
    /// Autour du centre, aucun secteur n'est visé.
    public var deadZone: Double

    /// `count` secteurs égaux, le premier en haut.
    public init(count: Int, radius: Double, deadZone: Double) {
        let width = count > 0 ? 360 / Double(count) : 0
        self.init(angles: (0..<max(count, 0)).map { -90 + Double($0) * width }, radius: radius, deadZone: deadZone)
    }

    /// Un secteur par angle, dans l'ordre donné ; chacun s'étend jusqu'à mi-chemin de ses voisins sur le cercle,
    /// de sorte qu'une action garde sa direction quand ses voisines manquent. Un seul angle : tout l'anneau.
    public init(angles: [Double], radius: Double, deadZone: Double) {
        let order = angles.indices.sorted { Self.normalized(angles[$0]) < Self.normalized(angles[$1]) }
        var sectors = [Sector](repeating: Sector(mid: 0, start: 0, end: 0), count: angles.count)
        for (rank, index) in order.enumerated() {
            let mid = angles[index]
            guard angles.count > 1 else { sectors[index] = Sector(mid: mid, start: mid - 180, end: mid + 180); break }
            let previous = angles[order[(rank + order.count - 1) % order.count]], next = angles[order[(rank + 1) % order.count]]
            let before = Self.normalized(mid - previous), after = Self.normalized(next - mid)
            sectors[index] = Sector(mid: mid, start: mid - (before == 0 ? 360 : before) / 2, end: mid + (after == 0 ? 360 : after) / 2)
        }
        self.sectors = sectors; self.radius = radius; self.deadZone = deadZone
    }

    /// Valeurs du prototype R2a : rayon extérieur 114 pt (taille moyenne), zone morte 16 pt.
    public static func standard(count: Int, size: RingSize = .medium) -> RingGeometry {
        RingGeometry(count: count, radius: size.radius, deadZone: 16)
    }

    public var count: Int { sectors.count }

    /// Rayon intérieur dessiné : un peu au-delà de la zone morte.
    public var innerRadius: Double { max(deadZone + 6, 24) }

    /// Distance au-delà de laquelle on est hors de l'anneau : son bord, plus une marge pour ne pas le rater de peu.
    public var reach: Double { radius + 12 }

    /// true dès qu'on a quitté la zone morte, dans l'anneau ou hors de lui.
    public func isAiming(dx: Double, dy: Double) -> Bool { (dx * dx + dy * dy).squareRoot() >= deadZone }

    public func centerAngle(of index: Int) -> Double { sectors[index].mid }

    public func bounds(of index: Int) -> (start: Double, end: Double) { (sectors[index].start, sectors[index].end) }

    /// Secteur visé par un déplacement depuis le centre ; nil dans la zone morte et hors de l'anneau.
    public func sector(dx: Double, dy: Double) -> Int? {
        guard count > 0, isAiming(dx: dx, dy: dy), (dx * dx + dy * dy).squareRoot() <= reach else { return nil }
        let angle = atan2(dy, dx) * 180 / .pi
        return sectors.firstIndex { sector in
            sector.end - sector.start >= 360 || Self.normalized(angle - sector.start) < Self.normalized(sector.end - sector.start)
        }
    }

    /// Angle ramené dans [0, 360[.
    public static func normalized(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Centre ramené pour que l'anneau tienne entier dans `bounds` ; centré sur l'axe trop étroit pour lui.
    public static func clampedCenter(_ point: CGPoint, outerRadius: Double, in bounds: CGRect) -> CGPoint {
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            low > high ? (low + high) / 2 : min(max(value, low), high)
        }
        let r = CGFloat(outerRadius)
        return CGPoint(x: clamp(point.x, bounds.minX + r, bounds.maxX - r),
                       y: clamp(point.y, bounds.minY + r, bounds.maxY - r))
    }
}
