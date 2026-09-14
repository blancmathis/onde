import Foundation
import AVFoundation
import CryptoKit

// Build-time only: trim recording silence, preserve stereo and real attack,
// normalize with a fixed ceiling. Never runs in the audio callback.
let args=CommandLine.arguments
guard args.count==4 else { fatalError("PrepareOrchestra manifest.json rawDirectory outputDirectory") }
let manifestURL=URL(fileURLWithPath:args[1]),raw=URL(fileURLWithPath:args[2]),out=URL(fileURLWithPath:args[3])
let sourceData=try Data(contentsOf:manifestURL)
var manifest=try JSONSerialization.jsonObject(with:sourceData) as! [String:Any]
let sourceHash=SHA256.hash(data:sourceData).map{String(format:"%02x",$0)}.joined()
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
var processed:[[String:Any]]=[]
for var item in manifest["samples"] as! [[String:Any]] {
 let name=item["filename"] as! String,inst=item["instrument"] as! Int
 let file=try AVAudioFile(forReading:raw.appendingPathComponent(name),commonFormat:.pcmFormatFloat32,interleaved:false)
 guard file.length>64 && file.length<=2_000_000 else { fatalError("Unexpected source duration") }
 let buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(file.length))!
 try file.read(into:buffer)
 let channels=buffer.floatChannelData!,n=Int(buffer.frameLength),sr=file.processingFormat.sampleRate
 let lc=channels[0],rc=channels[Int(file.processingFormat.channelCount)-1]
 var peak:Float=0
 for i in 0..<n {peak=max(peak,abs(lc[i]),abs(rc[i]))}
 guard peak>0.0001 else {fatalError("Empty instrument: \(name)")}
 let threshold=max(Float(0.00002),peak*0.006)
 var first=0,last=n-1
 while first<n-1 && max(abs(lc[first]),abs(rc[first]))<threshold {first+=1}
 while last>first && max(abs(lc[last]),abs(rc[last]))<threshold*0.3 {last-=1}
 first=max(0,first-Int(sr*0.012));last=min(n-1,last+Int(sr*0.040))
 let sustained=[0,1,2,5,6,7].contains(inst)
 let maximum=sustained ? 7.5 : inst==8 ? 6.5 : inst==9 ? 4.5 : inst==10 ? 3.5 : 2.2
 last=min(last,first+Int(maximum*sr)-1);let count=last-first+1
 guard count>64 else {fatalError("Too short: \(name)")}
 var meanL:Double=0,meanR:Double=0
 for i in first...last {meanL+=Double(lc[i]);meanR+=Double(rc[i])}
 let dcL=Float(meanL/Double(count)),dcR=Float(meanR/Double(count))
 var energy:Double=0,maxWindow:Double=0,newPeak:Float=0
 let hop=max(64,Int(sr*0.080))
 for offset in stride(from:first,through:last,by:hop) {
  energy=0;let end=min(last+1,offset+hop)
  for i in offset..<end {let a=lc[i]-dcL,b=rc[i]-dcR;energy+=Double(a*a+b*b);newPeak=max(newPeak,abs(a),abs(b))}
  maxWindow=max(maxWindow,sqrt(energy/Double((end-offset)*2)))
 }
 let desired=sustained ? 0.15/max(0.00001,maxWindow) : 0.58/Double(max(0.00001,newPeak))
 let gain=Float(min(32,desired,0.72/Double(max(0.00001,newPeak))))
 let format=AVAudioFormat(standardFormatWithSampleRate:sr,channels:2)!
 let rendered=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(count))!;rendered.frameLength=AVAudioFrameCount(count)
 let dest=rendered.floatChannelData!;var a:Float=0,b:Float=0
 let coef=Float(1-exp(-2*Double.pi*6800/sr)),fade=Int(sr*0.005)
 for j in 0..<count {
  a+=coef*((lc[first+j]-dcL)*gain-a);b+=coef*((rc[first+j]-dcR)*gain-b)
  let fadeIn=min(1,Float(j)/Float(max(1,fade))),fadeOut=min(1,Float(count-1-j)/Float(max(1,fade)))
  let f=fadeIn*fadeOut;dest[0][j]=a*f;dest[1][j]=b*f
 }
 let target=out.appendingPathComponent(name)
 do {
  let settings:[String:Any]=[AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:sr,AVNumberOfChannelsKey:2,AVLinearPCMBitDepthKey:16,AVLinearPCMIsFloatKey:false,AVLinearPCMIsBigEndianKey:false]
  let f=try AVAudioFile(forWriting:target,settings:settings,commonFormat:.pcmFormatFloat32,interleaved:false)
  try f.write(from:rendered)
 }
 let data=try Data(contentsOf:target)
 item["processed_sha256"]=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
 item["frames"]=count;item["sample_rate"]=sr;item["trim_start_frames"]=first;item["normalization_gain"]=gain
 processed.append(item)
}
manifest["samples"]=processed;manifest["source_manifest_sha256"]=sourceHash;manifest["processing_version"]=1
manifest["processing"]="Stereo PCM16; silent edges trimmed with 12ms preroll; DC removed; controlled level normalization; 6.8kHz one-pole smoothing; 5ms edge fades. No synthetic hiss added."
let json=try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
try json.write(to:out.appendingPathComponent("manifest.json"),options:.atomic)
print("Prepared \(processed.count) acoustic recordings.")
