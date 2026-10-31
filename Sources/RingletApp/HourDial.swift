import RingletCore
import SwiftUI

/// Cadran des réglages : chaque action sur son heure, à glisser vers une autre. Deux actions à la même heure
/// s'empilent vers le centre ; une action sans heure (un texte) est montrée là où l'anneau la mettrait.
struct HourDial: View {
    let actions: [FileAction]
    /// Heures effectives (défauts recouverts par les choix).
    let hours: [String: Int]
    let onMove: (FileAction, Int) -> Void

    @State private var drag: (id: String, translation: CGSize)?
    private let side: CGFloat = 400
    private let chipRadius: CGFloat = 148
    private var center: CGPoint { CGPoint(x: side / 2, y: side / 2) }

    private struct Chip: Identifiable {
        var action: FileAction
        var hour: Int
        var stack: Int
        var id: String { action.id }
    }

    private var chips: [Chip] {
        let placed = Dictionary(RingHours.place(actions, hours: hours).map { ($0.action.id, $0.hour) }) { first, _ in first }
        var counts: [Int: Int] = [:]
        return actions.compactMap { action in
            guard let hour = hours[action.id] ?? placed[action.id] else { return nil }
            defer { counts[hour, default: 0] += 1 }
            return Chip(action: action, hour: hour, stack: counts[hour, default: 0])
        }
    }

    /// L'heure sous une pastille en cours de glissement.
    private var target: Int? {
        guard let drag, let chip = chips.first(where: { $0.id == drag.id }) else { return nil }
        return hour(at: position(of: chip) + drag.translation)
    }

    var body: some View {
        ZStack {
            Circle().fill(.quaternary.opacity(0.35))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                .frame(width: side - 40, height: side - 40)
            Circle().fill(.quaternary.opacity(0.5)).frame(width: 36, height: 36)
                .overlay(Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary))
            ForEach(0..<RingHours.count, id: \.self) { hour in
                let angle = RingHours.angle(of: hour) * .pi / 180
                Text(verbatim: "\(hour == 0 ? 12 : hour)")
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(target == hour ? Color.accentColor : .secondary)
                    .position(x: center.x + cos(angle) * (side / 2 - 8), y: center.y + sin(angle) * (side / 2 - 8))
            }
            if let target {
                Circle().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: 60, height: 60)
                    .position(position(hour: target, stack: 0))
            }
            ForEach(chips) { chip in
                let dragging = drag?.id == chip.id
                chipView(chip)
                    .position(position(of: chip) + (dragging ? drag!.translation : .zero))
                    .zIndex(dragging ? 1 : 0)
                    .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .local)
                        .onChanged { drag = (chip.id, $0.translation) }
                        .onEnded { value in
                            if let hour = hour(at: position(of: chip) + value.translation), hour != chip.hour { onMove(chip.action, hour) }
                            drag = nil
                        })
                    .accessibilityLabel(String(localized: "\(chip.action.label), \(chip.hour == 0 ? 12 : chip.hour) o’clock"))
            }
        }
        .frame(width: side, height: side)
        .animation(.easeOut(duration: 0.15), value: drag == nil)
    }

    private func chipView(_ chip: Chip) -> some View {
        let dragging = drag?.id == chip.id
        return Group {
            if let symbol = chip.action.symbol {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
            } else {
                // Un texte long est coupé : la pastille doit tenir entre ses voisines.
                Text(String(chip.action.shortLabel.prefix(10))).font(.system(size: 12, weight: .bold)).lineLimit(1).fixedSize()
            }
        }
        .padding(.horizontal, 10).frame(minWidth: 36, minHeight: 28)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(dragging ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: dragging ? 2 : 1))
        .shadow(color: .black.opacity(dragging ? 0.25 : 0.1), radius: dragging ? 8 : 2, y: dragging ? 4 : 1)
        .help(chip.action.label)
    }

    private func position(of chip: Chip) -> CGPoint { position(hour: chip.hour, stack: chip.stack) }

    private func position(hour: Int, stack: Int) -> CGPoint {
        let angle = RingHours.angle(of: hour) * .pi / 180, radius = chipRadius - CGFloat(stack) * 36
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    /// Heure la plus proche de la direction du point ; nil près du centre.
    private func hour(at point: CGPoint) -> Int? {
        let dx = point.x - center.x, dy = point.y - center.y
        guard (dx * dx + dy * dy).squareRoot() > 26 else { return nil }
        let degrees = atan2(dy, dx) * 180 / .pi + 90
        let turn = (degrees / (360 / Double(RingHours.count))).rounded()
        return (Int(turn) % RingHours.count + RingHours.count) % RingHours.count
    }
}

private func + (point: CGPoint, size: CGSize) -> CGPoint { CGPoint(x: point.x + size.width, y: point.y + size.height) }
