import Foundation

// Free async functions, run off the main actor (nonisolated).
// Return Bool; no throwing — a failed check is a normal result, not an error.

nonisolated func checkDocker() async -> Bool {
    // Login-launched apps inherit a minimal PATH. Resolve the binary explicitly.
    let candidates = [
        "/opt/homebrew/bin/docker",
        "/usr/local/bin/docker",
        "/usr/bin/docker",
    ]
    guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
        return false
    }
    return await runShell(path, ["info", "--format", "{{.ServerVersion}}"], timeout: 3)
}

nonisolated func checkSupabase(port: Int) async -> Bool {
    await httpProbe(urlString: "http://localhost:\(port)/health", method: "GET", timeout: 3)
}

nonisolated func checkDevServer(port: Int) async -> Bool {
    await httpProbe(urlString: "http://localhost:\(port)", method: "HEAD", timeout: 3)
}

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
