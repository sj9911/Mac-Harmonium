<div align="center">

# Mac Harmonium 🪗

**The bellows were in your laptop all along.**

Move the lid to pump air, press the keys to play. A harmonium hiding inside your MacBook.

![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-000000?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-2E7DFF?style=flat-square)
[![VirusTotal](https://img.shields.io/badge/VirusTotal-0%2F61%20clean-3BD671?style=flat-square)](https://www.virustotal.com/gui/file/372ac462fbf6278ccd52e279542f3bc6aa84115c26ddaa4a0c6dd0b50eec6af5)
![Stars](https://img.shields.io/github/stars/sj9911/Mac-Harmonium?style=flat-square&color=E11D2A)
![Vibecoded with Claude](https://img.shields.io/badge/vibecoded%20with-Claude-D97757?style=flat-square)

![Mac Harmonium](docs/hero.webp)

</div>

## How to play

1. Launch the app.
2. **Pump air** by gently moving your laptop lid (or click and drag the bellows on screen with your mouse).
3. While there is air, press the **A S D F G H J** keys to play the sargam notes:

<div align="center">

| Key | A | S | D | F | G | H | J |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Note** | Sa | Re | Ga | Ma | Pa | Dha | Ni |

</div>

It is polyphonic, so hold several keys for chords. Notes swell while you pump and fade when you stop. No air, no sound, just like the real thing.

## Install

**[Download the latest DMG](https://github.com/sj9911/Mac-Harmonium/releases/latest)**, open it, and drag **Mac Harmonium** into Applications.

It is not notarized by Apple (that needs a paid developer account), so the first time you open it, macOS asks you to confirm:

1. Right-click (or Control-click) **Mac Harmonium** in Applications.
2. Choose **Open**, then **Open** again in the dialog.

You only do this once. Prefer to skip it entirely? Build from source (below).

### Is it safe?

Yes, and you do not have to take my word for it:

- **It is fully open source.** Every line is in this repo. Read it, or build it yourself.
- **Scanned clean by [VirusTotal](https://www.virustotal.com/gui/file/372ac462fbf6278ccd52e279542f3bc6aa84115c26ddaa4a0c6dd0b50eec6af5):** 0 of 61 security vendors flagged it.
- **Verify your download** matches the published checksum:
  ```bash
  shasum -a 256 Mac-Harmonium-1.0.dmg
  # 372ac462fbf6278ccd52e279542f3bc6aa84115c26ddaa4a0c6dd0b50eec6af5
  ```

### Why the extra right-click?

Apple's notarization runs through their Developer Program, which costs $99 a year. This is a free little thing I made for fun, so I have not signed up for that yet. If it ever grows into something people genuinely use and it feels worth it, I would love to get it properly notarized down the line. Until then, thank you for bearing with the one-time right-click. It really does mean a lot. 🙏

## The story

I saw [Rocktopus101's Hingemonium](https://github.com/Rocktopus101/Hingemonium) reel years ago, and it just stuck. Every so often it would float back into my head: *someday I want to build that.*

Truth is, I am still learning. And I really believe the best way to learn is by doing, actually building the thing you are excited about, one "wait, how do I..." at a time. This whole app was exactly that, a playground for learning by doing.

What changed is that now, with Claude, the "someday" became a weekend. An idea that lived in my head for years finally had a way out. I am genuinely thankful, and honestly a little giddy, to be building in a time like this.

So here it is. Not because it is important, but because it was fun, and because I finally could.

## How the sound is made

The lid gives you **air**. The keyboard gives you **notes**. A small real time synth turns both into a reedy harmonium tone.

```mermaid
flowchart LR
    subgraph AIR["🌬️ Air · the bellows"]
        Lid["Laptop lid angle"] --> Vel["Velocity<br/>(rate of change)"]
        Vel --> Pressure["Air pressure<br/>= volume"]
    end

    subgraph NOTES["🎹 Notes · the keyboard"]
        Keys["Keys A to J"] --> Freq["Sargam frequencies<br/>Sa Re Ga Ma Pa Dha Ni"]
    end

    Freq --> Osc["2 detuned reed<br/>oscillators per note"]
    LFO["Tremulant LFO<br/>5.2 Hz"] --> Osc
    Osc --> Env["ADSR envelope"]
    Env --> Mix["Mix voices"]
    Pressure --> Master["Master gain"]
    Mix --> Master
    Master --> LPF["Lowpass 4.5 kHz"]
    LPF --> Comp["Compressor"]
    Comp --> Out["🔊 Output"]
```

- **Reed timbre** comes from an additive wavetable, not a plain sine or sawtooth.
- **Two oscillators per note**, detuned a few cents apart, give that chorused harmonium "beat".
- A shared **tremulant** and a per note **ADSR envelope** shape the swell and fade.
- A global **lowpass** and **compressor** keep stacked chords warm and clean.

## Requirements

- macOS 26 or later
- A MacBook with a **lid angle sensor** (MacBook Pro 16-inch 2019, Apple Silicon MacBook Pro, and MacBook Air M2 and later)
- No sensor? You can still play by dragging the bellows with your mouse.

## Build and run

```bash
swift build
swift run
```

Or open `Package.swift` in Xcode and press ⌘R.

## With thanks to

- **[Sam Gold](https://github.com/samhenrigold/LidAngleSensor)** for the Lid Angle Sensor that makes the whole lid as bellows trick possible.
- **[Rocktopus101](https://github.com/Rocktopus101/Hingemonium)** for the original idea (Hingemonium) that sparked this.

## License

MIT. See [LICENSE](LICENSE).

<div align="center">

Made with ♥ &amp; Claude.

</div>
