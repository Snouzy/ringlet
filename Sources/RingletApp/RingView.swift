import RingletCore
import SwiftUI

/// Camembert R2a : secteurs pleins, premier en haut, libellé du secteur visé sous l'anneau.
struct RingView: View {
    let model: RingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if model.showsRing { ring.position(model.center) }
            if let message = model.message {
                MessageBubble(text: message, isError: model.messageIsError, isBusy: model.messageIsBusy)
                    .position(model.center)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .ignoresSafeArea()
    }

    private var ring: some View {
        let g = model.geometry, outer = g.radius, inner = g.innerRadius
        let gap = g.count > 1 ? 1.2 : 0
        return ZStack {
            ForEach(Array(model.actions.enumerated()), id: \.element.id) { index, action in
                let mid = g.centerAngle(of: index)
                let isHot = model.hot == index
                let labelRadius = (inner + outer) / 2
                ZStack {
                    Sector(start: mid - g.sectorWidth / 2 + gap, end: mid + g.sectorWidth / 2 - gap, inner: inner, outer: outer)
                        .fill(isHot ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial))
                    Sector(start: mid - g.sectorWidth / 2 + gap, end: mid + g.sectorWidth / 2 - gap, inner: inner, outer: outer)
                        .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                    Group {
                        if let symbol = action.symbol {
                            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                        } else {
                            Text(action.shortLabel).font(.system(size: 13, weight: .bold, design: .monospaced))
                        }
                    }
                    .foregroundStyle(isHot ? Color.white : Color.primary)
                    .offset(x: cos(mid * .pi / 180) * labelRadius, y: sin(mid * .pi / 180) * labelRadius)
                    .accessibilityLabel(action.label)
                }
                .scaleEffect(model.isOpen ? 1 : 0.5)
                .opacity(model.isOpen ? 1 : 0)
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.9, 0.3, 1.2, duration: 0.18).delay(Double(index) * 0.014),
                           value: model.isOpen)
                .animation(.easeOut(duration: 0.09), value: isHot)
            }
            // Centre : la croix pour annuler (clic, ou retour au centre puis relâché).
            Circle()
                .fill(model.cancelHot ? AnyShapeStyle(Color.red.opacity(0.85)) : AnyShapeStyle(.regularMaterial))
                .overlay(Circle().stroke(Color.primary.opacity(0.14), lineWidth: 1))
                .overlay(Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(model.cancelHot ? Color.white : Color.secondary))
                .frame(width: (inner - 4) * 2, height: (inner - 4) * 2)
                .opacity(model.isOpen ? 1 : 0)
                .animation(.easeOut(duration: 0.09), value: model.cancelHot)
            if let caption = model.hot.flatMap({ model.actions.indices.contains($0) ? model.actions[$0].label : nil })
                ?? (model.cancelHot ? "Annuler" : nil) {
                Text(caption)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.14), lineWidth: 1))
                    .fixedSize()
                    .offset(y: outer + 22)
            }
        }
        .frame(width: outer * 2, height: outer * 2)
        .shadow(color: .black.opacity(0.25), radius: 15, y: 7)
    }
}

/// Secteur d'anneau entre deux angles (degrés, sens horaire à l'écran), centré dans son cadre.
struct Sector: Shape {
    var start: Double
    var end: Double
    var inner: Double
    var outer: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: .degrees(end), endAngle: .degrees(start), clockwise: true)
        path.closeSubpath()
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
