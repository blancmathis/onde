import Foundation
import AVFoundation
import OndeCore
import OndeDSP

/// Main-thread owner; rendering occurs entirely in a preallocated C11 DSP core.
/// Acoustic CC0 notes are preloaded from the installed app; no audio capture, runtime downloads or ML.
final class GenerativeEngine {
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var core: OpaquePointer?
    private let sampleRate: Double = 44_100
    private var fadeTicket = 0
    private var config = GenerativeSettings()
    private var selectedMode: SessionMode = .focus
    private var configurationObserver: NSObjectProtocol?
    private var wantedPlaying = false
    private var wantedGain: Float = 0
    private(set) var lastError: String?

    init() {
        configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, self.wantedPlaying else { return }
            do { try self.engine.start(); self.lastError = nil }
            catch { self.lastError = error.localizedDescription }
        }
    }
    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        engine.stop()
        if let source { engine.detach(source) }
        if let core { onde_dsp_destroy(core) }
    }
    private func prepare(_ mode: SessionMode, _ config: GenerativeSettings) throws {
        guard core == nil else { return }
        guard let ptr = onde_dsp_create(sampleRate, mode.dspMode, config.seed) else {
            throw OndeError("generator_init_failed", "Le moteur sonore n’a pas pu être initialisé.")
        }
        do { try OrchestraBank.load(into:ptr,required:config.orchestra>0) }
        catch { onde_dsp_destroy(ptr);throw error }
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, list -> OSStatus in
            // Buffer lists are provided by Core Audio. No new buffers are allocated here.
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count == 2, let left = buffers[0].mData, let right = buffers[1].mData else {
                for buffer in buffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
                return noErr
            }
            onde_dsp_render(ptr, left.assumingMemoryBound(to: Float.self), right.assumingMemoryBound(to: Float.self), frameCount)
            return noErr
        }
        core = ptr; source = node
        engine.attach(node); engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()
    }
    func apply(mode: SessionMode, config: GenerativeSettings, gain: Double, playing: Bool) throws {
        self.config = config; self.selectedMode = mode
        wantedPlaying = playing; wantedGain = Float(max(0, min(1, gain)))
        fadeTicket += 1; let ticket = fadeTicket
        if playing { try prepare(mode, config) }
        guard let core else { return }
        if config.orchestra>0 && onde_dsp_orchestra_samples(core)==0 {throw OndeError("orchestra_missing","La banque orchestrale complète est requise pour ce profil.")}
        onde_dsp_set_mode(core, mode.dspMode); onde_dsp_set_seed(core, config.seed)
        for (index, value) in config.values.enumerated() { onde_dsp_set(core, GenerativeSettings.dspIndex(index), Float(value)) }
        onde_dsp_set(core, Int32(ONDE_GAIN), playing ? wantedGain : 0)
        if playing {
            if !engine.isRunning { try engine.start() }
            lastError = nil
        } else {
            // The render gain reaches silence before pausing Core Audio.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.fadeTicket == ticket, !self.wantedPlaying else { return }
                self.engine.pause()
            }
        }
    }
    func reset() {
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
        if let core { onde_dsp_destroy(core) }
        core = nil; wantedPlaying = false; fadeTicket += 1
    }
    var running: Bool { engine.isRunning && wantedPlaying }
    func snapshot() -> [String: Any] {
        let frames = core.map(onde_dsp_frames) ?? 0
        return ["engine": "onde-living-5", "offline": true, "sample_based": config.orchestra>0 && (core.map(onde_dsp_orchestra_samples) ?? 0)>0,
                "orchestra_samples": core.map(onde_dsp_orchestra_samples) ?? 0,
                "orchestra_voices": core.map(onde_dsp_orchestra_voices) ?? 0,
                "orchestra_events": core.map(onde_dsp_orchestra_events) ?? 0,
                "orchestra_bank_present": OrchestraBank.directory() != nil,
                "mode": selectedMode.rawValue, "running": running,
                "rendered_seconds": Double(frames) / sampleRate,
                "scheduled_events": core.map(onde_dsp_events) ?? 0,
                "note_events": core.map(onde_dsp_note_events) ?? 0,
                "grain_events": core.map(onde_dsp_grain_events) ?? 0,
                "beats": core.map(onde_dsp_beats) ?? 0,
                "sixteenth_ticks": core.map(onde_dsp_ticks) ?? 0,
                "min_beat_gap_samples": core.map(onde_dsp_min_beat_gap) ?? 0,
                "max_beat_gap_samples": core.map(onde_dsp_max_beat_gap) ?? 0,
                "rhythm_policy": "fixed_grid_no_random_omissions",
                "noise_layer_enabled": false,
                "granular_layer_enabled": false,
                "bars": core.map(onde_dsp_bars) ?? 0,
                "bpm": core.map(onde_dsp_bpm) ?? 0,
                "active_voices": core.map(onde_dsp_voices) ?? 0,
                "harmony_index": core.map(onde_dsp_harmony) ?? 0,
                "arrangement_section": ["Ouverture", "Courant", "Tissage", "Respiration", "Résonance", "Suspension"][min(5, max(0, Int(core.map(onde_dsp_section) ?? 0)))],
                "output_peak": core.map(onde_dsp_peak) ?? 0,
                "output_rms": core.map(onde_dsp_rms) ?? 0,
                "actual_gain": core.map(onde_dsp_gain) ?? 0,
                "sample_rate": sampleRate, "configuration": jsonObject(config),
                "last_error": lastError as Any? ?? NSNull()]
    }
}
