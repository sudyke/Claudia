import Foundation

// Dispatches a StartSpec to the appropriate launcher. Runs off the main actor.
enum ActionRunner {
    nonisolated static func run(_ spec: StartSpec, terminalInBackground: Bool = false) async -> Bool {
        guard spec.isExecutable else { return false }

        switch spec {
        case .openApp(let name):
            return await runShell("/usr/bin/open", ["-a", name], timeout: 5)
        case .terminal(let workdir, let command):
            return await openInTerminal(workdir: workdir, command: command, inBackground: terminalInBackground)
        case .shell(let binary, let args):
            guard FileManager.default.isExecutableFile(atPath: binary) else { return false }
            return await runShell(binary, args, timeout: 10)
        }
    }
}

// Opens Terminal.app and runs `cd <workdir> && <command>`.
//
// Two subtleties this function handles:
//
// 1) Double-window bug: when Terminal isn't already running, calling `do script` triggers
//    Terminal to launch, which opens an *empty default window* per the user's prefs.
//    Then `do script` creates a *second* window with our command. We avoid this by
//    detecting the not-running case, launching Terminal first, waiting briefly, and
//    placing our command in window 1 (the just-opened default window) rather than
//    creating a new one.
//
// 2) Background mode: if `inBackground`, we don't `activate` Terminal (no focus steal)
//    and we miniaturize the new window (yellow Dock icon). The user can click it to
//    expand and see logs when they want.
private nonisolated func openInTerminal(workdir: String, command: String, inBackground: Bool) async -> Bool {
    let bashEscapedDir = workdir.replacingOccurrences(of: "'", with: "'\\''")
    let bashCommand = "cd '\(bashEscapedDir)' && \(command)"
    let appleScriptEscaped = bashCommand
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")

    let focusLine = inBackground
        ? "set miniaturized of window 1 to true"
        : "activate"

    let script = """
    tell application "Terminal"
        if not running then
            launch
            delay 0.4
            do script "\(appleScriptEscaped)" in window 1
        else
            do script "\(appleScriptEscaped)"
        end if
        \(focusLine)
    end tell
    """

    return await runShell("/usr/bin/osascript", ["-e", script], timeout: 10)
}
