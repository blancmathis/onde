#if canImport(Compression)
import Foundation
import Compression

/// Apple's raw-DEFLATE decoder verifies the actual output bound before ditto can
/// write anything. A dishonest ZIP size cannot expand until the disk is full.
enum UpdateArchiveInflation {
    static func validate(_ data: Data, start: Int, count: Int, expected: Int) throws {
        func reject() -> Error { OndeError("update_archive", "The compressed update is damaged or exceeds its declared size.") }
        guard count > 0, start >= 0, start + count <= data.count else { throw reject() }
        try data.withUnsafeBytes { raw in
            guard let bytes = raw.bindMemory(to: UInt8.self).baseAddress else { throw reject() }
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65_536)
            defer { buffer.deallocate() }
            var stream = compression_stream(dst_ptr: buffer, dst_size: 0, src_ptr: bytes.advanced(by: start), src_size: 0, state: nil)
            guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) != COMPRESSION_STATUS_ERROR else { throw reject() }
            defer { compression_stream_destroy(&stream) }
            stream.src_ptr = bytes.advanced(by: start)
            stream.src_size = count
            var total = 0
            while true {
                stream.dst_ptr = buffer
                stream.dst_size = 65_536
                let previousInput = stream.src_size
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let produced = 65_536 - stream.dst_size
                total += produced
                guard total <= expected, status != COMPRESSION_STATUS_ERROR else { throw reject() }
                if status == COMPRESSION_STATUS_END {
                    guard total == expected, stream.src_size == 0 else { throw reject() }
                    return
                }
                guard produced > 0 || stream.src_size < previousInput else { throw reject() }
            }
        }
    }
}
#endif
