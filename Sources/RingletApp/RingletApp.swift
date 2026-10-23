import AppKit
import SwiftUI

@main
struct RingletApp: App {
    var body: some Scene {
        MenuBarExtra("Ringlet", systemImage: "circle.dashed") {
            Button("Quitter Ringlet") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
