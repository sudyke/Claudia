import SwiftUI
import ServiceManagement
import AppKit

struct PopoverView: View {
    @Environment(StatusMonitor.self) private var monitor
    @Environment(\.openSettings) private var openSettings
    @Bindable private var settings = AppSettings.shared
    @State private var launchAtLogin: Bool = false

    private var activeServices: [Service] {
        settings.services.filter(\.enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if activeServices.isEmpty {
                emptyState
            } else {
                serviceRows
            }

            Divider()
            controls
            Divider()
            appControls
        }
        .frame(width: 320)
        .onAppear { syncLaunchAtLoginState() }
    }

    private var header: some View {
        HStack {
            Text("Claudia")
                .font(.headline)
            Spacer()
            Text(monitor.lastChecked, format: .relative(presentation: .numeric))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No services configured")
                .font(.callout)
            Button("Add a service…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var serviceRows: some View {
        VStack(spacing: 8) {
            ForEach(activeServices) { service in
                ServiceRow(
                    service: service,
                    status: monitor.states[service.id]?.status ?? .unknown,
                    startAction: { Task { await runStart(for: service) } }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Toggle("Notifications", isOn: $settings.notificationsEnabled)
                .toggleStyle(.switch)
                .help("When on, Claudia sends a banner if a service goes down. Turn off while you're intentionally stopping services. Recovery alerts always fire.")
            Button {
                monitor.pollNow()
            } label: {
                Label("Refresh Now", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var appControls: some View {
        VStack(spacing: 8) {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
            HStack(spacing: 8) {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - Actions

    private func runStart(for service: Service) async {
        guard let action = service.startCommand else {
            // No start action configured → take user to settings to add one.
            openSettingsWindow()
            return
        }
        if !action.isExecutable {
            // Action exists but is missing required fields (e.g. empty workdir).
            openSettingsWindow()
            return
        }
        // Snapshot the setting on main before kicking off the nonisolated runner.
        let inBackground = settings.launchTerminalInBackground
        _ = await ActionRunner.run(action, terminalInBackground: inBackground)
        // Give the service a moment to spin up, then poll.
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        monitor.pollNow()
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private func syncLaunchAtLoginState() {
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}

private struct ServiceRow: View {
    let service: Service
    let status: ServiceStatus
    let startAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(color)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
            Text(service.name)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if status == .down && service.startCommand != nil {
                Button(action: startAction) {
                    Label("Start", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var symbolName: String {
        switch status {
        case .up:      return "checkmark.circle.fill"
        case .down:    return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var color: Color {
        switch status {
        case .up:      return .green
        case .down:    return .red
        case .unknown: return .orange
        }
    }

    private var label: String {
        switch status {
        case .up:      return "Up"
        case .down:    return "Down"
        case .unknown: return "—"
        }
    }
}
