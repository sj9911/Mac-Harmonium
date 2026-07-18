import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AudioEngine.self) private var audio
    @Environment(LidSensor.self) private var lid
    @EnvironmentObject private var keys: KeyboardMonitor

    @State private var isIdle = false
    @State private var idleSeconds = 0.0
    private let idleTick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    // Hint: shown when the user taps keys but isn't pumping (so there's no sound).
    // Shows for a few seconds, then hides with a 30s cooldown before it can reappear.
    @State private var showHint = false
    @State private var silentTaps = 0
    @State private var emptyTicks = 0
    @State private var hintTicks = 0        // how long it's been shown (idleTicks)
    @State private var cooldownTicks = 0    // remaining cooldown (idleTicks)

    // Mouse-drag bellows control (a synthetic "tilt" the mouse can drive)
    @State private var manualMode = false     // mouse is driving instead of the sensor
    @State private var dragging = false
    @State private var dragOpen = 0.0         // 0…1 bellows openness from the drag
    @State private var dragStartOpen = 0.0
    @State private var dragVel = 0.0          // signed "pump" velocity from the drag
    @State private var pumpTick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // Effective tilt — from the mouse when dragging, else the lid sensor.
    private var sensorOpen: Double { min(abs(lid.smoothAngle - 90) / 26.7, 1) }
    private var openness: Double { manualMode ? dragOpen : sensorOpen }
    private var effVelocity: Double { manualMode ? dragVel : lid.signedVelocity }
    private var effDriftAngle: Double { manualMode ? (90 + (dragOpen - 0.5) * 80) : lid.smoothAngle }

    var body: some View {
        ZStack {
            // Apple Liquid Glass over the transparent window
            Color.clear
                .liquidGlass(in: Rectangle())
                .ignoresSafeArea()

            // Light wash — keeps the backdrop light regardless of desktop / dark mode
            Color(red: 0xe0 / 255, green: 0xdf / 255, blue: 0xdc / 255)
                .opacity(0.55)
                .ignoresSafeArea()

            // Reactive dotted field — ripples on key press, drifts with lid tilt
            DotsField(lidAngle: effDriftAngle, pressedNotes: keys.pressedNotes)
                .ignoresSafeArea()

            // Air-flow streaks + current lines — flow in the pump direction
            AirFlow(lidVelocity: effVelocity)
                .ignoresSafeArea()

            // Tilt glow — sits over the dots (translucent, so they show through tinted)
            TiltGlow(lidVelocity: effVelocity, pressedNotes: keys.pressedNotes)
                .ignoresSafeArea()

            HarmoniumView(
                openness: openness,
                pressedNotes: keys.pressedNotes,
                isIdle: isIdle,
                onDragChange: { th, vh in
                    if !dragging { dragging = true; dragStartOpen = openness }
                    manualMode = true
                    dragOpen = min(max(dragStartOpen + Double(-th) / 180.0, 0), 1)
                    // Pump the velocity UP toward the drag speed, but never drop it
                    // instantly — let pumpTick decay it slowly (so it lingers like the lid).
                    let target = min(max(Double(-vh) / 30.0, -26), 26)
                    if abs(target) > abs(dragVel) { dragVel = target }
                },
                onDragEnd: { dragging = false }
            )
            .padding(.horizontal, 64)
            .padding(.top, 56)
            .padding(.bottom, 72)
        }
        .overlay(alignment: .top) {
            if showHint {
                HintBanner()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomLeading) {
            VersionBadge().padding(18)
        }
        .overlay(alignment: .bottomTrailing) {
            CreditBadge().padding(18)
        }
        .background(WindowConfigurator())
        .onReceive(pumpTick) { _ in
            if manualMode {
                dragVel *= 0.991                             // slow, lingering air fade
                if abs(dragVel) < 0.03 { dragVel = 0 }
                if lid.velocity > 3 { manualMode = false }   // real lid takes over
            }
            let vmag = manualMode ? abs(dragVel) : lid.velocity
            // Drag is more sensitive (/15) than the lid (/18) so small pumps give volume.
            let scale = manualMode ? 15.0 : 18.0
            audio.airPressure = Float(min(vmag / scale, 1.0))
        }
        .onReceive(idleTick) { _ in
            // Active = lid moving, key held, or mouse-dragging the bellows.
            let active = lid.velocity > 1.0 || !keys.pressedNotes.isEmpty || dragging || abs(dragVel) > 0.2
            if active {
                idleSeconds = 0
                isIdle = false
            } else {
                idleSeconds += 0.25
                if idleSeconds >= 1.5 { isIdle = true }
            }

            // Hint lifecycle (idleTick = 0.25s): show ~4s, then 30s cooldown.
            if showHint {
                hintTicks += 1
                if hintTicks >= 16 || audio.airPressure > 0.08 {   // ~4s, or they started pumping
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showHint = false }
                    cooldownTicks = 120   // 30s before it can appear again
                    silentTaps = 0
                }
            } else if cooldownTicks > 0 {
                cooldownTicks -= 1
                silentTaps = 0
            } else if keys.pressedNotes.isEmpty {
                emptyTicks += 1
                if emptyTicks >= 4 { silentTaps = 0 }   // ~1s without a tap → reset the counter
            } else {
                emptyTicks = 0
            }
        }
        .onChange(of: keys.pressedNotes) { old, notes in
            audio.activeNotes = notes
            // A new key pressed with no air (from lid OR mouse) → count it; several in a
            // row shows the hint, unless we're already showing it or in cooldown.
            if notes.count > old.count && audio.airPressure < 0.08 && !showHint && cooldownTicks == 0 {
                silentTaps += 1
                if silentTaps >= 4 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showHint = true }
                    hintTicks = 0
                    silentTaps = 0
                }
            }
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            lid.start()
            keys.start()
        }
        .onDisappear {
            lid.stop()
            keys.stop()
        }
        .preferredColorScheme(.light)   // always render the light appearance
    }
}

// MARK: - Liquid glass helpers

// Makes the host window transparent so the glass can see the desktop behind it.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Air flow (streaks + current lines that move with pumping)

struct AirFlow: View {
    var lidVelocity: Double   // signed deg/s

    @State private var phase: CGFloat = 0       // integrated flow position (px)
    @State private var intensity: CGFloat = 0   // 0…1, eases with pump strength
    @State private var time: CGFloat = 0        // free-running clock for shimmer
    @State private var tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private let streakCount = 24
    private let currentCount = 7

    private func wrap(_ v: CGFloat, _ w: CGFloat) -> CGFloat {
        let m = v.truncatingRemainder(dividingBy: w)
        return m < 0 ? m + w : m
    }

    private func hue(_ i: Int, _ count: Int) -> Color {
        Color(hue: Double(i) / Double(count), saturation: 0.85, brightness: 0.95)
    }

    // A soft, glowing vertical streak: transparent → color → transparent along its length.
    private func drawStreak(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, width: CGFloat,
                            len: CGFloat, color: Color, alpha: CGFloat) {
        let rect = CGRect(x: x - width / 2, y: y, width: width, height: len)
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(stops: [
                .init(color: color.opacity(0), location: 0.0),
                .init(color: color.opacity(Double(alpha)), location: 0.5),
                .init(color: color.opacity(0), location: 1.0),
            ]),
            startPoint: CGPoint(x: x, y: y),
            endPoint: CGPoint(x: x, y: y + len)
        )
        ctx.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: shading)
    }

    var body: some View {
        Canvas { ctx, size in
            let span = size.height + 320

            // Flow current — long, faint, slower colored lines (behind streaks)
            for i in 0..<currentCount {
                let fx = (Double(i) + 0.5) / Double(currentCount)
                let x = CGFloat(fx) * size.width
                let base = CGFloat((Double(i) * 0.6180339887).truncatingRemainder(dividingBy: 1)) * span
                let y = wrap(base + phase * 0.55, span) - 160
                let len: CGFloat = 220 + CGFloat(i % 3) * 80
                let shimmer = 0.6 + 0.4 * sin(time * 1.1 + CGFloat(i) * 0.8)
                drawStreak(ctx, x: x, y: y, width: 3, len: len,
                           color: hue(i, currentCount), alpha: 0.16 * intensity * shimmer)
            }

            // Air-flow streaks — short, quicker, shimmering colored streaks
            for i in 0..<streakCount {
                let fx = (Double(i) + 0.5) / Double(streakCount)
                let x = CGFloat(fx) * size.width
                let base = CGFloat((Double(i) * 0.3819660113).truncatingRemainder(dividingBy: 1)) * span
                let y = wrap(base + phase, span) - 160
                let len: CGFloat = 42 + CGFloat(i % 5) * 16
                let shimmer = 0.55 + 0.45 * sin(time * 1.8 + CGFloat(i) * 0.7)
                drawStreak(ctx, x: x, y: y, width: 2.4, len: len,
                           color: hue(i, streakCount), alpha: 0.32 * intensity * shimmer)
            }
        }
        .onReceive(tick) { _ in
            let v = CGFloat(lidVelocity)
            let target = min(abs(v) / 10.0, 1.0)          // ~10 deg/s → full
            intensity += (target - intensity) * 0.12       // smooth in/out
            phase += v * (1.0 / 60.0) * 22                 // integrate direction & speed
            time += 1.0 / 60.0
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shared sargam palette

enum Sargam {
    // Sa (red) → Ni (violet). Vivid, orange in place of yellow, richer green/blue.
    static let rgb: [(r: Double, g: Double, b: Double)] = [
        (0xF5 / 255, 0x1E / 255, 0x2B / 255),  // Sa  — red
        (0xFF / 255, 0x6B / 255, 0x00 / 255),  // Re  — orange
        (0xFF / 255, 0x9A / 255, 0x00 / 255),  // Ga  — amber-orange
        (0x1E / 255, 0xC7 / 255, 0x4A / 255),  // Ma  — green
        (0x00 / 255, 0xC2 / 255, 0xB0 / 255),  // Pa  — teal
        (0x1E / 255, 0x7B / 255, 0xFF / 255),  // Dha — blue
        (0x7C / 255, 0x4D / 255, 0xFF / 255),  // Ni  — violet
    ]

    static func color(_ i: Int) -> Color {
        let c = rgb[i]
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    // Average RGB of the currently-held notes (nil if none).
    static func blendedRGB(_ notes: Set<Int>) -> (r: Double, g: Double, b: Double)? {
        let valid = notes.filter { rgb.indices.contains($0) }
        guard !valid.isEmpty else { return nil }
        var r = 0.0, g = 0.0, b = 0.0
        for n in valid { r += rgb[n].r; g += rgb[n].g; b += rgb[n].b }
        let c = Double(valid.count)
        return (r / c, g / c, b / c)
    }
}

// MARK: - Tilt glow
//
// Tilt down → glow from the top; tilt up → from the bottom. Intensity tracks tilt
// velocity (and controls reach). Color comes from the held key and eases smoothly
// when the chord changes (so a new note "flows in" rather than snapping).
struct TiltGlow: View {
    var lidVelocity: Double         // signed deg/s
    var pressedNotes: Set<Int>

    @State private var downI: CGFloat = 0   // top glow (tilt down)
    @State private var upI: CGFloat = 0     // bottom glow (tilt up)
    @State private var cr = 0.55            // current (eased) glow color
    @State private var cg = 0.56
    @State private var cb = 0.62
    @State private var time: CGFloat = 0
    @State private var tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private func drawEdge(_ ctx: GraphicsContext, _ size: CGSize, intensity: CGFloat, top: Bool) {
        guard intensity > 0.01 else { return }
        let edgeY: CGFloat = top ? 0 : size.height
        let ph: CGFloat = top ? 0 : 1.7
        let widen: CGFloat = 1.9                                    // horizontal stretch → wider

        let reach = size.height * 0.6 * min(intensity, 1)          // velocity → deeper
        let radius = reach * (1 + 0.12 * sin(time * 1.3 + ph))     // living edge
        let cx = size.width * 0.5 + 26 * sin(time * 0.9 + ph)
        let a = min(intensity, 1) * 0.55 * (0.85 + 0.15 * sin(time * 2.0 + ph))
        let color = Color(red: cr, green: cg, blue: cb)
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [color.opacity(Double(a)), .clear]),
            center: CGPoint(x: cx, y: edgeY), startRadius: 0, endRadius: max(radius, 1)
        )
        // Stretch horizontally around the edge point to make the glow wider than tall.
        ctx.drawLayer { layer in
            layer.translateBy(x: cx, y: edgeY)
            layer.scaleBy(x: widen, y: 1)
            layer.translateBy(x: -cx, y: -edgeY)
            layer.fill(
                Path(CGRect(x: -size.width, y: -size.height, width: size.width * 3, height: size.height * 3)),
                with: shading
            )
        }
    }

    var body: some View {
        Canvas { ctx, size in
            drawEdge(ctx, size, intensity: downI, top: true)
            drawEdge(ctx, size, intensity: upI, top: false)
        }
        .onReceive(tick) { _ in
            let v = CGFloat(lidVelocity)
            let mag = abs(v)
            let thr: CGFloat = 2.5

            // Direction-gated targets → only one edge is active at a time.
            let downTarget: CGFloat = v < -thr ? min(mag / 14, 1) : 0
            let upTarget:   CGFloat = v >  thr ? min(mag / 14, 1) : 0
            downI += (downTarget - downI) * (downTarget > downI ? 0.20 : 0.04)  // rise fast, fall slow
            upI   += (upTarget   - upI)   * (upTarget   > upI   ? 0.20 : 0.04)

            // Color eases toward the held chord (flows in on a new note, keeps last if none)
            if let t = Sargam.blendedRGB(pressedNotes) {
                cr += (t.r - cr) * 0.10
                cg += (t.g - cg) * 0.10
                cb += (t.b - cb) * 0.10
            }

            time += 1.0 / 60.0
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Dotted background pattern

struct DotsField: View {
    var lidAngle: Double           // smoothed angle — drives directional drift
    var pressedNotes: Set<Int>

    @State private var ripples: [Ripple] = []
    @State private var prevNotes: Set<Int> = []

    private let spacing: CGFloat = 26
    private let baseRadius: CGFloat = 1.4
    // Soothing, unhurried motion — waves travel slowly and linger.
    private let rippleSpeed: CGFloat = 340    // pts / second
    private let rippleLife: Double = 3.6       // seconds
    private let bandWidth: CGFloat = 54        // ring thickness (soft)
    private let pushAmount: CGFloat = 10       // gentle displacement
    private let restAngle: Double = 90         // neutral tilt
    private let driftScale: CGFloat = 0.7      // px of drift per degree from rest
    private let driftMax: CGFloat = 34

    // While a key is held, re-emit a gentle wave on this cadence.
    // @State so the timer persists across re-renders instead of being recreated.
    @State private var heldEmit = Timer.publish(every: 1.4, on: .main, in: .common).autoconnect()

    struct Ripple {
        let start: Date
        let origin: UnitPoint   // normalized position within the view
        let note: Int           // which key → which color
    }

    private func spawn(note: Int) {
        let fx = 0.30 + 0.40 * (CGFloat(note) / 6.0)   // keys span the instrument
        ripples.append(Ripple(start: Date(), origin: UnitPoint(x: fx, y: 0.62), note: note))
        if ripples.count > 40 { ripples.removeFirst(ripples.count - 40) }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let active = ripples.filter { now.timeIntervalSince($0.start) < rippleLife }
                // Field drifts with lid position: opening (angle above rest) pushes dots
                // down; closing pushes them up. Position-based → smooth, holds while tilted.
                let driftY = max(-driftMax, min(driftMax, CGFloat(lidAngle - restAngle) * driftScale))

                var y = spacing / 2
                while y < size.height {
                    var x = spacing / 2
                    while x < size.width {
                        // Neutral resting field
                        var opacity = 0.06
                        var scale = 1.0
                        var dx: CGFloat = 0, dy: CGFloat = 0        // displacement
                        var cr = 0.0, cg = 0.0, cb = 0.0, cw = 0.0  // weighted color accumulation

                        for r in active {
                            let age = now.timeIntervalSince(r.start)
                            let radius = CGFloat(age) * rippleSpeed
                            let origin = CGPoint(x: r.origin.x * size.width, y: r.origin.y * size.height)
                            let vx = x - origin.x, vy = y - origin.y
                            let dist = hypot(vx, vy)
                            let band = abs(dist - radius)
                            if band < bandWidth {
                                let ring = 1 - band / bandWidth
                                let fade = 1 - CGFloat(age / rippleLife)
                                let boost = ring * fade
                                opacity += 0.6 * boost
                                scale += 2.0 * boost
                                // Push the dot outward from the ripple origin
                                if dist > 0.001 {
                                    dx += (vx / dist) * pushAmount * boost
                                    dy += (vy / dist) * pushAmount * boost
                                }
                                // Accumulate this note's color, weighted by boost
                                let col = Sargam.rgb[r.note]
                                cr += col.r * Double(boost)
                                cg += col.g * Double(boost)
                                cb += col.b * Double(boost)
                                cw += Double(boost)
                            }
                        }

                        // Lit dots use the full vivid note color; resting dots stay dark.
                        // Intensity is carried by opacity, NOT by darkening the color.
                        let color: Color = cw > 0
                            ? Color(red: cr / cw, green: cg / cw, blue: cb / cw)
                            : .black

                        let px = x + dx, py = y + dy + driftY
                        let rad = baseRadius * scale

                        // Bloom — soft glow halo under lit dots
                        if cw > 0.04 {
                            let hr = rad * 3.2
                            context.fill(
                                Path(ellipseIn: CGRect(x: px - hr, y: py - hr, width: hr * 2, height: hr * 2)),
                                with: .color(color.opacity(Double(min(opacity, 0.7)) * 0.35))
                            )
                        }

                        // Core dot
                        context.fill(
                            Path(ellipseIn: CGRect(x: px - rad, y: py - rad, width: rad * 2, height: rad * 2)),
                            with: .color(color.opacity(Double(min(opacity, 0.85))))
                        )
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
        .onChange(of: pressedNotes) { _, notes in
            // Instant wave from each newly-pressed key
            for note in notes.subtracting(prevNotes) { spawn(note: note) }
            prevNotes = notes
        }
        .onReceive(heldEmit) { _ in
            // Sustained: held keys keep sending gentle waves
            for note in pressedNotes { spawn(note: note) }
        }
    }
}

// MARK: - The harmonium (top cap + stretching bellows + base with keys)

struct HarmoniumView: View {
    let openness: Double            // 0 closed … 1 open (from lid tilt or mouse drag)
    let pressedNotes: Set<Int>
    let isIdle: Bool
    // Drag on the top cap / bellows → (vertical translation, vertical velocity), and end.
    var onDragChange: (CGFloat, CGFloat) -> Void = { _, _ in }
    var onDragEnd: () -> Void = {}

    // Enables the spring only after first layout, so there's no "grow-in" on launch.
    @State private var animate = false
    @State private var grabbing = false   // for the grab cursor while dragging the bellows

    // Bellows height as a fraction of image width.
    private static let bellowsMin: CGFloat = 0.03
    private static let bellowsMax: CGFloat = 0.16

    // Holding a key instantly wakes the bellows (don't wait for the idle tick).
    private var resting: Bool { isIdle && pressedNotes.isEmpty }

    private var bellowsFactor: CGFloat {
        if resting { return Self.bellowsMin }   // idle → settle to nearly closed
        let e = CGFloat(min(max(openness, 0), 1))
        return Self.bellowsMin + (Self.bellowsMax - Self.bellowsMin) * e
    }

    var body: some View {
        GeometryReader { geo in
            // Reserve a constant-height block sized for the fully-expanded assembly.
            let totalAspectMax = HarmoniumAssets.top2Aspect
                + HarmoniumAssets.baseAspect
                + Self.bellowsMax
            let width = min(geo.size.width, geo.size.height / totalAspectMax)
            let bellowsHeight = width * bellowsFactor
            let maxBellowsHeight = width * Self.bellowsMax
            // Slack above the top cap absorbs the bellows' shrink, so the base never moves.
            let topSlack = maxBellowsHeight - bellowsHeight
            let blockHeight = width * totalAspectMax

            VStack(spacing: 0) {
                // Keeps the base anchored at the block's bottom while bellows change.
                Color.clear.frame(height: topSlack)

                // Draggable group: the top cap + the stretching bellows. Dragging this
                // pumps the bellows (and feeds the same "tilt" into every effect).
                VStack(spacing: 0) {
                    // Top cap — moves with the bellows, never stretches
                    HarmoniumAssets.top2
                        .resizable()
                        .frame(width: width, height: width * HarmoniumAssets.top2Aspect)

                    // Stretching bellows — 5 stacked stripes sharing the height
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            HarmoniumAssets.bellow
                                .resizable(resizingMode: .stretch)
                                .frame(width: width, height: bellowsHeight / 5)
                        }
                    }
                    .frame(height: bellowsHeight)
                }
                .contentShape(Rectangle())
                .grabPointer(grabbing)
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { v in
                            grabbing = true
                            onDragChange(v.translation.height, v.velocity.height)
                        }
                        .onEnded { _ in
                            grabbing = false
                            onDragEnd()
                        }
                )

                // Base body with pressed-key overlays
                ZStack {
                    HarmoniumAssets.base
                        .resizable()
                        .frame(width: width, height: width * HarmoniumAssets.baseAspect)

                    ForEach(0..<7, id: \.self) { i in
                        HarmoniumAssets.keys[i]
                            .resizable()
                            .frame(width: width, height: width * HarmoniumAssets.baseAspect)
                            .opacity(pressedNotes.contains(i) ? 1 : 0)
                            .animation(.easeOut(duration: 0.06), value: pressedNotes.contains(i))
                    }
                }
            }
            // Constant-height block, centered → base stays put, only bellows move.
            .frame(width: width, height: blockHeight)
            // Flatten to one layer, then stack shadows lit from above — starting
            // hard/crisp and softening as they fall further down.
            .compositingGroup()
            .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 8)
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 22)
            .shadow(color: .black.opacity(0.13), radius: 14, x: 0, y: 38)
            .shadow(color: .black.opacity(0.09), radius: 24, x: 0, y: 58)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            // Slow, gentle settle when going idle; snappy spring when tracking the lid.
            .animation(
                animate ? (resting ? .easeInOut(duration: 0.9) : .spring(response: 0.3, dampingFraction: 0.7)) : nil,
                value: bellowsHeight
            )
        }
        .onAppear {
            // Turn animation on one runloop later so the initial layout doesn't animate.
            DispatchQueue.main.async { animate = true }
        }
    }
}
