import XCTest
import OndeDSP
@testable import OndeCore

final class LivingV4Tests: XCTestCase {
    func render(_ configuration: GenerativeSettings, seconds: Int = 12) throws -> [Float] {
        let core = try XCTUnwrap(onde_dsp_create(22050, 0, configuration.seed)); defer { onde_dsp_destroy(core) }
        for (i,v) in configuration.values.enumerated() { onde_dsp_set(core, GenerativeSettings.dspIndex(i), Float(v)) }
        onde_dsp_set(core, Int32(ONDE_GAIN), 1)
        let n = 22050 * seconds
        var l = [Float](repeating: 0, count: n), r = l
        onde_dsp_render(core, &l, &r, UInt32(n))
        XCTAssertTrue(l.allSatisfy { $0.isFinite && abs($0) <= 0.951 })
        XCTAssertTrue(r.allSatisfy { $0.isFinite && abs($0) <= 0.951 })
        return l
    }
    func testNewControlsDefaultToZeroForOldConfigurations() throws {
        var object = jsonObject(GenerativeSettings()) as! [String: Any]
        object.removeValue(forKey: "drive"); object.removeValue(forKey: "punch")
        let config = try JSONDecoder().decode(GenerativeSettings.self, from: jsonData(object))
        XCTAssertEqual(config.drive, 0); XCTAssertEqual(config.punch, 0)
        XCTAssertEqual(GenerativeSettings.dspIndex(13), Int32(ONDE_DRIVE))
        XCTAssertEqual(GenerativeSettings.dspIndex(14), Int32(ONDE_PUNCH))
    }
    func testThreeEnergeticProfilesValidateAndAreAudible() throws {
        for id in ["elan", "reacteur", "traction"] {
            let p = try XCTUnwrap(SoundProfile.find(id)); _ = try p.configuration.validated()
            let x = try render(p.configuration)
            XCTAssertGreaterThan(x.map { abs($0) }.max() ?? 0, 0.2)
            XCTAssertGreaterThan(p.configuration.drive, 0.5)
        }
    }
    func testImpactAddsMeasurableTransientEnergyNotJustTempo() throws {
        var c = try XCTUnwrap(SoundProfile.find("reacteur")).configuration
        let energized = try render(c)
        c.drive = 0; c.punch = 0
        let legacy = try render(c)
        let energyA = energized.dropFirst(22050).reduce(0.0) { $0 + Double($1 * $1) }
        let energyB = legacy.dropFirst(22050).reduce(0.0) { $0 + Double($1 * $1) }
        XCTAssertGreaterThan(energyA, energyB * 1.2)
        XCTAssertNotEqual(energized, legacy)
    }
    func testMaximumImpactHasHeadroomAndRemainsFinite() throws {
        var c = GenerativeSettings(); c.drive=1; c.punch=1; c.bass=1; c.density=1; c.tempo=120
        _ = try render(c, seconds: 20)
    }
}
