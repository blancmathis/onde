import Foundation
import AVFoundation
import OndeCore
import OndeDSP

/// One Core Audio graph, two render scenes during a transition. Preparation and
/// disposal are outside the audio callback. Rapid clicks retain the last request.
final class GenerativeEngine {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let builder = DispatchQueue(label: "app.onde.scene-preparation", qos: .userInitiated)
    private var source: AVAudioSourceNode?
    private var mixer: OpaquePointer?
    private var targetCore: OpaquePointer?
    private var requestedIdentity: String?
    private var requestTicket = 0
    private var fadeTicket = 0
    private var config = GenerativeSettings()
    private var selectedMode: SessionMode = .focus
    private var wantedPlaying = false
    private var wantedGain: Float = 0
    private var configurationObserver: NSObjectProtocol?
    private var collector: Timer?
    private var fromTitle = ""
    private(set) var loading = false
    private(set) var lastError: String?
    var transitionSeconds: Double = 10
    private var entranceSeconds: Double = 8

    init() {
        collector = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            if let mixer = self?.mixer { onde_scene_mixer_collect(mixer) }
        }
        configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, self.wantedPlaying else { return }
            do { try self.engine.start(); self.lastError = nil }
            catch { self.lastError = error.localizedDescription }
        }
    }
    deinit {
        collector?.invalidate()
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        engine.stop()
        if let source { engine.detach(source) }
        if let mixer { onde_scene_mixer_destroy(mixer) }
    }
    private func prepareGraph() throws {
        guard mixer == nil else { return }
        guard let mix = onde_scene_mixer_create(sampleRate) else { throw OndeError("generator_init_failed", "Could not initialize the audio mixer.") }
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let node = AVAudioSourceNode(format: format) { _, _, count, list -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count == 2, let l = buffers[0].mData, let r = buffers[1].mData else {
                for buffer in buffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
                return noErr
            }
            onde_scene_mixer_render(mix, l.assumingMemoryBound(to: Float.self), r.assumingMemoryBound(to: Float.self), count)
            return noErr
        }
        mixer = mix; source = node
        engine.attach(node); engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1; engine.prepare()
    }
    private func applyControls(_ ptr: OpaquePointer, mode: SessionMode, configuration: GenerativeSettings) {
        onde_dsp_set_mode(ptr, mode.dspMode); onde_dsp_set_seed(ptr, configuration.seed)
        for (i, v) in configuration.values.enumerated() { onde_dsp_set(ptr, GenerativeSettings.dspIndex(i), Float(v)) }
        onde_dsp_set(ptr, Int32(ONDE_GAIN), 1)
    }
    private func prepareScene(mode: SessionMode, configuration: GenerativeSettings, identity: String) {
        requestTicket += 1; let ticket = requestTicket
        requestedIdentity = identity; loading = true; lastError = nil
        let rate = sampleRate
        builder.async { [weak self] in
            var needed = false
            DispatchQueue.main.sync { needed = self?.requestTicket == ticket }
            guard needed else { return }
            var candidate: OpaquePointer?
            do {
                let valid = try configuration.validated()
                guard let ptr = onde_dsp_create(rate, mode.dspMode, valid.seed) else { throw OndeError("generator_init_failed", "Could not prepare the soundscape.") }
                candidate = ptr
                try OrchestraBank.load(into: ptr, required: valid.orchestra > 0 || valid.piano > 0)
                if valid.piano > 0 && (onde_dsp_orchestra_families(ptr) & 2048) == 0 { throw OndeError("piano_missing", "The complete piano sample bank is required.") }
                for (i, v) in valid.values.enumerated() { onde_dsp_set(ptr, GenerativeSettings.dspIndex(i), Float(v)) }
                onde_dsp_set(ptr, Int32(ONDE_GAIN), 1)
                // Warm the harmonic space silently for one whole bar, before publication.
                var l = [Float](repeating: 0, count: 1024), r = l
                var remaining = Int((240 / valid.tempo * rate).rounded(.up))
                while remaining > 0 { let n = min(1024, remaining); onde_dsp_render(ptr, &l, &r, UInt32(n)); remaining -= n }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.requestTicket == ticket, let mixer = self.mixer else { onde_dsp_destroy(ptr); return }
                    self.applyControls(ptr, mode: self.selectedMode, configuration: self.config)
                    guard onde_scene_mixer_submit(mixer, ptr, self.transitionSeconds) == 1 else {
                        onde_dsp_destroy(ptr); self.loading = false; self.requestedIdentity = nil
                        self.lastError = "Could not prepare the transition."; return
                    }
                    self.targetCore = ptr; self.loading = false
                    onde_scene_mixer_gain(mixer, self.wantedPlaying ? self.wantedGain : 0)
                }
            } catch {
                if let candidate { onde_dsp_destroy(candidate) }
                let text = error.localizedDescription
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.requestTicket == ticket else { return }
                    self.loading = false; self.requestedIdentity = nil; self.lastError = text
                }
            }
        }
    }
    func apply(mode: SessionMode, config: GenerativeSettings, gain: Double, playing: Bool, startFadeSeconds: Double = 8, freshStart: Bool = false) throws {
        let identity = mode.rawValue + ":" + (config.profileID ?? "custom") + ":" + String(Int(config.composition))
        let previousName = self.config.displayName
        let wasPlaying = wantedPlaying, hadMixer = mixer != nil
        let sameScene = requestedIdentity == identity && targetCore != nil
        self.config = config; selectedMode = mode; wantedPlaying = playing
        wantedGain = Float(max(0, min(1, gain)))
        fadeTicket += 1; let ticket = fadeTicket
        if playing { try prepareGraph() }
        guard let mixer else { return }
        if playing && identity != requestedIdentity {
            fromTitle = hadMixer ? previousName : ""
            prepareScene(mode: mode, configuration: config, identity: identity)
        } else if !loading, identity == requestedIdentity, let targetCore {
            applyControls(targetCore, mode: mode, configuration: config)
        }
        if !hadMixer || wasPlaying != playing {
            entranceSeconds = playing ? ((freshStart || !sameScene) ? startFadeSeconds : min(2, startFadeSeconds)) : 0.20
            onde_scene_mixer_playback(mixer, playing ? 1 : 0, max(0.015, entranceSeconds))
        }
        onde_scene_mixer_gain(mixer, playing ? wantedGain : 0)
        if playing {
            if !engine.isRunning { try engine.start() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self, self.fadeTicket == ticket, !self.wantedPlaying else { return }; self.engine.pause()
            }
        }
    }
    func reset() {
        requestTicket += 1; loading = false; requestedIdentity = nil; targetCore = nil
        engine.stop(); if let source { engine.detach(source) }; source = nil
        if let mixer { onde_scene_mixer_destroy(mixer) }; mixer = nil
        wantedPlaying = false; fadeTicket += 1; fromTitle = ""; lastError = nil
    }
    var running: Bool { engine.isRunning && wantedPlaying && mixer.flatMap { onde_scene_mixer_visible($0) } != nil }
    var transitionSnapshot: [String: Any] {
        let phase = mixer.map(onde_scene_mixer_state) ?? 0
        return ["state": loading ? "preparing" : phase == 1 ? "waiting_for_bar" : phase == 2 ? "crossfading" : "idle",
                "progress": mixer.map(onde_scene_mixer_progress) ?? 1,
                "seconds": transitionSeconds, "from": fromTitle, "to": config.displayName,
                "queued": (mixer.map(onde_scene_mixer_pending) ?? 0) != 0,
                "policy": "smooth_equal_power_with_rhythmic_handover"]
    }
    func snapshot() -> [String: Any] {
        let core = mixer.flatMap { onde_scene_mixer_visible($0) }
        let frames = core.map(onde_dsp_frames) ?? 0
        let entranceGain: Float = mixer.map { onde_scene_mixer_entrance_gain($0) } ?? 0
        let entranceProgress: Float = mixer.map { onde_scene_mixer_entrance_progress($0) } ?? 0
        let entrance: [String: Any] = ["gain": entranceGain, "progress": entranceProgress,
                                      "seconds": entranceSeconds, "curve": "squared_smoothstep",
                                      "waiting_for_audio": wantedPlaying && core == nil,
                             "first_gain": Double(mixer.map(onde_scene_mixer_entrance_first_gain) ?? 0),
                             "audited_frames": mixer.map(onde_scene_mixer_entrance_frames) ?? 0,
                             "intermediate_frames": mixer.map(onde_scene_mixer_entrance_intermediate) ?? 0,
                             "serial": mixer.map(onde_scene_mixer_entrance_serial) ?? 0,
                             "request_pending": (mixer.map(onde_scene_mixer_entrance_pending) ?? 0) != 0]
        return ["engine": "onde-living-7", "offline": true, "sample_based": config.orchestra>0 && (core.map(onde_dsp_orchestra_samples) ?? 0)>0,
                "loading": loading,
                "entrance": entrance,
                "transition": transitionSnapshot,
                "phrase_index": core.map(onde_dsp_phrase) ?? 0,
                "chapter_index": core.map(onde_dsp_chapter) ?? 0,
                "phrase_fingerprint": String(core.map(onde_dsp_plan_hash) ?? 0),
                "theme_variant": core.map(onde_dsp_variant) ?? 0,
                "phrase_bars": 8, "chapter_bars": config.composition >= 8 ? 96 : 64,
                "composition_id": core.map(onde_dsp_composition) ?? 0,
                "score_events": core.map(onde_dsp_signature_events) ?? 0,
                "choir_voices": core.map(onde_dsp_choir_voices) ?? 0,
                "vocal_source": config.vocals > 0 ? "original_synthesized_vowels" : "none",
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
                "arrangement_section": ["Opening", "Current", "Weave", "Breathing space", "Resonance", "Suspension"][min(5, max(0, Int(core.map(onde_dsp_section) ?? 0)))],
                "output_peak": mixer.map(onde_scene_mixer_peak) ?? 0,
                "output_rms": mixer.map(onde_scene_mixer_rms) ?? 0,
                "actual_gain": mixer.map(onde_scene_mixer_actual_gain) ?? 0,
                "sample_rate": sampleRate, "configuration": jsonObject(config),
                "last_error": lastError as Any? ?? NSNull()]
    }
}
