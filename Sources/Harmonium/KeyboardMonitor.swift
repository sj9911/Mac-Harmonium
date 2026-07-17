import AppKit

final class KeyboardMonitor: ObservableObject {
    @Published private(set) var pressedNotes: Set<Int> = []

    private var localMonitor: Any?

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
        // Start immediately — don't wait for onAppear
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            // Only intercept our note keys without modifier keys
            let hasModifier = !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            guard Self.keyToNote[event.keyCode] != nil, !hasModifier else { return event }
            self.handle(event)
            return nil  // consume the event so the macOS accent popup never appears
        }
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // Called from ContentView.onAppear — monitoring is already running, these are no-ops
    func start() {}
    func stop() {}

    private func handle(_ event: NSEvent) {
        guard let noteIndex = Self.keyToNote[event.keyCode] else { return }
        if event.type == .keyDown {
            guard !event.isARepeat else { return }
            pressedNotes.insert(noteIndex)
        } else {
            pressedNotes.remove(noteIndex)
        }
    }
}
