import SwiftUI
import AppKit

@main
struct HarmoniumApp: App {
    @State private var audioEngine = AudioEngine()
    @State private var lidSensor = LidSensor()
    @StateObject private var keyboardMonitor = KeyboardMonitor()

    init() {
        setvbuf(stdout, nil, _IONBF, 0)   // unbuffered logs for debugging
        setDockIcon()
    }

    private func setDockIcon() {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png", subdirectory: "Resources"),
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
