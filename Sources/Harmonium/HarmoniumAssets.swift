import SwiftUI

// Loads the harmonium PNGs bundled as package resources.
enum HarmoniumAssets {
    // Native pixel dimensions — all share the same 1444px width.
    static let nativeWidth: CGFloat = 1444
    static let baseAspect: CGFloat = 850.0 / 1444.0    // base + key overlays
    static let top2Aspect: CGFloat = 55.0 / 1444.0     // bellows top cap
    static let bellowAspect: CGFloat = 33.0 / 1444.0   // one bellows stripe (native)

    static let base = image("base", subdirectory: "Resources")
    static let top2 = image("top2", subdirectory: "Resources")
    static let bellow = image("bellow-mid-stretch", subdirectory: "Resources")

    // Key overlays in note order: A S D F G H J
    static let keyFiles = ["A", "S", "D", "F", "G", "H", "J"]
    static let keys: [Image] = keyFiles.map { image($0, subdirectory: "Resources/Keys") }

    private static func image(_ name: String, subdirectory: String) -> Image {
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: subdirectory),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        print("[Harmonium] Missing asset: \(subdirectory)/\(name).png")
        return Image(systemName: "questionmark.square")
    }
}
