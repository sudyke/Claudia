import AppKit

@MainActor
final class LifecycleObserver {
    private let monitor: StatusMonitor
    private var observers: [NSObjectProtocol] = []

    init(monitor: StatusMonitor) {
        self.monitor = monitor
        let center = NSWorkspace.shared.notificationCenter

        let onPause: @Sendable (Notification) -> Void = { _ in
            Task { @MainActor in monitor.pause() }
        }
        let onResume: @Sendable (Notification) -> Void = { _ in
            Task { @MainActor in monitor.resume() }
        }

        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main, using: onPause))
        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main, using: onResume))
        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil, queue: .main, using: onPause))
        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil, queue: .main, using: onResume))
    }

    // No deinit: LifecycleObserver lives for the entire app lifetime; the OS reclaims
    // observers on process exit. Removing them earlier serves no purpose.
}
