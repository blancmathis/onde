import Foundation
import AVFoundation
import CryptoKit
import OndeDSP

/// Immutable acoustic notes are decoded and verified before Core Audio starts.
/// The same bank is used by the app and standalone exports. Nothing is fetched at runtime.
public enum OrchestraBank {
    private final class Note {
        let instrument: Int32; let root: Int32; let rr: Int32; let pcm: OpaquePointer
        init(instrument: Int32, root: Int32, rr: Int32, pcm: OpaquePointer) {
            self.instrument = instrument; self.root = root; self.rr = rr; self.pcm = pcm
        }
        deinit { onde_sample_buffer_release(pcm) }
    }
    private static let lock=NSLock()
    private static var cache:[String:[Note]]=[:]
    public static func directory() -> URL? {
        let fm=FileManager.default
        if let p=ProcessInfo.processInfo.environment["ONDE_ORCHESTRA_DIR"] {
            guard p.hasPrefix("/"),fm.fileExists(atPath:p+"/manifest.json") else {return nil}
            return URL(fileURLWithPath:p,isDirectory:true)
        }
        let executable=URL(fileURLWithPath:CommandLine.arguments[0]).resolvingSymlinksInPath()
        var options:[URL]=[]
        if let resource=Bundle.main.resourceURL {options.append(resource.appendingPathComponent("Orchestra"))}
        options.append(executable.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Orchestra"))
        options.append(URL(fileURLWithPath:fm.currentDirectoryPath).appendingPathComponent("Assets/Orchestra"))
        return options.first{fm.fileExists(atPath:$0.appendingPathComponent("manifest.json").path)}
    }
    @discardableResult public static func load(into core:OpaquePointer,required:Bool) throws -> Int {
        guard let directory=directory() else {
            if required {throw OndeError("orchestra_missing","The orchestra bank is missing. Install the complete app or run Tools/prepare_orchestra.sh.")}
            return 0
        }
        let notes=try decoded(directory)
        for note in notes {
            let ok = onde_dsp_add_shared_sample(core, note.instrument, note.root, note.rr, note.pcm)
            guard ok==1 else {throw OndeError("orchestra_invalid","Could not load an instrument before audio rendering.")}
        }
        guard (onde_dsp_orchestra_families(core) & 2047)==2047 else {throw OndeError("orchestra_incomplete","The orchestra bank is missing required instrument families.")}
        return notes.count
    }
    private static func decoded(_ directory:URL) throws -> [Note] {
        lock.lock();defer{lock.unlock()}
        if let existing=cache[directory.path] {return existing}
        let data=try Data(contentsOf:directory.appendingPathComponent("manifest.json"))
        guard data.count<2_000_000,let object=try JSONSerialization.jsonObject(with:data) as? [String:Any],object["license"] as? String=="CC0-1.0",let samples=object["samples"] as? [[String:Any]],samples.count>=11,samples.count<=112 else {throw OndeError("orchestra_invalid","Invalid orchestra manifest.")}
        var result:[Note]=[];var total=0
        for item in samples {
            guard let name=item["filename"] as? String,name==URL(fileURLWithPath:name).lastPathComponent,!name.hasPrefix("."),let instrument=item["instrument"] as? Int,(0...11).contains(instrument),let root=item["root_midi"] as? Int,(0...127).contains(root),let rr=item["round_robin"] as? Int,(0...7).contains(rr),let digest=item["processed_sha256"] as? String else {throw OndeError("orchestra_invalid","Invalid instrument metadata.")}
            let url=directory.appendingPathComponent(name),bytes=try Data(contentsOf:url)
            guard bytes.count<=12_000_000,SHA256.hash(data:bytes).map({String(format:"%02x",$0)}).joined()==digest else {throw OndeError("orchestra_checksum","Instrument integrity check failed: \(name).")}
            let f=try AVAudioFile(forReading:url,commonFormat:.pcmFormatFloat32,interleaved:false)
            guard f.length>=64,f.length<=1_500_000,f.processingFormat.channelCount==2 else {throw OndeError("orchestra_invalid","Invalid instrument format.")}
            total+=Int(f.length);guard total<=24_000_000 else {throw OndeError("orchestra_too_large","The instrument bank exceeds the memory limit.")}
            let buffer=AVAudioPCMBuffer(pcmFormat:f.processingFormat,frameCapacity:AVAudioFrameCount(f.length))!
            try f.read(into:buffer);let channels=buffer.floatChannelData!,count=Int(buffer.frameLength)
            guard let pcm = onde_sample_buffer_create(channels[0], channels[1], UInt32(count), f.processingFormat.sampleRate) else {
                throw OndeError("orchestra_invalid", "The instrument contains invalid PCM samples.")
            }
            result.append(Note(instrument: Int32(instrument), root: Int32(root), rr: Int32(rr), pcm: pcm))
        }
        cache[directory.path]=result;return result
    }
}
