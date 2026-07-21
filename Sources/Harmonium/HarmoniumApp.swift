import SwiftUI
import AppKit

@main
struct HarmoniumApp: App {
    @State private var audioEngine = AudioEngine()
    @State private var lidSensor = LidSensor()
    @StateObject private var keyboardMonitor = KeyboardMonitor()

    init() {
        setDockIcon()
    }

    private func setDockIcon() {
        if let url = AppResources.url("AppIcon", ext: "png", subdirectory: "Resources"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup("Mac Harmonium") {
            ContentView()
                .environment(audioEngine)
                .environment(lidSensor)
                .environmentObject(keyboardMonitor)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 780)
        .windowResizability(.contentSize)
    }
}
