import Foundation

// Resolves bundled resources without ever trapping.
//
// SwiftPM's `Bundle.module` calls `fatalError` when it cannot load its generated resource
// bundle. That bundle ships without an Info.plist, so it is not a valid macOS bundle: lenient
// Macs load it anyway, but stricter ones (recent macOS with the code-signing monitor) reject
// it, and the app crashes at launch before a window ever appears.
//
// To avoid that entirely, the packaged app copies the resources into its own bundle (which is
// always valid) and we look them up via `Bundle.main`. `swift run` has no such copy, so we fall
// back to a non-trapping search for the SPM module bundle. Either way, a miss returns nil
// instead of crashing.
enum AppResources {
    static func url(_ name: String, ext: String, subdirectory: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return u
        }
        if let bundle = moduleBundle,
           let u = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return u
        }
        return nil
    }

    // A non-trapping stand-in for `Bundle.module` (used only by `swift run`).
    private static let moduleBundle: Bundle? = {
        let bundleName = "Harmonium_Harmonium.bundle"
        let candidates: [URL?] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle(for: BundleToken.self).resourceURL,
            Bundle(for: BundleToken.self).bundleURL,
        ]
        for candidate in candidates {
            if let url = candidate?.appendingPathComponent(bundleName),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()

    private final class BundleToken {}
}
