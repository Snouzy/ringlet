import Observation
import RingletCore
import SwiftUI

/// État affiché par `RingView` ; coordonnées de la fenêtre, origine en haut à gauche.
@MainActor @Observable final class RingModel {
    var actions: [FileAction] = []
    var geometry = RingGeometry.standard(count: 0)
    var look = RingLook()
    var center: CGPoint = .zero
    var hot: Int?
    /// Le curseur est revenu au centre après avoir visé : relâcher annule, la croix s'allume.
    var cancelHot = false
    /// Passe à true juste après l'affichage, pour jouer l'ouverture.
    var isOpen = false
    var showsRing = false
    var message: String?
    var messageIsError = false
    /// Action longue en cours (vidéo) : la bulle montre une roue au lieu d'une coche.
    var messageIsBusy = false
}
