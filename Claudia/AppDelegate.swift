import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var welcomeWindow: NSWindow?
    private var lifecycle: LifecycleObserver?
    private let monitor = StatusMonitor()
    private let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders with LSUIElement: no Dock, no app switcher.
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.image = StatusIcon.image(for: monitor.overallStatus)
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environment(monitor)
        )

        monitor.onIconUpdate = { [weak self] in
            self?.updateIcon()
        }
        lifecycle = LifecycleObserver(monitor: monitor)
        monitor.start()

        // First-launch welcome flow.
        if !settings.hasCompletedFirstRun {
            DispatchQueue.main.async { [weak self] in
                self?.showWelcome()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func updateIcon() {
        statusItem.button?.image = StatusIcon.image(for: monitor.overallStatus)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }

    private func showWelcome() {
        // Accessory apps need an explicit window to host a SwiftUI sheet on first launch.
        let hosting = NSHostingController(rootView: WelcomeSheet())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to Claudia"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
