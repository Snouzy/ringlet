import Foundation

/// Où va chaque action : son heure sur un cadran de douze, choisie dans les réglages. L'anneau garde chaque action
/// présente à son heure, et son secteur s'étend jusqu'à mi-chemin des voisines (`RingGeometry(angles:)`) : la
/// direction d'une action ne bouge pas quand d'autres manquent.
public enum RingHours {
    public static let count = 12

    /// Angle écran de l'heure : 12 h en haut, puis dans le sens horaire.
    public static func angle(of hour: Int) -> Double { -90 + Double(hour) * 360 / Double(count) }

    /// Heures par défaut de l'anneau des fichiers et du dossier. Deux actions qui ne se présentent jamais ensemble
    /// partagent une heure (JPG et MP4, PNG et 720p, GPS et M4A).
    public static let fileDefaults: [String: Int] = [
        ActionKind.goUp.rawValue: 0, ActionKind.quickLook.rawValue: 1,
        ActionKind.convertToJPEG.rawValue: 2, ActionKind.videoToMP4.rawValue: 2,
        ActionKind.convertToPNG.rawValue: 3, ActionKind.videoTo720p.rawValue: 3,
        ActionKind.removeGPS.rawValue: 4, ActionKind.extractAudio.rawValue: 4,
        ActionKind.copyPath.rawValue: 5, ActionKind.goDown.rawValue: 6, ActionKind.newFolder.rawValue: 7,
        ActionKind.openEditor.rawValue: 8, ActionKind.openTerminal.rawValue: 9, ActionKind.revealCopiedPath.rawValue: 10,
    ]

    /// Anneau des textes : « Coller » en haut, le chemin copié à 11 h ; les textes sans heure se répartissent.
    public static let textDefaults: [String: Int] = [ActionKind.paste.rawValue: 0, ActionKind.revealCopiedPath.rawValue: 11]

    /// Les actions avec leur heure, dans le sens horaire. Une action à l'heure choisie ; deux à la même heure,
    /// la seconde (dans l'ordre donné) prend l'heure libre suivante ; celles sans heure vont chacune à l'heure la plus
    /// éloignée de toutes les autres (puis des heures choisies), et se suivent dans l'ordre donné autour du cadran.
    /// Au-delà de douze, les dernières sans heure sont laissées de côté.
    public static func place(_ actions: [FileAction], hours: [String: Int]) -> [(action: FileAction, hour: Int)] {
        var taken = Set<Int>(), placed: [(action: FileAction, hour: Int)] = [], bumped: [(FileAction, Int)] = []
        for action in actions {
            guard let wanted = hours[action.id] else { continue }
            let hour = ((wanted % count) + count) % count
            if taken.insert(hour).inserted { placed.append((action, hour)) } else { bumped.append((action, hour)) }
        }
        for (action, wanted) in bumped {
            var hour = wanted
            while taken.contains(hour) && taken.count < count { hour = (hour + 1) % count }
            guard taken.insert(hour).inserted else { continue }
            placed.append((action, hour))
        }
        let pinned = taken
        func distance(_ hour: Int, to set: Set<Int>) -> Int {
            set.map { abs(hour - $0) }.map { min($0, count - $0) }.min() ?? count
        }
        var chosen: [Int] = []
        let loose = actions.filter { hours[$0.id] == nil }
        for _ in loose where taken.count < count {
            let free = (0..<count).filter { !taken.contains($0) }
            let best = free.max { (distance($0, to: taken), distance($0, to: pinned), -$0) < (distance($1, to: taken), distance($1, to: pinned), -$1) }!
            taken.insert(best)
            chosen.append(best)
        }
        for (action, hour) in zip(loose, chosen.sorted()) { placed.append((action, hour)) }
        return placed.sorted { $0.hour < $1.hour }
    }

    /// Les actions dans l'ordre de l'anneau et l'angle de chacune : son heure, écartée de ses voisines quand
    /// l'anneau est clairsemé (`spread`). Plus de douze actions : secteurs égaux.
    public static func layout(_ actions: [FileAction], hours: [String: Int]) -> (actions: [FileAction], angles: [Double]) {
        guard actions.count <= count else {
            let width = 360 / Double(actions.count)
            return (actions, actions.indices.map { -90 + Double($0) * width })
        }
        let placed = place(actions, hours: hours)
        return (placed.map(\.action), spread(placed.map { angle(of: $0.hour) }))
    }

    /// Écart minimum entre deux voisines, en degrés : une heure (30°) dès huit actions, les heures sont alors
    /// exactes ; plus large quand l'anneau est clairsemé (60° à cinq, 72° à quatre ou moins), pour que peu
    /// d'actions ne se tassent pas d'un côté.
    public static func minimumGap(count: Int) -> Double { count >= 8 ? 30 : min(72, 300 / Double(max(count, 1))) }

    /// Les mêmes angles, les voisines trop proches repoussées à égalité de part et d'autre, dans le même ordre
    /// autour du cercle ; une action loin de ses voisines ne bouge pas.
    public static func spread(_ angles: [Double]) -> [Double] {
        guard angles.count > 1 else { return angles }
        let gap = minimumGap(count: angles.count)
        let order = angles.indices.sorted { RingGeometry.normalized(angles[$0]) < RingGeometry.normalized(angles[$1]) }
        // Positions « déroulées », croissantes le long du cercle : les écarts sont signés, une poussée ne peut pas
        // faire passer une action de l'autre côté de sa voisine sans qu'on le voie.
        var unrolled = [RingGeometry.normalized(angles[order[0]])]
        for rank in 1..<order.count {
            unrolled.append(unrolled[rank - 1] + RingGeometry.normalized(angles[order[rank]] - angles[order[rank - 1]]))
        }
        let initial = unrolled
        for _ in 0..<400 {
            var moved = false
            for rank in order.indices {
                let next = (rank + 1) % order.count
                let distance = (next == 0 ? unrolled[0] + 360 : unrolled[next]) - unrolled[rank]
                let deficit = gap - distance
                guard deficit > 0.001 else { continue }
                unrolled[rank] -= deficit / 2
                unrolled[next] += deficit / 2
                moved = true
            }
            if !moved { break }
        }
        var result = angles
        for (rank, index) in order.enumerated() { result[index] = ((angles[index] + unrolled[rank] - initial[rank]) * 100).rounded() / 100 }
        return result
    }

    /// L'anneau prêt à afficher : ses actions dans le sens horaire et sa géométrie.
    public static func ring(_ actions: [FileAction], hours: [String: Int], size: RingSize) -> (actions: [FileAction], geometry: RingGeometry) {
        let laid = layout(actions, hours: hours)
        return (laid.actions, RingGeometry(angles: laid.angles, radius: size.radius, deadZone: 16))
    }
}
