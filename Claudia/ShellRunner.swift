import Foundation

// Single shared async Process runner. Every shell command in Claudia goes through this.
// Hard timeout via watchdog. Set terminationHandler before run() to avoid races.
nonisolated func runShell(_ launchPath: String, _ args: [String], timeout: TimeInterval) async -> Bool {
    await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        process.terminationHandler = { p in
            cont.resume(returning: p.terminationStatus == 0)
        }

        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            cont.resume(returning: false)
            return
        }

        // Watchdog: kill the process if it outlives the timeout.
        // Detached so it survives parent Task cancellation and still cleans up the process,
        // which then fires terminationHandler and resumes the continuation.
        let holder = ProcessHolder(process)
        Task.detached {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            holder.terminateIfRunning()
        }
    }
}

// Foundation's Process is not Sendable. Wrapping it for the watchdog closure is safe
// because Process.isRunning and Process.terminate are documented thread-safe APIs,
// and the watchdog only reads/calls those two — never mutates Process state otherwise.
private nonisolated final class ProcessHolder: @unchecked Sendable {
    private let process: Process
    nonisolated init(_ process: Process) { self.process = process }
    nonisolated func terminateIfRunning() {
        if process.isRunning { process.terminate() }
    }
}
