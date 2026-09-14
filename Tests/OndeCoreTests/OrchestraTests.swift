import XCTest
import OndeDSP
@testable import OndeCore
final class OrchestraTests:XCTestCase {
    func testOldSettingsKeepAcousticLayerDisabled() throws {
        var o=jsonObject(GenerativeSettings()) as! [String:Any]
        for k in ["orchestra","strings","brass","woods","harp","ostinato","percussion"] {o.removeValue(forKey:k)}
        let c=try JSONDecoder().decode(GenerativeSettings.self,from:jsonData(o))
        XCTAssertEqual(c.orchestra,0)
        XCTAssertEqual(GenerativeSettings.dspIndex(15),Int32(ONDE_ORCHESTRA))
        XCTAssertEqual(GenerativeSettings.dspIndex(21),Int32(ONDE_PERCUSSION))
    }
    func testFourOriginalEnsemblesValidate() throws {
        let profiles=SoundProfile.all.filter{$0.configuration.orchestra>0}
        XCTAssertEqual(profiles.map(\.id),["atlas","ostinato","aurore","chambre"])
        for p in profiles { _ = try p.configuration.validated();XCTAssertEqual(p.mode,.focus) }
    }
    func testSamplerRejectsInvalidMetadataAndLateLoading() throws {
        let core=try XCTUnwrap(onde_dsp_create(22050,0,42));defer{onde_dsp_destroy(core)}
        var a=[Float](repeating:0.1,count:256),b=a
        XCTAssertEqual(onde_dsp_add_sample(core,11,60,0,&a,&b,256,22050),0)
        XCTAssertEqual(onde_dsp_add_sample(core,0,128,0,&a,&b,256,22050),0)
        XCTAssertEqual(onde_dsp_add_sample(core,0,60,0,&a,&b,256,0),0)
        XCTAssertEqual(onde_dsp_add_sample(core,0,60,0,&a,&b,256,22050),1)
        XCTAssertEqual(onde_dsp_add_sample(core,0,60,0,&a,&b,256,22050),0)
        onde_dsp_render(core,&a,&b,1)
        XCTAssertEqual(onde_dsp_add_sample(core,0,60,1,&a,&b,256,22050),0)
    }
    func testRealBankLoadsAllElevenArticulations() throws {
        guard OrchestraBank.directory() != nil else {throw XCTSkip("Run Tools/prepare_orchestra.sh for real-bank validation")}
        let core=try XCTUnwrap(onde_dsp_create(44100,0,6040));defer{onde_dsp_destroy(core)}
        XCTAssertEqual(try OrchestraBank.load(into:core,required:true),67)
        XCTAssertEqual(onde_dsp_orchestra_families(core),2047)
        let config=try XCTUnwrap(SoundProfile.find("atlas")).configuration
        for (i,v) in config.values.enumerated() {onde_dsp_set(core,GenerativeSettings.dspIndex(i),Float(v))}
        onde_dsp_set(core,Int32(ONDE_GAIN),1)
        var l=[Float](repeating:0,count:1024),r=l;var peak:Float=0
        for _ in 0..<220 {
            onde_dsp_render(core,&l,&r,1024)
            XCTAssertTrue(l.allSatisfy{$0.isFinite && abs($0)<=0.951})
            peak=max(peak,l.map{abs($0)}.max() ?? 0)
        }
        XCTAssertGreaterThan(onde_dsp_orchestra_events(core),30)
        XCTAssertGreaterThan(onde_dsp_orchestra_voices(core),5)
        XCTAssertGreaterThan(peak,0.025)
        XCTAssertEqual(onde_dsp_grain_events(core),0)
    }
    func testAllSectionBoundsAreEnforced() throws {
        var c=GenerativeSettings()
        for k in ["orchestra","strings","brass","woods","harp","ostinato","percussion"] {
            XCTAssertThrowsError(try c.set(k,-0.1));XCTAssertThrowsError(try c.set(k,1.1));XCTAssertThrowsError(try c.set(k,.nan))
            try c.set(k,0.4);XCTAssertEqual(c.value(k),0.4)
        }
    }
}
