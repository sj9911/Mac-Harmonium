import AppKit

final class KeyboardMonitor: ObservableObject {
    @Published private(set) var pressedNotes: Set<Int> = []

    private var localMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    // ADB key codes: H=4, G=5 (counterintuitive but correct)
    private static let keyToNote: [UInt16: Int] = [
        0: 0,   // A → Sa
        1: 1,   // S → Re
        2: 2,   // D → Ga
        3: 3,   // F → Ma
        5: 4,   // G → Pa
        4: 5,   // H → Dha
        38: 6,  // J → Ni
    ]

    init() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, let note = Self.keyToNote[event.keyCode] else { return event }

            if event.type == .keyUp {
                // Always release a note we started, even if a modifier is now held
                // (e.g. the key is let go while reaching for Cmd-Tab). Otherwise it sticks.
                guard self.pressedNotes.contains(note) else { return event }
                self.pressedNotes.remove(note)
                return nil
            }

            // keyDown: don't hijack modifier combos (Cmd-Q, Cmd-Tab, and friends).
            let hasModifier = !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            guard !hasModifier else { return event }
            if !event.isARepeat { self.pressedNotes.insert(note) }
            return nil  // consume the event so the macOS accent popup never appears
        }

        // If the app loses focus mid-press, the keyUp never arrives — clear held notes.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.pressedNotes.removeAll()
        }
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    }

    // Monitoring starts in init and lives for the app's lifetime; these keep the
    // ContentView call sites simple.
    func start() {}
    func stop() {}
}
