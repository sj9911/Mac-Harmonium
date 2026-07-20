import SwiftUI

// First-run welcome. Shows the instrument blurred behind a frosted veil, then fades to
// reveal the live, sharp one on "Start playing". Sells the real experience — keyboard +
// lid — and teaches A–J → sargam by playing the cascade.
struct WelcomeView: View {
    var onDismiss: () -> Void     // fired after the exit animation, to remove the overlay

    // The seven playable keys, in order, with their sargam names.
    private static let keys: [(letter: String, name: String)] = [
        ("A", "Sa"), ("S", "Re"), ("D", "Ga"), ("F", "Ma"),
        ("G", "Pa"), ("H", "Dha"), ("J", "Ni"),
    ]

    // Shared width so the key row and the lid pill line up edge to edge.
    private static let panelWidth: CGFloat = 410

    // Cascade timing (seconds) — calm, readable scale.
    private let cascadeDelay = 0.8
    private let step = 0.40
    private let holdAfter = 1.4

    @State private var start = Date()
    @State private var appear = false        // entrance spring (scale / opacity)
    @State private var leaveAt: Date? = nil  // set on dismiss → time-driven exit

    private var cyclePeriod: Double { Double(Self.keys.count) * step + holdAfter }

    // 0…1 exit amount (time-driven so it stays smooth via TimelineView).
    private func exitAmt(_ now: Date) -> Double {
        guard let leaveAt else { return 0 }
        return min(now.timeIntervalSince(leaveAt) / 0.5, 1)
    }

    // 0…1 brightness for chip `i` — a soft pulse sweeping left→right, then looping.
    private func chipIntensity(_ i: Int, _ t: Double) -> Double {
        let ct = t - cascadeDelay
        guard ct > 0 else { return 0 }
        let cyc = ct.truncatingRemainder(dividingBy: cyclePeriod)
        let local = cyc - Double(i) * step
        guard local >= 0 else { return 0 }
        if local < 0.14 { return local / 0.14 }            // attack
        return max(0, 1 - (local - 0.14) / 0.80)           // decay
    }

    private func dismiss() {
        guard leaveAt == nil else { return }
        leaveAt = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { onDismiss() }
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            let ex = exitAmt(tl.date)

            ZStack {
                    // Opaque near-white base — covers the transparent window so the blur
                    // has no edge artifacts.
                    Color(red: 0xf7/255, green: 0xf6/255, blue: 0xf4/255)
                        .opacity(1 - ex)
                        .ignoresSafeArea()

                    // The instrument at its true proportions and position, blurred — the
                    // frosted bg. Fades on exit → the live, sharp instrument takes its place.
                    HarmoniumView(openness: 0, pressedNotes: [], isIdle: true)
                        .padding(.horizontal, 64)
                        .padding(.top, 56)
                        .padding(.bottom, 72)
                        .blur(radius: 22)
                        .opacity(1 - ex)
                        .allowsHitTesting(false)

                    // Soft white veil over the blur — frosted-glass lift for the content.
                    Color.white
                        .opacity(0.3 * (1 - ex))
                        .ignoresSafeArea()

                    card(t: t)
                        .scaleEffect((appear ? 1 : 0.9) * (1 - 0.06 * ex))
                        .opacity((appear ? 1 : 0) * (1 - ex))
                        .offset(y: (appear ? 0 : 10) - 36 * ex)
                }
            }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { appear = true }
        }
    }

    private func card(t: Double) -> some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("🪗").font(.system(size: 40))
                VStack(spacing: 5) {
                    Text("Meet your harmonium")
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Each key plays a sargam note.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                }
            }

            // Sargam cascade — the hero. The app plays itself to teach the mapping.
            HStack(spacing: 0) {
                ForEach(Array(Self.keys.enumerated()), id: \.offset) { idx, k in
                    KeyChip(letter: k.letter,
                            name: k.name,
                            color: Sargam.color(idx),
                            intensity: chipIntensity(idx, t))
                    if idx < Self.keys.count - 1 { Spacer(minLength: 0) }
                }
            }
            .frame(width: Self.panelWidth)

            // Lid movement, spelled out in its own container.
            HStack(spacing: 9) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Move your laptop lid like bellows to pump the air")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.82))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(width: Self.panelWidth)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 1)
            )

            Text("No lid sensor? You can click the keys and drag the bellows.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: dismiss) {
                Text("Start playing")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(red: 0xF5/255, green: 0x1E/255, blue: 0x2B/255)))
            }
            .buttonStyle(.plain)
            .handPointer()
            .padding(.top, 6)
        }
        // No card chrome — the content sits directly on the full-window bloom.
        .padding(40)
    }
}

// One key in the cascade: letter over sargam name, lighting to its note color.
private struct KeyChip: View {
    let letter: String
    let name: String
    let color: Color
    let intensity: Double

    var body: some View {
        VStack(spacing: 3) {
            Text(letter)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(intensity > 0.5 ? .white : .primary)
            Text(name)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(intensity > 0.5 ? Color.white.opacity(0.9) : .secondary)
        }
        .frame(width: 40, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.4))
        )
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color.opacity(intensity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.22 + 0.5 * intensity), lineWidth: 1)
        )
        .scaleEffect(1 + 0.12 * intensity)
        .shadow(color: color.opacity(0.6 * intensity), radius: 11 * intensity, y: 2)
    }
}
