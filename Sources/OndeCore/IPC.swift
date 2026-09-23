import Foundation
import Darwin

public enum LocalIPC {
    public static func address(_ path: String) throws -> sockaddr_un {
        guard path.utf8.count < 104 else { throw OndeError("socket_path", "Socket path exceeds the macOS UNIX-domain limit.") }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                _ = path.withCString { strlcpy(dest, $0, 104) }
            }
        }
        return addr
    }
    public static func configure(_ fd: Int32, timeoutSeconds: Int = 5) {
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one)))
        var tv = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout.size(ofValue: tv)))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout.size(ofValue: tv)))
    }
    public static func sendAll(_ data: Data, fd: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                let n = Darwin.send(fd, base.advanced(by: offset), bytes.count - offset, 0)
                if n < 0 && errno == EINTR { continue }
                guard n > 0 else { throw OndeError("connection_lost", "Could not write to the local socket.") }
                offset += n
            }
        }
    }
    public static func readLine(fd: Int32, limit: Int = 1_048_576) throws -> Data {
        var result = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while result.count < limit {
            let n = Darwin.recv(fd, &buffer, min(buffer.count, limit - result.count), 0)
            if n < 0 && errno == EINTR { continue }
            guard n > 0 else { throw OndeError("invalid_response", "Local connection closed or timed out before a complete JSON line.") }
            if let end = buffer[..<n].firstIndex(of: 10) { result.append(contentsOf: buffer[..<end]); return result }
            result.append(contentsOf: buffer[..<n])
        }
        throw OndeError("request_too_large", "JSON message is too large.")
    }
    public static func request(_ object: [String: Any]) throws -> [String: Any] {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw OndeError("socket", "Could not create socket.") }
        defer { Darwin.close(fd) }
        // Cold Core Audio / first SwiftUI layout may outlast a 5-second client wait.
        // The server still limits untrusted request reads to five seconds.
        configure(fd, timeoutSeconds: 30)
        var addr = try address(OndePaths.socket)
        let rc = withUnsafePointer(to: &addr) { p in p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        guard rc == 0 else { throw OndeError("not_running", "Onde is not running. Launch Onde.app or add --launch.") }
        var data = try jsonData(object); data.append(10)
        try sendAll(data, fd: fd)
        guard let result = try JSONSerialization.jsonObject(with: readLine(fd: fd)) as? [String: Any] else { throw OndeError("invalid_response", "Expected a JSON object.") }
        return result
    }
}
/// Local-only socket, owner-only filesystem permissions, and peer UID validation.
public final class CommandServer {
    private var fd: Int32 = -1
    private var lockFD: Int32 = -1
    private let queue = DispatchQueue(label: "app.onde.command-server", qos: .utility)
    public init() {}
    public func start(handler: @escaping ([String: Any]) -> [String: Any]) throws {
        try OndePaths.prepare()
        lockFD = Darwin.open(OndePaths.support.appendingPathComponent("app.lock").path, O_CREAT | O_RDWR, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw OndeError("already_running", "Another Onde instance already owns this profile.") }
        fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw OndeError("socket", "Could not create command socket.") }
        unlink(OndePaths.socket)
        var addr = try LocalIPC.address(OndePaths.socket)
        let rc = withUnsafePointer(to: &addr) { p in p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        guard rc == 0 else { throw OndeError("socket", "Could not bind command socket: \(String(cString: strerror(errno)))") }
        chmod(OndePaths.socket, 0o600)
        guard Darwin.listen(fd, 8) == 0 else { throw OndeError("socket", "Could not listen on command socket.") }
        let serverFD = fd
        queue.async {
            while true {
                let client = Darwin.accept(serverFD, nil, nil)
                if client < 0 { if errno == EINTR { continue }; break }
                LocalIPC.configure(client)
                var uid: uid_t = 0; var gid: gid_t = 0
                guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { Darwin.close(client); continue }
                do {
                    let data = try LocalIPC.readLine(fd: client, limit: 65536)
                    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw OndeError("invalid_request", "Expected one JSON object.") }
                    try ControlRequestValidation.validate(object)
                    var response: [String: Any] = [:]
                    DispatchQueue.main.sync { response = handler(object) }
                    var reply = try jsonData(response); reply.append(10)
                    try LocalIPC.sendAll(reply, fd: client)
                } catch {
                    let e = error as? OndeError ?? OndeError("invalid_request", error.localizedDescription)
                    var reply = (try? jsonData(["ok": false, "error": ["code": e.code, "message": e.message]])) ?? Data(); reply.append(10)
                    try? LocalIPC.sendAll(reply, fd: client)
                }
                Darwin.close(client)
            }
        }
    }
}
