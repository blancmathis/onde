// Original deterministic compositions and textures. Code MIT, rendered sounds CC0.
// No sample libraries, generative AI models, network calls, or third-party assets.
import Foundation

let sr = 44100.0
let duration = 96.0
let n = Int(sr * duration)
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
var seed: UInt64 = 0x123456789abcdef
func noise() -> Double {
    seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
    return Double(seed >> 11) / Double(UInt64.max >> 11) * 2 - 1
}
func smooth(_ x: Double) -> Double { let v = max(0, min(1, x)); return v * v * (3 - 2 * v) }
func save(_ name: String, _ left: [Double], _ right: [Double], target: Double = 0.10, loop: Bool = true) throws {
    var l = left, r = right
    if loop {
        // Circular equal-power join: preserve duration, crossfade first/last 1.5s.
        let k = min(Int(sr * 1.5), l.count / 4)
        for i in 0..<k {
            let t = Double(i) / Double(k)
            let a = cos(t * .pi / 2), b = sin(t * .pi / 2)
            l[i] = left[l.count - k + i] * a + left[i] * b
            r[i] = right[r.count - k + i] * a + right[i] * b
        }
        // Remove the trailing crossfade region: new end leads into blended start.
        l.removeLast(k); r.removeLast(k)
    }
    let meanL = l.reduce(0,+) / Double(l.count), meanR = r.reduce(0,+) / Double(r.count)
    var energy = 0.0, peak = 0.0
    for i in l.indices { l[i] -= meanL; r[i] -= meanR; energy += l[i] * l[i] + r[i] * r[i]; peak = max(peak, abs(l[i]), abs(r[i])) }
    let rms = sqrt(energy / Double(l.count * 2))
    let gain = min(target / max(1e-10, rms), 0.58 / max(1e-10, peak))
    var data = Data(capacity: 44 + l.count * 4)
    func text(_ s: String) { data.append(contentsOf: s.utf8) }
    func u16(_ v: UInt16) { var b = v.littleEndian; withUnsafeBytes(of: &b) { data.append(contentsOf: $0) } }
    func u32(_ v: UInt32) { var b = v.littleEndian; withUnsafeBytes(of: &b) { data.append(contentsOf: $0) } }
    text("RIFF"); u32(UInt32(36 + l.count * 4)); text("WAVEfmt "); u32(16); u16(1); u16(2); u32(UInt32(sr)); u32(UInt32(sr * 4)); u16(4); u16(16); text("data"); u32(UInt32(l.count * 4))
    for i in l.indices {
        for x in [l[i], r[i]] {
            let v = Int16(max(-32767, min(32767, x * gain * 32767)))
            u16(UInt16(bitPattern: v))
        }
    }
    try data.write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".wav"))
    print("\(name): \(String(format:"%.1f",Double(l.count)/sr))s, RMS \(String(format:"%.4f",rms*gain)), peak \(String(format:"%.4f",peak*gain))")
}
func reverb(_ input: [Double], shifts: [Double], wet: Double) -> [Double] {
    var result = input
    for (j, sec) in shifts.enumerated() {
        let k = Int(sec * sr), gain = wet * pow(0.73, Double(j))
        for i in input.indices { result[(i + k) % input.count] += input[i] * gain }
    }
    return result
}
let tau = 2 * Double.pi
let chords: [[Double]] = [
    [130.8128,196.0,246.9417,293.6648],
    [110.0,164.8138,196.0,261.6256],
    [174.6141,220.0,261.6256,329.6276],
    [146.8324,196.0,220.0,293.6648]
]
var l = [Double](repeating: 0, count: n), r = l
// Aube: overlapping slow envelopes, gently detuned sine/triangle-like partials.
for chord in 0..<4 {
    let start = chord * 24
    for (voice, freq) in chords[chord].enumerated() {
        let pan = Double(voice) / 3
        for i in 0..<Int(sr * 34) {
            let t = Double(i) / sr
            let env = smooth(t / 8) * smooth((34 - t) / 10)
            let motion = 0.92 + 0.08 * sin(tau * t / (12 + Double(voice)))
            let f = freq * (voice == 0 ? 0.5 : 1)
            let s = (sin(tau * f * t) * 0.63 + sin(tau * f * 1.0014 * t + 0.8) * 0.26 + sin(tau * f * 2 * t) * 0.075 + sin(tau * f * 3 * t) * 0.025) * env * motion * 0.16
            let idx = (start * Int(sr) + i) % n
            l[idx] += s * sqrt(1 - pan * 0.7); r[idx] += s * sqrt(0.3 + pan * 0.7)
        }
    }
}
try save("aube", reverb(l, shifts:[0.37,0.71,1.19,1.91,2.71], wet:0.22), reverb(r, shifts:[0.43,0.83,1.37,2.13,2.93], wet:0.22))
// Piano de lune: original pentatonic electric-piano timbre, sparse phrasing.
l = Array(repeating:0,count:n); r = l
let notes = [261.6256,329.6276,391.9954,493.8833,587.3295,659.2551,783.9909]
for note in 0..<36 {
    let start = (Double(note) * 2.61 + (note % 4 == 3 ? 0.9 : 0))
    let f = notes[(note * 5 + note / 7) % notes.count] * (note % 6 == 0 ? 0.5 : 1)
    let pan = 0.25 + Double(note % 5) * 0.125
    for i in 0..<Int(sr * 10) {
        let t = Double(i) / sr
        let env = smooth(t / 0.035) * exp(-t / 2.3) * smooth((10 - t) / 2)
        let sound = (sin(tau*f*t + 0.30*sin(tau*f*2*t)*exp(-t/0.25)) + 0.26*sin(tau*f*2*t)*exp(-t/0.8) + 0.05*sin(tau*f*3.003*t)*exp(-t/0.4)) * env * (0.6 + 0.1*sin(Double(note)))
        let idx = (Int(start * sr) + i) % n
        l[idx] += sound * sqrt(1-pan); r[idx] += sound * sqrt(pan)
    }
}
try save("piano", reverb(l, shifts:[0.31,0.59,0.97,1.49,2.33,3.51], wet:0.35), reverb(r, shifts:[0.37,0.67,1.13,1.71,2.57,3.83], wet:0.35), target:0.08)
// Orbite: soft glass/pluck pattern, slow changes; no claimed entrainment.
l = Array(repeating:0,count:n); r = l
for note in 0..<64 {
    let f = notes[(note * 3 + note / 8) % 7]
    let start = Double(note) * 1.5
    for i in 0..<Int(sr * 5.5) {
        let t = Double(i) / sr
        let env = smooth(t/0.065) * exp(-t/1.1) * smooth((5.5-t)/1.0)
        let s = (sin(tau*f*t) + 0.14*sin(tau*f*2.001*t)*exp(-t*2)) * env * 0.45
        let idx = (Int(start*sr) + i) % n
        l[idx] += s*(0.6 + 0.15*sin(Double(note))); r[idx] += s*(0.6 - 0.15*sin(Double(note)))
    }
}
try save("orbit", reverb(l,shifts:[0.43,0.83,1.37,2.21],wet:0.4), reverb(r,shifts:[0.51,0.97,1.51,2.47],wet:0.4),target:0.07)
// Independent left/right noise filters, correlated base: comfortable stereo.
for kind in ["brown","pink","rain","ocean"] {
    l = Array(repeating:0,count:n); r = l
    var brownL = 0.0, brownR = 0.0
    var bL = [Double](repeating:0,count:7), bR = bL
    var prevL = 0.0, prevR = 0.0, lowL = 0.0, lowR = 0.0
    func pink(_ white: Double, _ b: inout [Double]) -> Double {
        b[0] = 0.99886*b[0] + white*0.0555179
        b[1] = 0.99332*b[1] + white*0.0750759
        b[2] = 0.969*b[2] + white*0.153852
        b[3] = 0.8665*b[3] + white*0.3104856
        b[4] = 0.55*b[4] + white*0.5329522
        b[5] = -0.7616*b[5] - white*0.016898
        let s = b[0]+b[1]+b[2]+b[3]+b[4]+b[5]+b[6]+white*0.5362
        b[6] = white*0.115926; return s*0.11
    }
    for i in 0..<n {
        let t = Double(i)/sr
        let common = noise(), wl = 0.60*common + 0.40*noise(), wr = 0.60*common + 0.40*noise()
        let pl = pink(wl,&bL), pr = pink(wr,&bR)
        brownL = 0.9985*brownL + wl*0.025; brownR = 0.9985*brownR + wr*0.025
        var a = 0.0, b = 0.0
        switch kind {
        case "brown": a = brownL; b = brownR
        case "pink": a = pl; b = pr
        case "rain":
            let swell = 0.8 + 0.11*sin(tau*t/24) + 0.035*sin(tau*t/7.2)
            lowL += 0.24*(pl-lowL); lowR += 0.24*(pr-lowR)
            a = (lowL*0.7 + (wl-prevL)*0.025)*swell
            b = (lowR*0.7 + (wr-prevR)*0.025)*swell
        default:
            let waveL = 0.17 + 0.75*pow(0.5+0.5*sin(tau*t/12 - 0.9),2)
            let waveR = 0.17 + 0.75*pow(0.5+0.5*sin(tau*t/12 - 1.06),2)
            lowL += 0.07*(pl-lowL); lowR += 0.07*(pr-lowR)
            a = (lowL*0.75+brownL*0.30)*waveL; b = (lowR*0.75+brownR*0.30)*waveR
        }
        prevL = wl; prevR = wr; l[i] = a; r[i] = b
    }
    try save(kind,l,r,target:0.09)
}
// Gentle struck glass: 70ms attack, soft inharmonic partials, six-second tail.
let bellN = Int(sr*7)
l = Array(repeating:0,count:bellN); r = l
for i in 0..<bellN {
    let t = Double(i)/sr
    let attack = smooth(t/0.07), tail = smooth((7-t)/1.3)
    let s = (sin(tau*659.255*t)*exp(-t/1.65) + 0.21*sin(tau*1319.1*t)*exp(-t/0.82) + 0.035*sin(tau*1814*t)*exp(-t/0.35)) * attack * tail
    l[i] = s; r[i] = s*0.98
}
try save("chime",l,r,target:0.065,loop:false)
