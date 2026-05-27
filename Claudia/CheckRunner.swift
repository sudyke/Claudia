import Foundation

// Dispatches a CheckSpec to the appropriate probe. Runs off the main actor.
enum CheckRunner {
    nonisolated static func run(_ spec: CheckSpec) async -> Bool {
        switch spec {
        case .http(let url, let method):
            return await httpProbe(urlString: url, method: method.rawValue, timeout: 3)
        case .tcp(let host, let port):
            return await tcpProbe(host: host, port: port, timeout: 3)
        case .shell(let binary, let args):
            guard !binary.isEmpty, FileManager.default.isExecutableFile(atPath: binary) else {
                return false
            }
            return await runShell(binary, args, timeout: 3)
        }
    }
}

// MARK: - HTTP

private nonisolated func httpProbe(urlString: String, method: String, timeout: TimeInterval) async -> Bool {
    guard let url = URL(string: urlString) else { return false }

    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = timeout
    config.timeoutIntervalForResource = timeout
    config.waitsForConnectivity = false
    let session = URLSession(configuration: config)
    defer { session.finishTasksAndInvalidate() }

    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.httpMethod = method

    do {
        let (_, response) = try await session.data(for: request)
        return response is HTTPURLResponse
    } catch {
        return false
    }
}

// MARK: - TCP

private nonisolated func tcpProbe(host: String, port: Int, timeout: TimeInterval) async -> Bool {
    // POSIX socket connect with non-blocking + select for timeout. Pure C; portable.
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }

    // Non-blocking
    let flags = fcntl(fd, F_GETFL, 0)
    _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = UInt16(port).bigEndian
    let hostCopy = host

    // Resolve hostname → IPv4
    guard let addrInfo = resolveIPv4(host: hostCopy) else { return false }
    addr.sin_addr = addrInfo

    let result = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
            connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }

    if result == 0 { return true }  // Connected immediately

    // EINPROGRESS expected for non-blocking connect; wait for writability via select.
    guard errno == EINPROGRESS else { return false }

    var writeSet = fd_set()
    fdZero(&writeSet)
    fdSet(fd, &writeSet)

    var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
    let selectResult = select(fd + 1, nil, &writeSet, nil, &tv)

    guard selectResult > 0 else { return false }

    // Check SO_ERROR to see if connect actually succeeded
    var soError: Int32 = 0
    var len = socklen_t(MemoryLayout<Int32>.size)
    let optResult = getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
    return optResult == 0 && soError == 0
}

private nonisolated func resolveIPv4(host: String) -> in_addr? {
    // Numeric IP path first
    var addr = in_addr()
    if inet_pton(AF_INET, host, &addr) == 1 {
        return addr
    }
    // Hostname lookup
    var hints = addrinfo()
    hints.ai_family = AF_INET
    hints.ai_socktype = SOCK_STREAM
    var result: UnsafeMutablePointer<addrinfo>?
    let err = getaddrinfo(host, nil, &hints, &result)
    guard err == 0, let r = result else { return nil }
    defer { freeaddrinfo(r) }
    guard let ai = r.pointee.ai_addr else { return nil }
    let sin = ai.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
    return sin.sin_addr
}

// fd_set helpers — Swift can't bit-manipulate the C macros directly.
private nonisolated func fdZero(_ set: inout fd_set) {
    set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

private nonisolated func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd / 32)
    let bitOffset = Int(fd % 32)
    let mask: Int32 = 1 << bitOffset
    withUnsafeMutablePointer(to: &set.fds_bits) { tuple in
        tuple.withMemoryRebound(to: Int32.self, capacity: 32) { ints in
            ints[intOffset] |= mask
        }
    }
}
