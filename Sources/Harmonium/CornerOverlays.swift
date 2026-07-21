import SwiftUI
import AppKit

// MARK: - Editable credit details
//
// 👉 Fill these in with your real name and links.
enum Credits {
    static let version = "v1.2.1"
    static let name = "Sunny Joshi"

    static let github   = URL(string: "https://github.com/sj9911")!
    static let linkedin = URL(string: "https://www.linkedin.com/in/thesunnyjoshi/")!
    static let website  = URL(string: "https://sunnyjoshi.com/?utm_source=mac-harmonium-credits")!

    // With thanks to
    static let lidAngleSensor = URL(string: "https://github.com/samhenrigold/LidAngleSensor")!
    static let hingemonium    = URL(string: "https://github.com/Rocktopus101/Hingemonium")!
}

// Loads a bundled Tabler SVG as a tintable template image.
private func tablerIcon(_ name: String) -> Image {
    if let url = AppResources.url(name, ext: "svg", subdirectory: "Resources/Icons"),
       let nsImage = NSImage(contentsOf: url) {
        nsImage.isTemplate = true
        return Image(nsImage: nsImage)
    }
    return Image(systemName: "questionmark")
}

// Loads a bundled PNG (e.g. the avatar).
private func creditImage(_ name: String) -> Image {
    if let url = AppResources.url(name, ext: "png", subdirectory: "Resources"),
       let nsImage = NSImage(contentsOf: url) {
        return Image(nsImage: nsImage)
    }
    return Image(systemName: "person.crop.circle")
}

// MARK: - Hint banner (nudge to tilt when tapping without air)

struct HintBanner: View {
    var body: some View {
        HStack(spacing: 9) {
            tablerIcon("arrows-move-vertical")
                .renderingMode(.template)
                .resizable()
                .frame(width: 15, height: 15)
                .foregroundStyle(.black.opacity(0.55))
            Text("Tilt your screen to pump air and hear the notes")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.black.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlass(in: Capsule())
    }
}

// MARK: - Bottom-left version badge

struct VersionBadge: View {
    var body: some View {
        Text(Credits.version)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(.black.opacity(0.4))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .liquidGlass(in: Capsule())
    }
}

// MARK: - Beating red heart (Nothing-style accent)

struct BeatingHeart: View {
    var size: CGFloat = 15

    var body: some View {
        tablerIcon("heart")
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
            .foregroundStyle(Color(red: 0xE1 / 255, green: 0x1D / 255, blue: 0x2A / 255))
            .keyframeAnimator(initialValue: 1.0, repeating: true) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                // lub–dub … rest
                KeyframeTrack {
                    SpringKeyframe(1.22, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.18, spring: .snappy)
                    SpringKeyframe(1.16, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.20, spring: .snappy)
                    LinearKeyframe(1.0, duration: 0.85)
                }
            }
    }
}

// MARK: - Bottom-right credit badge (info button → hover card)

struct CreditBadge: View {
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            if hovering {
                card.transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 10)).combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)),
                    removal: .opacity.combined(with: .offset(y: 6))
                ))
            }
            infoButton
        }
        .onHover { h in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { hovering = h }
        }
    }

    private var infoButton: some View {
        tablerIcon("info-circle")
            .renderingMode(.template)
            .resizable()
            .frame(width: 17, height: 17)
            .foregroundStyle(.black.opacity(hovering ? 0.75 : 0.5))
            .frame(width: 34, height: 34)
            .liquidGlass(in: Circle(), interactive: true)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Identity row — photo + name anchor the card
            HStack(spacing: 13) {
                creditImage("avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(Credits.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.85))

                    HStack(spacing: 5) {
                        Text("MADE WITH")
                        BeatingHeart(size: 11)
                        Text("& CLAUDE")
                    }
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.black.opacity(0.42))
                }
            }

            Text("Thanks for playing! A fun little app I built to learn vibecoding, and it's open source.")
                .font(.system(size: 12.5))
                .foregroundStyle(.black.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            HStack(spacing: 10) {
                LinkIcon(icon: "brand-github", label: "GitHub", url: Credits.github)
                LinkIcon(icon: "brand-linkedin", label: "LinkedIn", url: Credits.linkedin)
                LinkIcon(icon: "world", label: "Website", url: Credits.website)
            }

            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(height: 1)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("WITH THANKS TO")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.black.opacity(0.35))
                CreditLink(text: "Sam Gold · Lid Angle Sensor", url: Credits.lidAngleSensor)
                CreditLink(text: "Rocktopus101 · Original idea", url: Credits.hingemonium)
            }
        }
        .padding(22)
        .frame(width: 288, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Small text credit link

private struct CreditLink: View {
    let text: String
    let url: URL
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.black.opacity(hovering ? 0.8 : 0.5))
                .underline(hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Glassy Tabler link button with polished hover

private struct LinkIcon: View {
    let icon: String
    let label: String
    let url: URL

    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            tablerIcon(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(.black.opacity(hovering ? 0.95 : 0.6))
                .frame(width: 40, height: 40)
                .liquidGlass(in: Circle(), interactive: true)
                .scaleEffect(hovering ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { h in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { hovering = h }
        }
    }
}
