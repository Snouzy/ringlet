import CoreGraphics
import Foundation

/// Géométrie du camembert, en coordonnées écran (y vers le bas, angles en degrés, 0° à droite, sens horaire).
/// Le premier secteur pointe vers le haut ; on choisit par la direction, entre la zone morte et le bord de l'anneau.
/// Au-delà du bord, rien n'est visé : relâcher là annule, comme sur la croix.
public struct RingGeometry: Sendable, Equatable {
    public var count: Int
    /// Rayon extérieur des secteurs.
    public var radius: Double
    /// Autour du centre, aucun secteur n'est visé.
    public var deadZone: Double

    public init(count: Int, radius: Double, deadZone: Double) {
        self.count = count; self.radius = radius; self.deadZone = deadZone
    }

    /// Valeurs du prototype R2a : rayon extérieur 114 pt (taille moyenne), zone morte 16 pt.
    public static func standard(count: Int, size: RingSize = .medium) -> RingGeometry {
        RingGeometry(count: count, radius: size.radius, deadZone: 16)
    }

    /// Rayon intérieur dessiné : un peu au-delà de la zone morte.
    public var innerRadius: Double { max(deadZone + 6, 24) }

    /// Distance au-delà de laquelle on est hors de l'anneau : son bord, plus une marge pour ne pas le rater de peu.
    public var reach: Double { radius + 12 }

    /// true dès qu'on a quitté la zone morte, dans l'anneau ou hors de lui.
    public func isAiming(dx: Double, dy: Double) -> Bool { (dx * dx + dy * dy).squareRoot() >= deadZone }

    public var sectorWidth: Double { count > 0 ? 360 / Double(count) : 0 }

    public func centerAngle(of index: Int) -> Double { -90 + Double(index) * sectorWidth }

    /// Secteur visé par un déplacement depuis le centre ; nil dans la zone morte et hors de l'anneau.
    public func sector(dx: Double, dy: Double) -> Int? {
        guard count > 0, isAiming(dx: dx, dy: dy), (dx * dx + dy * dy).squareRoot() <= reach else { return nil }
        let angle = atan2(dy, dx) * 180 / .pi
        // Décalé pour que le secteur 0 couvre [-90 - w/2, -90 + w/2[.
        let shifted = (angle + 90 + sectorWidth / 2).truncatingRemainder(dividingBy: 360)
        return Int((shifted < 0 ? shifted + 360 : shifted) / sectorWidth) % count
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
