import AVFoundation
import Observation

// MARK: - Wavetable (reed timbre)
//
// One cycle of the harmonium's additive spectrum, baked into a lookup table.
// A strong fundamental with a slowly-decaying overtone stack — the "reed buzz"
// that a plain sawtooth/sine can't produce.
private enum Wavetable {
    static let size = 2048
    static let samples: [Float] = {
        // imag[n] = amplitude of the n-th harmonic (index 1 = fundamental)
        let harmonics: [Double] = [0, 1, 0.6, 0.5, 0.35, 0.25, 0.18,
                                   0.13, 0.1, 0.07, 0.05, 0.04, 0.03]
        var table = [Float](repeating: 0, count: size)
        for n in 0..<size {
            let theta = 2.0 * Double.pi * Double(n) / Double(size)
            var value = 0.0
            for h in 1..<harmonics.count {
                value += harmonics[h] * sin(Double(h) * theta)
            }
            table[n] = Float(value)
        }
        // Normalize to unit peak so absolute level is predictable.
        let peak = table.map(abs).max() ?? 1
        if peak > 0 { for i in 0..<size { table[i] /= peak } }
        return table
    }()

    // Linear-interpolated read. `phase` is 0..<1.
    @inline(__always)
    static func lookup(_ phase: Double) -> Float {
        let pos = phase * Double(size)
        let i = Int(pos)
        let frac = Float(pos - Double(i))
        let a = samples[i % size]
        let b = samples[(i + 1) % size]
        return a + (b - a) * frac
    }
}

// MARK: - Voice (one note = two detuned reeds + an envelope)

private final class Voice: @unchecked Sendable {
    // Written on the main thread, read on the audio thread (benign single-word race).
    nonisolated(unsafe) var isActive = false

    let frequency: Double
    // Audio-thread-only state:
    private var phaseLow = 0.0
    private var phaseHigh = 0.0
    private var env: Float = 0.0
    private var stage: Stage = .idle

    private enum Stage { case idle, attack, decay, sustain, release }

    // Envelope shape (peak 0.26 per voice)
    private static let sampleRate = 44100.0
    private static let peak: Float = 0.26
    private static let sustainLevel: Float = 0.26 * 0.82
    private static let attackRate  = peak / Float(sampleRate * 0.05)          // 50 ms
    private static let decayRate   = (peak - sustainLevel) / Float(sampleRate * 0.23) // 230 ms
    private static let releaseRate = peak / Float(sampleRate * 0.6)           // 600 ms — gentle harmonium fade

    init(frequency: Double) {
        self.frequency = frequency
    }

    // Advance one sample. `multLow`/`multHigh` are the shared detune+vibrato
    // frequency multipliers for this sample. Returns this voice's contribution.
    @inline(__always)
    func nextSample(multLow: Double, multHigh: Double) -> Float {
        // --- Envelope state machine ---
        if isActive {
            if stage == .idle || stage == .release { stage = .attack }
        } else if stage != .idle {
            stage = .release
        }

        switch stage {
        case .idle:
            return 0
        case .attack:
            env += Self.attackRate
            if env >= Self.peak { env = Self.peak; stage = .decay }
        case .decay:
            env -= Self.decayRate
            if env <= Self.sustainLevel { env = Self.sustainLevel; stage = .sustain }
        case .sustain:
            env = Self.sustainLevel
        case .release:
            env -= Self.releaseRate
            if env <= 0 { env = 0; stage = .idle; return 0 }
        }

        // --- Two detuned oscillators (the two reeds) ---
        let incLow = frequency * multLow / Self.sampleRate
        let incHigh = frequency * multHigh / Self.sampleRate
        let sample = (Wavetable.lookup(phaseLow) + Wavetable.lookup(phaseHigh)) * 0.5 * env
        phaseLow += incLow;  if phaseLow >= 1 { phaseLow -= 1 }
        phaseHigh += incHigh; if phaseHigh >= 1 { phaseHigh -= 1 }
        return sample
    }
}

// MARK: - Shared DSP state (audio-thread only, captured by the render block)

private final class DSPState {
    let sampleRate: Double

    // Tremulant LFO
    var lfoPhase = 0.0
    let lfoFreq = 5.2          // Hz
    let lfoDepthCents = 7.0    // ± cents
    let staticDetuneCents = 6.0 // ± cents (the two reeds)

    // Lowpass biquad (Direct Form I) — 4500 Hz, Q 0.6
    let b0, b1, b2, a1, a2: Float
    var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

    // Compressor: threshold -18 dB, ratio 3:1, 3 ms attack, 250 ms release
    let compThresholdDb: Float = -18
    let compRatio: Float = 3
    let compAttack: Float
    let compRelease: Float
    var compEnv: Float = 0

    // Master gain smoothing (20 ms) — the bellows/air-pressure volume
    var masterCurrent: Float = 0
    nonisolated(unsafe) var masterTarget: Float = 0
    let masterCoeff: Float

    init(sampleRate: Double) {
        self.sampleRate = sampleRate

        // --- RBJ lowpass coefficients ---
        let f0 = 4500.0, q = 0.6
        let w0 = 2 * Double.pi * f0 / sampleRate
        let cosw0 = cos(w0), sinw0 = sin(w0)
        let alpha = sinw0 / (2 * q)
        let a0 = 1 + alpha
        b0 = Float((1 - cosw0) / 2 / a0)
        b1 = Float((1 - cosw0) / a0)
        b2 = Float((1 - cosw0) / 2 / a0)
        a1 = Float((-2 * cosw0) / a0)
        a2 = Float((1 - alpha) / a0)

        compAttack  = Float(1 - exp(-1.0 / (sampleRate * 0.003)))
        compRelease = Float(1 - exp(-1.0 / (sampleRate * 0.25)))
        masterCoeff = Float(1 - exp(-1.0 / (sampleRate * 0.02)))
    }

    // Process one mono sample through master gain → lowpass → compressor.
    @inline(__always)
    func process(_ input: Float) -> Float {
        // Master gain (smoothed)
        masterCurrent += masterCoeff * (masterTarget - masterCurrent)
        var s = input * masterCurrent

        // Lowpass biquad
        let y = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = s
        y2 = y1; y1 = y
        s = y

        // Compressor (feed-forward, envelope-following)
        let level = abs(s)
        if level > compEnv { compEnv += compAttack * (level - compEnv) }
        else                { compEnv += compRelease * (level - compEnv) }
        let envDb = 20 * log10(max(compEnv, 1e-6))
        if envDb > compThresholdDb {
            let reductionDb = (envDb - compThresholdDb) * (1 - 1 / compRatio)
            s *= pow(10, -reductionDb / 20)
        }

        // Final safety clamp
        return max(-1, min(1, s))
    }
}

// MARK: - Audio engine

@Observable
final class AudioEngine {
    static let noteNames = ["Sa", "Re", "Ga", "Ma", "Pa", "Dha", "Ni"]
    static let keyLabels  = ["A",  "S",  "D",  "F",  "G",  "H",  "J"]
    static let frequencies: [Double] = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88]

    private let engine = AVAudioEngine()
    private var voices: [Voice] = []
    private let dsp = DSPState(sampleRate: 44100.0)

    // Bellows air pressure → master volume (0..1)
    var airPressure: Float = 0 {
        didSet { dsp.masterTarget = max(0, min(1, airPressure)) }
    }

    // Which notes (0..6) are held
    var activeNotes: Set<Int> = [] {
        didSet {
            for (i, voice) in voices.enumerated() {
                voice.isActive = activeNotes.contains(i)
            }
        }
    }

    init() {
        setupEngine()
    }

    private func setupEngine() {
        let sampleRate = 44100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        for freq in Self.frequencies {
            voices.append(Voice(frequency: freq))
        }

        let voices = self.voices
        let dsp = self.dsp
        let lfoInc = 2 * Double.pi * dsp.lfoFreq / sampleRate

        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                // Shared tremulant: one LFO fans into every voice's detune.
                let lfoCents = dsp.lfoDepthCents * sin(dsp.lfoPhase)
                dsp.lfoPhase += lfoInc
                if dsp.lfoPhase >= 2 * Double.pi { dsp.lfoPhase -= 2 * Double.pi }

                let multLow  = pow(2.0, (-dsp.staticDetuneCents + lfoCents) / 1200.0)
                let multHigh = pow(2.0, ( dsp.staticDetuneCents + lfoCents) / 1200.0)

                // Sum all voices
                var mix: Float = 0
                for voice in voices {
                    mix += voice.nextSample(multLow: multLow, multHigh: multHigh)
                }

                // Master gain → lowpass → compressor
                let out = dsp.process(mix)

                for buffer in abl {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = out
                }
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0

        do {
            try engine.start()
        } catch {
            print("[Harmonium] Audio engine failed to start: \(error)")
        }
    }
}
