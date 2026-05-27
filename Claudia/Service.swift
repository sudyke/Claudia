import Foundation

// User-configurable service: name, how to check it, how to start it when down.
struct Service: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var check: CheckSpec
    var startCommand: StartSpec?
    var enabled: Bool

    init(id: UUID = UUID(), name: String, check: CheckSpec, startCommand: StartSpec? = nil, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.check = check
        self.startCommand = startCommand
        self.enabled = enabled
    }
}

// MARK: - Check types

enum CheckSpec: Codable, Hashable, Sendable {
    case http(url: String, method: HTTPMethod)
    case tcp(host: String, port: Int)
    case shell(binary: String, args: [String])

    nonisolated var summary: String {
        switch self {
        case .http(let url, let method):
            return "\(method.rawValue) \(url)"
        case .tcp(let host, let port):
            return "TCP \(host):\(port)"
        case .shell(let binary, let args):
            return "\(binary) \(args.joined(separator: " "))"
        }
    }
}

enum HTTPMethod: String, Codable, Hashable, Sendable, CaseIterable {
    case get  = "GET"
    case head = "HEAD"
}

// MARK: - Start action types

enum StartSpec: Codable, Hashable, Sendable {
    /// Opens a macOS app by name (e.g. "Docker", "OrbStack"). Runs `open -a <name>`.
    case openApp(name: String)
    /// Opens Terminal.app and runs `cd <workdir> && <command>`. Long-running commands belong here.
    case terminal(workdir: String, command: String)
    /// Runs a shell command and waits for it to finish. Use for quick commands that exit on success.
    case shell(binary: String, args: [String])

    nonisolated var summary: String {
        switch self {
        case .openApp(let name):              return "Open \(name).app"
        case .terminal(let dir, let cmd):     return "Terminal: cd \(prettyPath(dir)) && \(cmd)"
        case .shell(let binary, let args):    return "\(binary) \(args.joined(separator: " "))"
        }
    }

    /// True if this action is fully specified and can run immediately (no missing fields).
    nonisolated var isExecutable: Bool {
        switch self {
        case .openApp(let name):
            return !name.isEmpty
        case .terminal(let dir, let cmd):
            return !dir.isEmpty && !cmd.isEmpty
        case .shell(let binary, _):
            return !binary.isEmpty
        }
    }
}

// MARK: - Discriminator helpers (for picker UI)

enum CheckKind: String, CaseIterable, Hashable, Sendable {
    case http  = "HTTP"
    case tcp   = "TCP"
    case shell = "Shell"
}

extension CheckSpec {
    nonisolated var kind: CheckKind {
        switch self {
        case .http:  return .http
        case .tcp:   return .tcp
        case .shell: return .shell
        }
    }
}

enum StartKind: String, CaseIterable, Hashable, Sendable {
    case none     = "None"
    case openApp  = "Open App"
    case terminal = "Terminal"
    case shell    = "Shell"
}

extension Optional where Wrapped == StartSpec {
    nonisolated var kind: StartKind {
        switch self {
        case .none:                    return .none
        case .some(.openApp):          return .openApp
        case .some(.terminal):         return .terminal
        case .some(.shell):            return .shell
        }
    }
}

// MARK: - Binary resolution (for login-launched apps with minimal PATH)

enum BinaryResolver {
    static let standardPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
    ]

    /// Returns the first existing executable path for the given binary name across standard locations.
    static func resolve(_ name: String) -> String? {
        for dir in standardPaths {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Returns the resolved path if found, otherwise the first standard candidate (callers can decide).
    static func resolveOrFirst(_ name: String) -> String {
        resolve(name) ?? "/opt/homebrew/bin/\(name)"
    }
}

// MARK: - Helpers

private nonisolated func prettyPath(_ path: String) -> String {
    let home = NSHomeDirectory()
    return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
}
