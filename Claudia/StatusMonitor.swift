import Foundation
import Observation

enum ServiceStatus: Sendable, Equatable {
    case up
    case down
    case unknown
}

enum ServiceKind: Sendable {
    case docker
    case supabase
    case devServer

    var displayName: String {
        switch self {
        case .docker:    return "Docker"
        case .supabase:  return "Supabase"
        case .devServer: return "Dev Server (3000)"
        }
    }
}

@MainActor
@Observable
final class StatusMonitor {
    var dockerStatus: ServiceStatus = .unknown
    var supabaseStatus: ServiceStatus = .unknown
    var devServerStatus: ServiceStatus = .unknown
    var notificationsEnabled: Bool = true
    var lastChecked: Date = .now
    var shouldPoll: Bool = true

    // Owned by AppDelegate; called whenever overallStatus may have changed.
    @ObservationIgnored var onIconUpdate: (@MainActor () -> Void)?

    @ObservationIgnored private var previousDocker: ServiceStatus = .unknown
    @ObservationIgnored private var previousSupabase: ServiceStatus = .unknown
    @ObservationIgnored private var previousDevServer: ServiceStatus = .unknown
    @ObservationIgnored private var suppressNextDownAlert = false
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let notifications = NotificationManager()

    // Worst-of-three: .down beats .unknown beats .up.
    var overallStatus: ServiceStatus {
        let all = [dockerStatus, supabaseStatus, devServerStatus]
        if all.contains(.down) { return .down }
        if all.contains(.unknown) { return .unknown }
        return .up
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.poll()
            while !Task.isCancelled {
                let interval: UInt64 = 5_000_000_000
                let jitter = UInt64.random(in: 0...500_000_000)
                try? await Task.sleep(nanoseconds: interval + jitter)
                guard !Task.isCancelled else { break }
                guard let self else { break }
                if self.shouldPoll {
                    await self.poll()
                }
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollNow() {
        Task { await poll() }
    }

    func pause() {
        shouldPoll = false
        dockerStatus = .unknown
        supabaseStatus = .unknown
        devServerStatus = .unknown
        onIconUpdate?()
    }

    func resume() {
        shouldPoll = true
        // First poll after resume is a baseline — suppress UP→DOWN alerts for one cycle
        // (services may still be spinning up after wake).
        suppressNextDownAlert = true
        Task { await poll() }
    }

    private func poll() async {
        async let d = checkDocker()
        async let s = checkSupabase()
        async let v = checkDevServer()
        let (docker, supa, dev) = await (d, s, v)

        apply(.docker,    docker ? .up : .down)
        apply(.supabase,  supa   ? .up : .down)
        apply(.devServer, dev    ? .up : .down)

        lastChecked = .now
        suppressNextDownAlert = false
        onIconUpdate?()
    }

    private func apply(_ kind: ServiceKind, _ new: ServiceStatus) {
        let previous: ServiceStatus
        switch kind {
        case .docker:
            previous = previousDocker
            dockerStatus = new
            previousDocker = new
        case .supabase:
            previous = previousSupabase
            supabaseStatus = new
            previousSupabase = new
        case .devServer:
            previous = previousDevServer
            devServerStatus = new
            previousDevServer = new
        }

        guard new != previous else { return }
        // First observation of any state is a silent baseline — never notify out of .unknown.
        if previous == .unknown { return }

        if new == .down && notificationsEnabled && !suppressNextDownAlert {
            notifications.notify(service: kind.displayName, isDown: true)
        } else if new == .up && previous == .down {
            notifications.notify(service: kind.displayName, isDown: false)
        }
    }
}
