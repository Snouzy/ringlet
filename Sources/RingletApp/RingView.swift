import RingletCore
import SwiftUI

/// Apparence de l'anneau, reprise des réglages.
struct RingLook: Equatable {
    var style = RingStyle.glass
    var accent = RingAccent.system
    var glassOpacity = GlassOpacity.standard
    var reduceMotion = false
}

extension RingAccent {
    var color: Color {
        guard let rgb else { return .accentColor }
        return Color(red: Double(rgb >> 16 & 0xFF) / 255, green: Double(rgb >> 8 & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}

/// Panneau plein écran : l'anneau sous le curseur, puis la bulle du résultat.
struct RingView: View {
    let model: RingModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if model.showsRing {
                RingFace(actions: model.actions, geometry: model.geometry, hot: model.hot, cancelHot: model.cancelHot,
                         isOpen: model.isOpen, look: model.look)
                    .position(model.center)
            }
            if let message = model.message {
                MessageBubble(text: message, isError: model.messageIsError, isBusy: model.messageIsBusy)
                    .position(model.center)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .ignoresSafeArea()
    }
}

/// L'anneau seul, en Verre (V1) ou en Cadran (V2) ; sert aussi à l'aperçu des réglages.
/// Premier secteur en haut, croix d'annulation au centre, libellé du secteur visé dessous.
struct RingFace: View {
    let actions: [FileAction]
    let geometry: RingGeometry
    let hot: Int?
    let cancelHot: Bool
    let isOpen: Bool
    let look: RingLook
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        Group {
            if look.style == .dial {
                // Le cadran est sombre sur tous les fonds, comme les HUD de volume.
                face.environment(\.colorScheme, .dark)
            } else {
                face
            }
        }
        .scaleEffect(isOpen ? 1 : 0.7)
        .opacity(isOpen ? 1 : 0)
        .animation(look.reduceMotion || systemReduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.7), value: isOpen)
    }

    private var face: some View {
        RingFaceContent(actions: actions, geometry: geometry, hot: hot, cancelHot: cancelHot, look: look)
    }
}

private struct RingFaceContent: View {
    let actions: [FileAction]
    let geometry: RingGeometry
    let hot: Int?
    let cancelHot: Bool
    let look: RingLook
    @Environment(\.colorScheme) private var scheme

    private var outer: Double { geometry.radius }
    private var inner: Double { max(geometry.innerRadius, outer * 0.26) }
    private var accent: Color { look.accent.color }
    private var isGlass: Bool { look.style == .glass }
    private var hotIndex: Int? { hot.flatMap { actions.indices.contains($0) ? $0 : nil } }

    var body: some View {
        ZStack {
            if isGlass { glassDisc } else { dialDisc }
            Spokes(count: actions.count, from: inner + 2, to: outer - (isGlass ? 8 : 16))
                .stroke(isGlass ? Color.white.opacity(scheme == .dark ? 0.2 : 0.55) : Color.white.opacity(0.07), lineWidth: 1)
            if let index = hotIndex { hotMark(index) }
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                icon(action, index: index)
            }
            hub
            caption
        }
        .frame(width: outer * 2, height: outer * 2)
        .animation(.easeOut(duration: 0.1), value: hot)
        .animation(.easeOut(duration: 0.1), value: cancelHot)
    }

    // MARK: Fonds

    private var glassDisc: some View {
        let shine = scheme == .dark ? 0.45 : 1.0
        return Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().fill(Color(nsColor: .windowBackgroundColor).opacity(look.glassOpacity)))
            .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.32 * shine), .white.opacity(0.03), .white.opacity(0.16 * shine)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.85 * shine), .white.opacity(0.1), .white.opacity(0.35 * shine)],
                                                          startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }

    private var dialDisc: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().fill(RadialGradient(colors: [Color(white: 0.18).opacity(0.84), Color(white: 0.07).opacity(0.9)],
                                                  center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: outer)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            .overlay(Ticks(count: actions.count, outer: outer, major: false).stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.2, lineCap: .round)))
            .overlay(Ticks(count: actions.count, outer: outer, major: true).stroke(Color.white.opacity(0.42), style: StrokeStyle(lineWidth: 1.2, lineCap: .round)))
            .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
    }

    // MARK: Secteur visé

    @ViewBuilder private func hotMark(_ index: Int) -> some View {
        let mid = geometry.centerAngle(of: index), half = geometry.sectorWidth / 2
        if isGlass {
            RoundedSector(start: mid - half, end: mid + half, inner: inner + 3, outer: outer - 6, gap: 5, corner: 5)
                .filled(accent, opacity: 0.9)
                .shadow(color: accent.opacity(0.6), radius: 10)
        } else {
            ZStack {
                RoundedSector(start: mid - half, end: mid + half, inner: inner + 2, outer: outer - 15, gap: 5, corner: 5)
                    .filled(accent, opacity: 0.24)
                Bezel(start: mid - half + 5, end: mid + half - 5, radius: outer - 7.5)
                    .stroke(accent, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .shadow(color: accent, radius: 6)
            }
        }
    }

    private func icon(_ action: FileAction, index: Int) -> some View {
        let mid = geometry.centerAngle(of: index) * .pi / 180
        let radius = (inner + outer) / 2 + (isGlass ? 2 : -3)
        let isHot = hotIndex == index
        return Group {
            if let symbol = action.symbol {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
            } else {
                // Libellé d'un texte : deux lignes au plus, rétréci plutôt que coupé.
                Text(action.shortLabel).font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                    .frame(width: min(76, 2 * .pi * radius / Double(max(actions.count, 1)) * 0.85))
            }
        }
        .foregroundStyle(isHot ? Color.white : Color.primary.opacity(isGlass ? 1 : 0.86))
        .scaleEffect(isHot ? 1.1 : 1)
        .offset(x: cos(mid) * radius, y: sin(mid) * radius)
        .accessibilityLabel(action.label)
    }

    // MARK: Centre et libellé

    private var hub: some View {
        let size = (inner - 5) * 2
        return ZStack {
            if cancelHot {
                Circle().fill(Color.red)
            } else if isGlass {
                Circle().fill(.ultraThinMaterial)
                    .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.16 : 0.45), .white.opacity(0.05)],
                                                          startPoint: .top, endPoint: .bottom)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(scheme == .dark ? 0.25 : 0.7), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
            } else {
                Circle().fill(Color.white.opacity(0.06)).overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            }
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(cancelHot ? Color.white : Color.secondary)
        }
        .frame(width: size, height: size)
        .scaleEffect(cancelHot ? 1.08 : 1)
    }

    @ViewBuilder private var caption: some View {
        if let text = hotIndex.map({ actions[$0].label }) ?? (cancelHot ? String(localized: "Cancel") : nil) {
            // Pastille pleine de la couleur du secteur visé (rouge pour annuler) : lisible sur n'importe quel fond.
            let fill = cancelHot ? Color.red : accent
            Text(text)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(look.accent == .yellow && !cancelHot ? Color.black.opacity(0.85) : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(fill, in: Capsule())
                .shadow(color: fill.opacity(0.55), radius: 10, y: 5)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                .fixedSize()
                .offset(y: outer + 26)
        }
    }
}

// MARK: - Formes (angles en degrés, sens horaire à l'écran, centre du cadre)

/// Secteur aux bords parallèles (écart constant en points) et aux coins arrondis. Près du centre, un grand
/// arrondi mange le bord intérieur : on garde `corner` petit.
struct RoundedSector: Shape {
    var start: Double
    var end: Double
    var inner: Double
    var outer: Double
    var gap: Double
    var corner: Double

    /// Le cœur du secteur, rétréci de `corner` de chaque côté ; `filled` lui ajoute un contour rond de 2 × corner.
    func path(in rect: CGRect) -> Path {
        Self.sector(center: CGPoint(x: rect.midX, y: rect.midY), start: start, end: end,
                    inner: inner + corner, outer: outer - corner, gap: gap + 2 * corner)
    }

    /// Rempli et contouré de la même couleur, l'opacité posée sur l'ensemble pour ne pas doubler sur le contour.
    func filled(_ color: Color, opacity: Double) -> some View {
        ZStack {
            fill(color)
            stroke(color, style: StrokeStyle(lineWidth: 2 * corner, lineJoin: .round))
        }
        .compositingGroup()
        .opacity(opacity)
    }

    static func sector(center: CGPoint, start: Double, end: Double, inner: Double, outer: Double, gap: Double) -> Path {
        let outerInset = gap / 2 / outer * 180 / .pi, innerInset = gap / 2 / inner * 180 / .pi
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: .degrees(start + outerInset), endAngle: .degrees(end - outerInset), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: .degrees(end - innerInset), endAngle: .degrees(start + innerInset), clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// Séparations entre les secteurs.
private struct Spokes: Shape {
    var count: Int
    var from: Double
    var to: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 1 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY), width = 360 / Double(count)
        for index in 0..<count {
            let angle = (-90 + Double(index) * width - width / 2) * .pi / 180
            path.move(to: CGPoint(x: center.x + cos(angle) * from, y: center.y + sin(angle) * from))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * to, y: center.y + sin(angle) * to))
        }
        return path
    }
}

/// Graduation du cadran : un trait fort à chaque limite de secteur, sept traits fins entre deux.
private struct Ticks: Shape {
    var count: Int
    var outer: Double
    var major: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY), width = 360 / Double(count)
        for index in 0..<count {
            for step in 0..<8 where (step == 0) == major {
                let angle = (-90 + Double(index) * width - width / 2 + Double(step) * width / 8) * .pi / 180
                let length = major ? 11.0 : 8.0
                path.move(to: CGPoint(x: center.x + cos(angle) * (outer - 4), y: center.y + sin(angle) * (outer - 4)))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * (outer - length), y: center.y + sin(angle) * (outer - length)))
            }
        }
        return path
    }
}

/// Arc lumineux du cadran, sur le bord du secteur visé.
private struct Bezel: Shape {
    var start: Double
    var end: Double
    var radius: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: radius,
                    startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        return path
    }
}

private struct MessageBubble: View {
    let text: String
    let isError: Bool
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 7) {
            if isBusy {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isError ? Color.orange : Color.green)
            }
            Text(text).font(.system(size: 13, weight: .semibold)).lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .frame(maxWidth: 420)
        .fixedSize()
    }
}
