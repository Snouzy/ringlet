import AppKit
import RingletCore

/// Icône de la barre des menus : le camembert à quatre secteurs, en image « modèle » (suit la couleur du menu).
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let ring = RingGeometry(count: 4, radius: 8, deadZone: 0)
            for index in 0..<4 {
                let mid = ring.centerAngle(of: index)
                let path = NSBezierPath()
                // Repère retourné (y vers le bas) : les angles croissent dans le sens horaire, comme l'anneau.
                path.appendArc(withCenter: center, radius: 8, startAngle: mid - 39, endAngle: mid + 39, clockwise: false)
                path.appendArc(withCenter: center, radius: 3.2, startAngle: mid + 39, endAngle: mid - 39, clockwise: true)
                path.close()
                NSColor.black.withAlphaComponent(index == 0 ? 1 : 0.55).setFill()
                path.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
