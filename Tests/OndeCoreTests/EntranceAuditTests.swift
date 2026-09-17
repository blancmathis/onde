import XCTest
import OndeDSP

final class EntranceAuditTests: XCTestCase {
    func testFirstSampleAndIntermediateFramesSurviveLatePolling() throws {
        let mixer = try XCTUnwrap(onde_scene_mixer_create(8000))
        defer { onde_scene_mixer_destroy(mixer) }
        let core = try XCTUnwrap(onde_dsp_create(8000, 0, 42))
        XCTAssertEqual(onde_scene_mixer_submit(mixer, core, 2), 1)
        onde_scene_mixer_gain(mixer, 0.5)
        onde_scene_mixer_playback(mixer, 1, 2)
        XCTAssertEqual(onde_scene_mixer_entrance_pending(mixer), 1)
        var l = [Float](repeating: 0, count: 256), r = l
        // Deliberately don't inspect the first two seconds: the render audit must retain them.
        for _ in 0..<125 { onde_scene_mixer_render(mixer, &l, &r, 256) }
        XCTAssertEqual(onde_scene_mixer_entrance_pending(mixer), 0)
        XCTAssertEqual(onde_scene_mixer_entrance_first_gain(mixer), 0)
        XCTAssertEqual(onde_scene_mixer_entrance_frames(mixer), 32000)
        XCTAssertGreaterThan(onde_scene_mixer_entrance_intermediate(mixer), 15000)
        XCTAssertEqual(onde_scene_mixer_entrance_gain(mixer), 1)
        let serial = onde_scene_mixer_entrance_serial(mixer)
        onde_scene_mixer_gain(mixer, 0.3)
        onde_scene_mixer_render(mixer, &l, &r, 256)
        XCTAssertEqual(onde_scene_mixer_entrance_serial(mixer), serial)
        XCTAssertEqual(onde_scene_mixer_entrance_first_gain(mixer), 0)
    }
}
