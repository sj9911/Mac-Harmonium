<div align="center">

# Mac Harmonium 🪗

**The bellows were in your laptop all along.**

Move the lid to pump air, press the keys to play. A harmonium hiding inside your MacBook.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-000000?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-2E7DFF?style=flat-square)
[![VirusTotal](https://img.shields.io/badge/VirusTotal-0%2F61%20clean-3BD671?style=flat-square)](https://www.virustotal.com/gui/file/b964469550bd628a92962f8e150afdf900f1294743e6ac574291ce03606363a0)
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

1. **[Download Mac Harmonium](https://github.com/sj9911/Mac-Harmonium/releases/latest/download/Mac-Harmonium.dmg)** (`Mac-Harmonium.dmg`).
2. Open the file and drag **Mac Harmonium** into your **Applications** folder.
3. **First launch:** right-click the app, choose **Open**, then **Open** again. macOS asks this once for apps from independent makers; after that it opens normally.

### Is it safe?

Yes, and you don't have to take my word for it:

- **VirusTotal scan came back clean.** [Full report](https://www.virustotal.com/gui/file/b964469550bd628a92962f8e150afdf900f1294743e6ac574291ce03606363a0): 0 of 61 scanners flagged it.
- **It's fully open source.** Every line is right here to read.

### Why the right-click?

Apple's notarization needs their Developer Program, which runs $99 a year. This is a free project I built for fun, so I haven't signed up yet. If it grows into something people genuinely use and it feels worth it, I'd happily get it notarized. Until then, thanks for bearing with the one-time right-click. 🙏

<details>
<summary><b>For developers (Homebrew, build from source, checksum)</b></summary>

<br/>

**Homebrew** (installs with no Gatekeeper prompt):

```bash
brew install --cask sj9911/tap/mac-harmonium
```

**Build from source:**

```bash
swift build
swift run
```

Or open `Package.swift` in Xcode and press ⌘R.

**Verify the download** matches the published checksum:

```bash
shasum -a 256 Mac-Harmonium.dmg
# b964469550bd628a92962f8e150afdf900f1294743e6ac574291ce03606363a0
```

</details>

## Why I built it

I saw [Rocktopus101's Hingemonium](https://github.com/Rocktopus101/Hingemonium) reel years ago, and it just stuck. Every so often it would float back into my head: *someday I want to build that.*

I am a design engineer, so making things look and feel right is my home turf. Real-time audio and reading a hardware sensor, though, were all new to me. And I really believe the best way to learn is by doing, actually building the thing you are excited about, one "wait, how do I..." at a time. This whole app was exactly that, a playground for learning by doing.

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

- macOS 14 (Sonoma) or later. The Liquid Glass look shows on macOS 26; older versions get a frosted fallback.
- A MacBook with a **lid angle sensor** (MacBook Pro 16-inch 2019, Apple Silicon MacBook Pro, and MacBook Air M2 and later)
- No sensor? You can still play by dragging the bellows with your mouse.

## With thanks to

- **[Sam Gold](https://github.com/samhenrigold/LidAngleSensor)** for the Lid Angle Sensor that makes the whole lid as bellows trick possible.
- **[Rocktopus101](https://github.com/Rocktopus101/Hingemonium)** for the original idea (Hingemonium) that sparked this.

## License

MIT. See [LICENSE](LICENSE).

<div align="center">

Made with ♥ &amp; Claude.

</div>
