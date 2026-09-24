import XCTest
import OndeDSP

final class SharedSampleTests: XCTestCase {
    func testPCMIsRetainedAcrossScenesAndIndependentOfSourceMemory() throws {
        var left = (0..<2048).map { Float(sin(Double($0) * 0.08) * 0.1) }
        let buffer = try XCTUnwrap(left.withUnsafeBufferPointer {
            onde_sample_buffer_create($0.baseAddress, nil, UInt32($0.count), 44100)
        })
        let a = try XCTUnwrap(onde_dsp_create(44100, 0, 42))
        let b = try XCTUnwrap(onde_dsp_create(44100, 0, 42))
        XCTAssertEqual(onde_sample_buffer_references(buffer), 1)
        XCTAssertEqual(onde_dsp_add_shared_sample(a, 0, 60, 0, buffer), 1)
        XCTAssertEqual(onde_dsp_add_shared_sample(b, 0, 60, 0, buffer), 1)
        XCTAssertEqual(onde_sample_buffer_references(buffer), 3)
        left = [Float](repeating: .nan, count: 2048) // Creator memory is not borrowed.
        onde_dsp_destroy(a)
        XCTAssertEqual(onde_sample_buffer_references(buffer), 2)
        onde_sample_buffer_release(buffer) // Other scene still owns its PCM.
        var l = [Float](repeating: 0, count: 512), r = l
        for _ in 0..<100 { onde_dsp_render(b, &l, &r, 512) }
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
        XCTAssertEqual(onde_dsp_orchestra_samples(b), 1)
        onde_dsp_destroy(b)
    }
    func testInvalidPCMAndDuplicateNotesCannotEnterBank() throws {
        var invalid = [Float](repeating: .nan, count: 64)
        XCTAssertNil(onde_sample_buffer_create(&invalid, nil, 64, 44100))
        var valid = [Float](repeating: 0.1, count: 128)
        let buffer = try XCTUnwrap(onde_sample_buffer_create(&valid, nil, 128, 44100))
        defer { onde_sample_buffer_release(buffer) }
        let core = try XCTUnwrap(onde_dsp_create(44100, 0, 42))
        defer { onde_dsp_destroy(core) }
        XCTAssertEqual(onde_dsp_add_shared_sample(core, 0, 60, 0, buffer), 1)
        XCTAssertEqual(onde_dsp_add_shared_sample(core, 0, 60, 0, buffer), 0)
        XCTAssertEqual(onde_dsp_add_shared_sample(core, 12, 60, 0, buffer), 0)
        XCTAssertEqual(onde_sample_buffer_references(buffer), 2)
        var l = [Float](repeating: 0, count: 128), r = l
        onde_dsp_render(core, &l, &r, 128)
        XCTAssertEqual(onde_dsp_add_shared_sample(core, 1, 60, 0, buffer), 0)
        XCTAssertEqual(onde_sample_buffer_references(buffer), 2)
    }
}
