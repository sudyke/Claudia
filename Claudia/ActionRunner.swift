import Foundation

// Dispatches a StartSpec to the appropriate launcher. Runs off the main actor.
enum ActionRunner {
    nonisolated static func run(_ spec: StartSpec) async -> Bool {
        guard spec.isExecutable else { return false }

        switch spec {
        case .openApp(let name):
            return await runShell("/usr/bin/open", ["-a", name], timeout: 5)
        case .terminal(let workdir, let command):
            return await openInTerminal(workdir: workdir, command: command)
        case .shell(let binary, let args):
            guard FileManager.default.isExecutableFile(atPath: binary) else { return false }
            return await runShell(binary, args, timeout: 10)
        }
    }
}

private nonisolated func openInTerminal(workdir: String, command: String) async -> Bool {
    let bashEscapedDir = workdir.replacingOccurrences(of: "'", with: "'\\''")
    let bashCommand = "cd '\(bashEscapedDir)' && \(command)"
    let appleScriptEscaped = bashCommand
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")

    let script = """
    tell application "Terminal"
        activate
        do script "\(appleScriptEscaped)"
    end tell
    """

    return await runShell("/usr/bin/osascript", ["-e", script], timeout: 10)
}
