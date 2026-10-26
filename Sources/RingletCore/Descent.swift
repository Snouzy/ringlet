import Foundation

/// « Redescendre », le pendant de « Remonter » : chaque remontée est retenue (dossier quitté, dossier atteint,
/// élément visé), et tant que la fenêtre montre encore le dossier atteint, on peut y revenir, niveau par niveau.
/// Comme « Suivant » dans le Finder, la pile s'oublie dès qu'on est allé ailleurs.
public struct Descent: Sendable, Equatable {
    public struct Step: Sendable, Equatable {
        /// Dossier atteint en remontant.
        public var parent: String
        /// Dossier quitté, où l'on redescend.
        public var child: String
        /// Élément visé avant de remonter, resélectionné en redescendant (nil pour l'anneau d'un dossier).
        public var item: String?

        public init(parent: String, child: String, item: String?) {
            self.parent = parent; self.child = child; self.item = item
        }
    }

    public private(set) var steps: [Step] = []

    public init() {}

    /// Une remontée de `child` à `parent`. Elle prolonge la pile si elle part de là où la précédente est arrivée.
    public mutating func wentUp(from child: String, to parent: String, item: String?) {
        let child = Self.normalized(child), parent = Self.normalized(parent)
        guard child != parent else { return }
        if steps.last?.parent != child { steps = [] }
        steps.append(Step(parent: parent, child: child, item: item.map(Self.normalized)))
    }

    /// Où redescendre depuis la fenêtre qui montre `folder` ; nil si on n'y est pas arrivé en remontant.
    public func step(showing folder: String) -> Step? {
        guard let last = steps.last, last.parent == Self.normalized(folder) else { return nil }
        return last
    }

    /// À l'ouverture de l'anneau : ailleurs que dans le dossier atteint, la pile est oubliée.
    public mutating func sync(showing folder: String) {
        if step(showing: folder) == nil { steps = [] }
    }

    /// Une descente faite : le niveau du dessous devient le suivant.
    public mutating func wentDown() {
        _ = steps.popLast()
    }

    /// Sans « / » final (sauf la racine), pour comparer les chemins du Finder et ceux des fichiers.
    static func normalized(_ path: String) -> String {
        var p = (path as NSString).standardizingPath
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// L'action de l'anneau : flèche vers le bas, avec le nom du dossier où l'on redescend.
    public static func action(for step: Step) -> FileAction {
        let name = (step.child as NSString).lastPathComponent
        return FileAction(kind: .goDown, shortLabel: String(localized: "Down"), symbol: "arrow.down",
                          label: String(localized: "Back down into “\(name)”"))
    }

    /// Place « Redescendre » en bas de l'anneau, à l'opposé de « Remonter » (secteur 0, en haut).
    /// Avec un nombre impair de secteurs, le plus proche du bas, juste à droite.
    public static func inserting(_ down: FileAction, into actions: [FileAction]) -> [FileAction] {
        var result = actions
        result.insert(down, at: (actions.count + 1) / 2)
        return result
    }
}
