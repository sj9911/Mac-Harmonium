import SwiftUI

// Availability shims so the app runs on macOS 14+ while still using Apple's
// Liquid Glass on macOS 26.

extension View {
    /// Apple Liquid Glass on macOS 26+, a frosted material fallback on older macOS.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                glassEffect(.regular.interactive(), in: shape)
            } else {
                glassEffect(.regular, in: shape)
            }
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }

    /// Grab cursor on macOS 15+ (open hand at rest, closed hand while dragging).
    /// No-op on macOS 14, where the API doesn't exist.
    @ViewBuilder
    func grabPointer(_ active: Bool) -> some View {
        if #available(macOS 15.0, *) {
            pointerStyle(active ? .grabActive : .grabIdle)
        } else {
            self
        }
    }
}
