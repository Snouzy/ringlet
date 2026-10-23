import AppKit
import ApplicationServices

/// Ce qu'il y a sous le curseur dans le Finder, par l'API d'Accessibilité (coordonnées écran, origine en haut à gauche).
enum FinderHitTest {
    private static let finderID = "com.apple.finder"

    /// true si l'élément sous `point` appartient au Finder (fenêtre ou bureau).
    static func isFinder(at point: CGPoint) -> Bool {
        guard let element = element(at: point) else { return false }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == finderID
    }

    /// true si `point` est sur le bureau (élément du Finder hors de toute fenêtre).
    static func isDesktop(at point: CGPoint) -> Bool {
        var current = element(at: point)
        for _ in 0..<12 {
            guard let element = current else { return true }
            if role(of: element) == kAXWindowRole as String { return false }
            current = attribute(element, kAXParentAttribute).map { $0 as! AXUIElement }
        }
        return false
    }

    /// Fichier sous `point` : l'élément touché, l'un de ses parents, ou une cellule de sa ligne.
    static func fileURL(at point: CGPoint) -> URL? {
        guard let hit = element(at: point) else { return nil }
        var current: AXUIElement? = hit
        for _ in 0..<8 {
            guard let element = current else { break }
            if let url = url(of: element) { return url }
            if role(of: element) == kAXRowRole as String, let url = firstURL(below: element, depth: 3) { return url }
            current = attribute(element, kAXParentAttribute).map { $0 as! AXUIElement }
        }
        return nil
    }

    private static func element(at point: CGPoint) -> AXUIElement? {
        var hit: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit)
        return status == .success ? hit : nil
    }

    private static func firstURL(below element: AXUIElement, depth: Int) -> URL? {
        guard depth > 0, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
        for child in children {
            if let url = url(of: child) ?? firstURL(below: child, depth: depth - 1) { return url }
        }
        return nil
    }

    /// Le Finder donne des URL de référence (`file:///.file/id=…`) : on les ramène à un chemin.
    private static func url(of element: AXUIElement) -> URL? {
        guard let value = attribute(element, kAXURLAttribute) else { return nil }
        let url = (value as? URL) ?? (value as? NSURL).map { $0 as URL }
        guard let url, url.isFileURL else { return nil }
        return (url as NSURL).filePathURL ?? url
    }

    private static func role(of element: AXUIElement) -> String? { attribute(element, kAXRoleAttribute) as? String }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}
