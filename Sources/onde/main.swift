import Foundation
import OndeCore
import Darwin
import CoreFoundation

let help = """
onde \(AppBuild.version) — native local controller for Onde.app
Every successful response: {"ok":true,"result":...}. Errors: nonzero exit + JSON.

PROFILES · ORIGINAL CONTINUOUS MUSIC
  onde generate profile atlas --launch   Acoustic orchestral focus
  onde generate set strings 0.8          Per-section control (also brass, woods, harp, ostinato, percussion)
  onde generate profiles
  onde generate profile abysses --launch
  onde generate profile ancrage
  onde generate set bass 0.85
  onde generate set tempo 72           Independent fixed tempo, 40...120 BPM
  onde generate set warmth 0.9         Rounder high frequencies, 0...1
  onde generate set stability 1        Long held harmonies; never random note skips
  onde generate render abysses /absolute/new.wav --minutes 10
  Profiles: ancrage, abysses, courant, velours, rive, immersion.
  Extra controls: bass, tempo, stability, warmth, character.

SESSION
  onde focus|relax|meditate [--reset] [--launch]
  onde play|pause|stop
  onde status
  onde volume <0...1>

SOUNDS
  onde sounds
  onde sound <id> on|off [--volume <0...1>]
  onde sound <id> volume <0...1>
  onde solo <id>
  onde silence                         Disable all beds; timer/chimes stay active
  onde import <absolute-path> [--title <name>]
  onde sound remove <imported-id>      Delete only Onde's local copy

MEDITATION
  onde timer markers 10,20,30          Minutes; absolute markers, not intervals
  onde timer markers ''               No markers, unlimited stopwatch
  onde timer markers 2,4,6 --seconds   Seconds (e.g. for integration tests)
  onde timer reset
  onde chime preview
  onde settings <key> <value>
  onde settings startFadeSeconds 8     Gentle entrance 0...20s; resume up to 2s
    keys: chimeVolume, fadeSeconds, startFadeSeconds, chimesEnabled, preventSleep, reducedMotion

MIXES & DATA
  onde mixes
  onde mix save <name>
  onde mix load <id-or-name>
  onde mix delete <id-or-name>
  onde history [clear]
  onde events
  onde watch [--interval 1]            NDJSON snapshots until Ctrl-C

ORIGINAL GENERATIVE MUSIC (OFFLINE, VERIFIED ACOUSTIC BANK)
  onde generate transition-render <from> <to> <new.wav> --seconds 60 --at 20 --fade 10
  onde generate transition <seconds>    Smooth handover duration, 2...30 seconds
  onde generate presets               Three original starting palettes
  onde generate play focus --launch
  onde generate play meditation --seed 123
  onde generate set brightness 0.2     Smoothly update current mode
  onde generate set settleMinutes 30   Meditation simplification; 0 disables
  onde generate seed 123               Evolve future choices without a cut
  onde generate status
  onde generate defaults
  onde generate render focus /path/new.wav --minutes 10 --seed 123
       [--settings '{"density":0.4,"space":0.8}']
  Render runs without opening the app. WAV + JSON provenance; never overwrites.
  Other controls: density, movement, texture, pulse, evolution (all 0...1).

UPDATES
  onde update check [--wait]           Query the latest published main build
  onde update status                  Inspect availability and download state
  onde update download [--wait]        Download verified ZIP, never install it
  onde update automatic on|off         Enable or disable automatic checks

UI & AGENTS
  onde ui show
  onde ui page studio|library|mixes|settings|cli|history|credits|generative|updates
  onde ui quiet on|off
  onde schema                         Full machine-readable command schema
  onde call '<JSON object>'            Raw protocol, no shell evaluated by app
  onde quit

OPTIONS
  --launch  Explicitly start Onde.app if it is not running
  --json    Accepted for clarity; JSON is already the default
  --help    This guide

IPC: user-owned UNIX socket; no TCP port, no authentication token, no network.
The timer continues after its final meditation chime. Pauses don't count.
Closing the main window keeps the app in the menu bar. Quitting stops audio.
"""
let commandSpecs: [[String: Any]] = [
    ["command":"updates.status","arguments":[:],"effect":"Read current build, candidate, SHA256 and downloaded file"],
    ["command":"updates.check","arguments":[:],"effect":"Asynchronously check the fixed official GitHub repository"],
    ["command":"updates.download","arguments":[:],"effect":"Download and verify candidate into Downloads; no execution or installation"],
    ["command":"updates.automatic","arguments":["enabled":"boolean"],"effect":"Enable/disable periodic metadata checks; never auto-download"],
    ["command":"generate.profiles","arguments":[:],"effect":"List available original sound profiles; available offline via generate profiles"],
    ["command":"generate.profile","arguments":["id":"stable profile ID from generate profiles"],"effect":"Start profile; preserve global volume, chimes and saved mixes"],

    ["command":"generate.status","arguments":[:],"effect":"Live original synthesis state, seed, controls, render time, output level"],
    ["command":"generate.play","arguments":["mode":"focus|relax|meditation","seed":"optional integer 0...2^53-1","reset":"optional boolean"],"effect":"Solo the living layer, start mode, preserve chime preferences"],
    ["command":"generate.transition","arguments":["seconds":"number 2...30"],"effect":"Set persistent smooth crossfade duration; does not reset the timer"],
    ["command":"generate.set","arguments":["key":"density|brightness|movement|space|texture|pulse|evolution|settleMinutes|bass|tempo|stability|warmth|character|drive|punch|orchestra|strings|brass|woods|harp|ostinato|percussion|composition|vocals|piano","value":"number 0...1; settleMinutes 0...120; tempo 40...120; composition integer 0...7"],"effect":"Smoothly change a persisted per-mode generator parameter"],
    ["command":"generate.seed","arguments":["value":"integer 0...2^53-1"],"effect":"Change future generative choices smoothly, no timer reset"],
    ["command":"generate.defaults","arguments":[:],"effect":"Restore current mode synthesis defaults, not chimes or layer volumes"],

    ["command":"status","arguments":[:],"effect":"Read session, preferences, layers and errors"],
    ["command":"mode","arguments":["mode":"focus|relax|meditation","play":"boolean; default true","reset":"boolean; default false"],"effect":"Select mode; changing mode resets elapsed and restores that mode's mix"],
    ["command":"play","arguments":[:],"effect":"Start or resume audio and stopwatch; idempotent"],
    ["command":"pause","arguments":[:],"effect":"Pause audio and stopwatch"],
    ["command":"stop","arguments":[:],"effect":"Record session, stop audio, reset stopwatch"],
    ["command":"volume","arguments":["value":"number 0...1"],"effect":"Set master volume; chimes also follow it"],
    ["command":"sounds","arguments":[:],"effect":"List built-in and imported sounds with license and layer state"],
    ["command":"sound","arguments":["id":"sound id","enabled":"optional boolean","volume":"optional number 0...1"],"effect":"Change one layer without starting a stopped session"],
    ["command":"solo","arguments":["id":"sound id"],"effect":"Enable only this sound, preserve playback state"],
    ["command":"silence","arguments":[:],"effect":"Disable all sound beds, preserve timer and chimes"],
    ["command":"timer.reset","arguments":[:],"effect":"Reset stopwatch and fired markers, preserve running/paused state"],
    ["command":"timer.markers","arguments":["seconds":"array of <=32 positive numbers <=86400; [] disables all"],"effect":"Set sorted absolute times. Past markers won't replay. No repeating alert after the last."],
    ["command":"chime.preview","arguments":[:],"effect":"Play the soft glass chime once"],
    ["command":"settings","arguments":["key":"chimeVolume|fadeSeconds|startFadeSeconds|chimesEnabled|preventSleep|reducedMotion","value":"number 0...1 for chimeVolume, number 0...10 for fadeSeconds; 0...20 for startFadeSeconds; otherwise boolean"],"effect":"Persist preference"],
    ["command":"mixes","arguments":[:],"effect":"List saved mixes"],
    ["command":"mix.save","arguments":["name":"1...80 characters"],"effect":"Save current mode and layers"],
    ["command":"mix.load","arguments":["id":"mix id or name","play":"optional boolean, default true"],"effect":"Restore mix"],
    ["command":"mix.delete","arguments":["id":"mix id or name"],"effect":"Delete saved mix"],
    ["command":"import","arguments":["path":"local audio file <=500 MB","title":"optional display name"],"effect":"Copy into private library; original file unchanged"],
    ["command":"sound.remove","arguments":["id":"imported sound id"],"effect":"Delete only imported local copy and remove references"],
    ["command":"history","arguments":[:],"effect":"Read completed sessions"],
    ["command":"history.clear","arguments":[:],"effect":"Clear local completed session records"],
    ["command":"events","arguments":[:],"effect":"Read last 100 in-memory events, including actual chimes"],
    ["command":"ui","arguments":["page":"optional studio|library|mixes|settings|cli|history|credits|generative|updates","quiet":"optional boolean","show":"optional boolean"],"effect":"Control window navigation and quiet view"],
    ["command":"errors.clear","arguments":[:],"effect":"Dismiss current error"],
    ["command":"quit","arguments":[:],"effect":"Save, stop audio, quit app"]
]
func emit(_ object: Any) {
    do { var data = try jsonData(object); data.append(10); FileHandle.standardOutput.write(data) }
    catch { FileHandle.standardError.write(Data("JSON encoding failed\n".utf8)); exit(2) }
}
func fail(_ error: Error) -> Never {
    let e = error as? OndeError ?? OndeError("cli_error", error.localizedDescription)
    emit(["ok":false,"error":["code":e.code,"message":e.message]])
    exit(e.code == "not_running" ? 3 : 2)
}
var args = Array(CommandLine.arguments.dropFirst())
let launch = args.contains("--launch")
args.removeAll { $0 == "--launch" || $0 == "--json" }
if args.isEmpty || args == ["help"] || args.contains("--help") { print(help); exit(0) }
if args == ["generate", "profiles"] { emit(["ok":true,"result":jsonObject(SoundProfile.all)]); exit(0) }
if args == ["generate", "presets"] { emit(["ok":true,"result":SessionMode.allCases.map { ["mode":$0.rawValue,"title":GenerativeSettings.title($0),"configuration":jsonObject(GenerativeSettings.preset($0))] }]); exit(0) }
if args.first == "schema" {
    emit(["ok":true,"result":["name":"onde","version":AppBuild.version,"transport":"unix-domain-socket / JSON lines","socket":OndePaths.socket,"commands":commandSpecs,"default_markers_seconds":[600,1200,1800],"timer":"unlimited; no chimes after final marker","exit_codes":["0":"success","2":"invalid command or operation failed","3":"app not running"]]])
    exit(0)
}
func argument(_ i: Int) throws -> String {
    guard args.indices.contains(i) else { throw OndeError("missing_argument", "Missing argument. Run onde --help.") }; return args[i]
}
func value(_ text: String) throws -> Double {
    guard let number = Double(text), number.isFinite else { throw OndeError("invalid_argument", "Expected a finite number: \(text)") }; return number
}
func boolean(_ text: String) throws -> Bool {
    if ["on","true"].contains(text) { return true }; if ["off","false"].contains(text) { return false }
    throw OndeError("invalid_argument", "Expected on/off or true/false.")
}
func option(_ name: String) throws -> String? {
    guard let i = args.firstIndex(of: name) else { return nil }; return try argument(i + 1)
}
func launchApp() throws {
    let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Onde.app")
    let embedded = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let candidate = FileManager.default.fileExists(atPath: home.path) ? home.path : embedded.pathExtension == "app" ? embedded.path : "/Applications/Onde.app"
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/open"); process.arguments = [candidate]
    process.standardOutput = FileHandle.standardError
    try process.run(); process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw OndeError("launch_failed", "Could not open Onde.app. Install it first.") }
}
func send(_ request: [String: Any]) throws -> [String: Any] {
    do { return try LocalIPC.request(request) }
    catch let e as OndeError where e.code == "not_running" && launch {
        try launchApp()
        for _ in 0..<40 { Thread.sleep(forTimeInterval: 0.15); if let reply = try? LocalIPC.request(request) { return reply } }
        throw OndeError("not_running", "Onde did not become ready after launch.")
    }
}
do {

    if args.count >= 2 && args[0] == "generate" && args[1] == "transition-render" {
        guard let from = SoundProfile.find(try argument(2)), let to = SoundProfile.find(try argument(3)) else { throw OndeError("not_found", "Unknown composition.") }
        let seconds = try option("--seconds").map(value) ?? 60
        let at = try option("--at").map(value) ?? 20
        let fade = try option("--fade").map(value) ?? 10
        emit(["ok": true, "result": try TransitionRenderer.render(from: from, to: to, seconds: seconds, at: at, fade: fade, path: try argument(4))]); exit(0)
    }
    if args.count >= 2 && args[0] == "generate" && args[1] == "render" {
        let selection = try argument(2)
        let selectedProfile = SoundProfile.find(selection)
        guard let mode = selectedProfile?.mode ?? SessionMode(rawValue: selection) else { throw OndeError("invalid_mode", "Use a mode or profile ID from generate profiles.") }
        let path = try argument(3)
        let seconds = try option("--seconds").map(value) ?? ((try option("--minutes").map(value) ?? 2) * 60)
        var config = selectedProfile?.configuration ?? GenerativeSettings.preset(mode)
        if let text = try option("--seed") { guard let seed = UInt64(text) else { throw OndeError("invalid_seed", "Expected a nonnegative integer.") }; config.seed = seed }
        if let text = try option("--settings") {
            guard let settings = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { throw OndeError("invalid_settings", "Expected a JSON object of synthesis controls.") }
            for (key, raw) in settings {
                guard let n = raw as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { throw OndeError("invalid_settings", "Control values must be numbers, not booleans.") }
                try config.set(key, n.doubleValue)
            }
        }
        emit(["ok": true, "result": try GenerativeRenderer.render(mode: mode, configuration: config, seconds: seconds, path: path)])
        exit(0)
    }

    var request: [String: Any]
    switch args[0] {
    case "focus", "relax", "meditate", "meditation": request = ["command":"mode","mode":args[0] == "meditate" ? "meditation" : args[0],"reset":args.contains("--reset")]
    case "play", "pause", "stop", "status", "sounds", "silence", "mixes", "events", "quit": request = ["command":args[0]]

    case "update":
        let action = try argument(1)
        guard ["check","status","download","automatic"].contains(action) else { throw OndeError("unknown_command", "Use update check, status, download, or automatic.") }
        request = ["command":"updates." + action]
        if action == "automatic" { request["enabled"] = try boolean(argument(2)) }
    case "generate":
        switch try argument(1) {
        case "profiles": request = ["command":"generate.profiles"]
        case "profile": request = ["command":"generate.profile","id":try argument(2)]
        case "status", "defaults": request = ["command":"generate." + (try argument(1))]
        case "play":
            request = ["command":"generate.play","mode":try argument(2),"reset":args.contains("--reset")]
            if let text = try option("--seed") { request["seed"] = try value(text) }
        case "transition": request = ["command":"generate.transition","seconds":try value(argument(2))]
        case "set": request = ["command":"generate.set","key":try argument(2),"value":try value(argument(3))]
        case "seed": request = ["command":"generate.seed","value":try value(argument(2))]
        default: throw OndeError("unknown_command", "Use generate presets, play, set, seed, defaults, status, or render.")
        }
    case "volume": request = ["command":"volume","value":try value(argument(1))]
    case "sound":
        let id = try argument(1)
        if id == "remove" { request = ["command":"sound.remove","id":try argument(2)] }
        else {
            let action = try argument(2)
            request = ["command":"sound","id":id]
            if action == "volume" { request["volume"] = try value(argument(3)) }
            else { request["enabled"] = try boolean(action); if let v = try option("--volume") { request["volume"] = try value(v) } }
        }
    case "solo": request = ["command":"solo","id":try argument(1)]
    case "timer":
        switch try argument(1) {
        case "reset": request = ["command":"timer.reset"]
        case "markers":
            let raw = try argument(2)
            let list = raw.isEmpty ? [] : try raw.split(separator: ",", omittingEmptySubsequences: false).map { try value(String($0).trimmingCharacters(in: .whitespaces)) * (args.contains("--seconds") ? 1 : 60) }
            request = ["command":"timer.markers","seconds":try validMarkers(list)]
        default: throw OndeError("unknown_command", "Use timer reset or timer markers.")
        }
    case "chime": guard try argument(1) == "preview" else { throw OndeError("unknown_command", "Use chime preview.") }; request = ["command":"chime.preview"]
    case "settings":
        let key = try argument(1), raw = try argument(2)
        request = ["command":"settings","key":key]
        request["value"] = ["chimesEnabled","preventSleep","reducedMotion"].contains(key) ? try boolean(raw) as Any : try value(raw) as Any
    case "mix":
        let action = try argument(1)
        guard ["save","load","delete"].contains(action) else { throw OndeError("unknown_command", "Use mix save, load, or delete.") }
        request = ["command":"mix." + action, action == "save" ? "name" : "id":try argument(2)]
    case "import":
        request = ["command":"import","path":NSString(string: try argument(1)).expandingTildeInPath]
        if let title = try option("--title") { request["title"] = title }
    case "history": request = ["command":args.count > 1 && args[1] == "clear" ? "history.clear" : "history"]
    case "ui":
        request = ["command":"ui"]
        switch try argument(1) {
        case "show": request["show"] = true
        case "page": request["page"] = try argument(2)
        case "quiet": request["quiet"] = try boolean(argument(2))
        default: throw OndeError("unknown_command", "Use ui show, ui page, or ui quiet.")
        }
    case "call":
        guard let r = try JSONSerialization.jsonObject(with: Data(argument(1).utf8)) as? [String: Any] else { throw OndeError("invalid_json", "Expected a JSON object.") }; request = r
    case "watch":
        let interval = try option("--interval").map(value) ?? 1
        guard interval >= 0.25, interval <= 3600 else { throw OndeError("invalid_interval", "Interval must be 0.25...3600 seconds.") }
        while true { let reply = try send(["command":"status"]); emit(reply); if reply["ok"] as? Bool != true { exit(2) }; Thread.sleep(forTimeInterval: interval) }
    default: throw OndeError("unknown_command", "Unknown command '\(args[0])'. Run onde --help.")
    }
    var reply = try send(request)
    if args.first == "update", args.contains("--wait"), reply["ok"] as? Bool == true {
        let deadline = Date().addingTimeInterval(200)
        while let result = reply["result"] as? [String: Any], (result["checking"] as? Bool == true || result["downloading"] as? Bool == true), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25); reply = try send(["command":"updates.status"])
        }
        if let result = reply["result"] as? [String: Any] {
            if result["checking"] as? Bool == true || result["downloading"] as? Bool == true { throw OndeError("update_timeout", "The update operation is still in progress; inspect update status.") }
            if let error = result["error"] as? String { throw OndeError("update_failed", error) }
        }
    }
    emit(reply); exit(reply["ok"] as? Bool == true ? 0 : 2)
} catch { fail(error) }
