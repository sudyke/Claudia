import Foundation

// Free async actions to start each service. All go through runShell, never raw Process.
//
// Docker: `open -a Docker` (NSWorkspace would work too; shelling out keeps the runShell discipline).
// Supabase + Dev Server: open Terminal.app via osascript and run `cd PATH && CMD` so the user
// sees output, can Ctrl+C, and the long-running process is decoupled from Claudia's lifetime.

nonisolated func startDocker() async -> Bool {
    await runShell("/usr/bin/open", ["-a", "Docker"], timeout: 5)
}

nonisolated func startSupabase(projectPath: String) async -> Bool {
    await startInTerminal(workdir: projectPath, command: "supabase start")
}

nonisolated func startDevServer(projectPath: String, command: String) async -> Bool {
    await startInTerminal(workdir: projectPath, command: command)
}

private nonisolated func startInTerminal(workdir: String, command: String) async -> Bool {
    guard !workdir.isEmpty else { return false }
    // Escape single quotes for the bash command, then escape backslashes/quotes for AppleScript.
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
