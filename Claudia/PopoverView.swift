import SwiftUI
import ServiceManagement
import AppKit

struct PopoverView: View {
    @Environment(StatusMonitor.self) private var monitor
    @Environment(\.openSettings) private var openSettings
    @Bindable private var settings = AppSettings.shared
    @State private var launchAtLogin: Bool = false

    var body: some View {
        @Bindable var monitor = monitor

        VStack(alignment: .leading, spacing: 0) {
            header(monitor: monitor)
            Divider()
            serviceRows(monitor: monitor)
            Divider()
            controls(monitor: monitor)
            Divider()
            appControls
        }
        .frame(width: 300)
        .onAppear { syncLaunchAtLoginState() }
    }

    private func header(monitor: StatusMonitor) -> some View {
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

    private func serviceRows(monitor: StatusMonitor) -> some View {
        VStack(spacing: 8) {
            ServiceRow(
                name: "Docker",
                status: monitor.dockerStatus,
                startAction: { Task { await runStart(.docker, monitor: monitor) } }
            )
            ServiceRow(
                name: "Supabase",
                status: monitor.supabaseStatus,
                startAction: { Task { await runStart(.supabase, monitor: monitor) } }
            )
            ServiceRow(
                name: "Dev Server (3000)",
                status: monitor.devServerStatus,
                startAction: { Task { await runStart(.devServer, monitor: monitor) } }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func controls(monitor: StatusMonitor) -> some View {
        @Bindable var bindable = monitor
        VStack(spacing: 8) {
            Toggle("Notifications", isOn: $bindable.notificationsEnabled)
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

    private enum StartTarget { case docker, supabase, devServer }

    private func runStart(_ target: StartTarget, monitor: StatusMonitor) async {
        let ok: Bool
        switch target {
        case .docker:
            ok = await startDocker()
        case .supabase:
            if settings.supabaseProjectPath.isEmpty {
                openSettingsWindow()
                return
            }
            ok = await startSupabase(projectPath: settings.supabaseProjectPath)
        case .devServer:
            if settings.devServerProjectPath.isEmpty {
                openSettingsWindow()
                return
            }
            ok = await startDevServer(
                projectPath: settings.devServerProjectPath,
                command: settings.devServerCommand.isEmpty ? "npm run dev" : settings.devServerCommand
            )
        }
        // Whether the action launched a process or not, poll shortly to reflect new reality.
        _ = ok
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
    let name: String
    let status: ServiceStatus
    let startAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(color)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
            Text(name)
                .font(.body)
            Spacer()
            if status == .down {
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
