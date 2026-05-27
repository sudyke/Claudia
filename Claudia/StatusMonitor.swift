import Foundation
import Observation

enum ServiceStatus: Sendable, Equatable {
    case up
    case down
    case unknown
}

/// Per-service state owned by StatusMonitor (current visible status + last-observed for
/// transition detection). Kept in a dictionary keyed by Service.id so the popover stays
/// data-driven over the AppSettings.services array.
struct ServiceState: Sendable {
    var status: ServiceStatus = .unknown
    fileprivate var previous: ServiceStatus = .unknown
}

@MainActor
@Observable
final class StatusMonitor {
    /// Visible per-service status, keyed by Service.id.
    var states: [UUID: ServiceState] = [:]
    var lastChecked: Date = .now
    var shouldPoll: Bool = true

    @ObservationIgnored var onIconUpdate: (@MainActor () -> Void)?

    @ObservationIgnored private var suppressNextDownAlert = false
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let notifications = NotificationManager()
    @ObservationIgnored private let settings = AppSettings.shared

    // Worst-of-N across enabled services.
    var overallStatus: ServiceStatus {
        let active = settings.services.filter(\.enabled)
        guard !active.isEmpty else { return .unknown }
        let statuses = active.map { states[$0.id]?.status ?? .unknown }
        if statuses.contains(.down) { return .down }
        if statuses.contains(.unknown) { return .unknown }
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
        // Mark every state .unknown (visible). Keep `previous` so we can detect transitions
        // when we resume — first cycle is a baseline.
        for key in states.keys {
            states[key]?.status = .unknown
        }
        onIconUpdate?()
    }

    func resume() {
        shouldPoll = true
        suppressNextDownAlert = true
        Task { await poll() }
    }

    private func poll() async {
        let active = settings.services.filter(\.enabled)

        // Ensure a state row exists for every active service.
        for service in active where states[service.id] == nil {
            states[service.id] = ServiceState()
        }
        // Drop state rows for services that were deleted/disabled.
        let activeIDs = Set(active.map(\.id))
        states = states.filter { activeIDs.contains($0.key) }

        // Parallel checks. Capture services + spec snapshots before the await
        // so we don't reach back into settings off the main actor.
        let snapshot: [(UUID, String, CheckSpec)] = active.map { ($0.id, $0.name, $0.check) }

        let results: [(UUID, Bool)] = await withTaskGroup(of: (UUID, Bool).self) { group in
            for (id, _, spec) in snapshot {
                group.addTask { (id, await CheckRunner.run(spec)) }
            }
            var collected: [(UUID, Bool)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        let nameByID = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.0, $0.1) })
        for (id, ok) in results {
            apply(id: id, name: nameByID[id] ?? "", new: ok ? .up : .down)
        }

        lastChecked = .now
        suppressNextDownAlert = false
        onIconUpdate?()
    }

    private func apply(id: UUID, name: String, new: ServiceStatus) {
        var state = states[id] ?? ServiceState()
        let previous = state.previous
        state.status = new
        state.previous = new
        states[id] = state

        guard new != previous else { return }
        // First observation out of .unknown is silent baseline.
        if previous == .unknown { return }

        if new == .down && settings.notificationsEnabled && !suppressNextDownAlert {
            notifications.notify(service: name, isDown: true)
        } else if new == .up && previous == .down {
            notifications.notify(service: name, isDown: false)
        }
    }
}
