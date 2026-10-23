/// Style de l'anneau, choisi dans les réglages.
public enum RingStyle: String, Sendable, CaseIterable, Identifiable {
    /// V1 : disque de verre dépoli, secteur visé allumé comme une lentille teintée.
    case glass
    /// V2 : cadran sombre façon HUD, gradué, secteur visé marqué par un arc sur le bord.
    case dial
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .glass: "Verre"
        case .dial: "Cadran"
        }
    }
}

/// Couleur du secteur visé : celle choisie dans macOS, ou l'une des couleurs d'accent de macOS.
public enum RingAccent: String, Sendable, CaseIterable, Identifiable {
    case system, blue, purple, pink, red, orange, yellow, green, graphite
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: "Couleur de macOS"
        case .blue: "Bleu"
        case .purple: "Violet"
        case .pink: "Rose"
        case .red: "Rouge"
        case .orange: "Orange"
        case .yellow: "Jaune"
        case .green: "Vert"
        case .graphite: "Graphite"
        }
    }

    /// Couleur en 0xRRGGBB ; nil pour suivre la couleur d'accent du système.
    public var rgb: UInt32? {
        switch self {
        case .system: nil
        case .blue: 0x007AFF
        case .purple: 0xA550A7
        case .pink: 0xF74F9E
        case .red: 0xFF5257
        case .orange: 0xF7821B
        case .yellow: 0xFFC600
        case .green: 0x62BA46
        case .graphite: 0x8C8C8C
        }
    }
}

/// Opacité du verre (style Verre) : bornée pour que les icônes restent lisibles et qu'on voie encore le flou.
public enum GlassOpacity {
    public static let range = 0.3...0.95
    public static let standard = 0.72
    public static func clamped(_ value: Double) -> Double { min(max(value, range.lowerBound), range.upperBound) }
}
