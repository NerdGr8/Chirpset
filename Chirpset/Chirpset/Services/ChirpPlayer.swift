import Foundation
import AVFoundation

/// Synthesizes Chirpset's signature bird "chirp" — no audio asset required.
/// Connect = a bright rising two-note chirp; disconnect = a single falling note.
/// Each note is a frequency-swept sine with a soft attack/decay envelope so it
/// reads as a chirp rather than a beep, and there are no clicks.
final class ChirpPlayer {

    enum Sound {
        case connect
        case disconnect
        case bootloader
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private let format: AVAudioFormat
    private var started = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ sound: Sound) {
        guard let buffer = makeBuffer(for: sound) else { return }
        ensureRunning()
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func ensureRunning() {
        guard !started else { return }
        do {
            try engine.start()
            started = true
        } catch {
            NSLog("Chirpset: audio engine start failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Synthesis

    /// A single swept-sine note.
    private struct Note {
        var start: Double       // seconds from buffer start
        var duration: Double    // seconds
        var freqStart: Double   // Hz
        var freqEnd: Double     // Hz
        var gain: Double        // 0…1 peak
    }

    private func notes(for sound: Sound) -> [Note] {
        switch sound {
        case .connect:
            return [
                Note(start: 0.00, duration: 0.085, freqStart: 1100, freqEnd: 1950, gain: 0.32),
                Note(start: 0.10, duration: 0.095, freqStart: 1500, freqEnd: 2300, gain: 0.32),
            ]
        case .bootloader:
            return [
                Note(start: 0.00, duration: 0.07, freqStart: 1000, freqEnd: 1500, gain: 0.30),
                Note(start: 0.09, duration: 0.07, freqStart: 1400, freqEnd: 1900, gain: 0.30),
                Note(start: 0.18, duration: 0.09, freqStart: 1800, freqEnd: 2400, gain: 0.30),
            ]
        case .disconnect:
            return [
                Note(start: 0.00, duration: 0.16, freqStart: 1700, freqEnd: 700, gain: 0.30),
            ]
        }
    }

    private func makeBuffer(for sound: Sound) -> AVAudioPCMBuffer? {
        let ns = notes(for: sound)
        let total = (ns.map { $0.start + $0.duration }.max() ?? 0.2) + 0.02
        let frameCount = AVAudioFrameCount(total * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        // Clear.
        for i in 0..<Int(frameCount) { channel[i] = 0 }

        for note in ns {
            let startFrame = Int(note.start * sampleRate)
            let noteFrames = Int(note.duration * sampleRate)
            var phase = 0.0
            for n in 0..<noteFrames {
                let idx = startFrame + n
                guard idx < Int(frameCount) else { break }
                let t = Double(n) / Double(noteFrames)            // 0…1 through the note
                let freq = note.freqStart + (note.freqEnd - note.freqStart) * t
                phase += 2.0 * Double.pi * freq / sampleRate
                channel[idx] += Float(sin(phase) * note.gain * envelope(t))
            }
        }
        return buffer
    }

    /// Soft attack, gentle exponential-ish decay — gives the note a chirp shape.
    private func envelope(_ t: Double) -> Double {
        let attack = 0.12
        if t < attack { return t / attack }
        let d = (t - attack) / (1 - attack)
        return pow(1 - d, 1.6)
    }
}
