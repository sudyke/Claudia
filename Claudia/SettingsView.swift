import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            ServicesSettingsView()
                .tabItem { Label("Services", systemImage: "list.bullet") }
                .padding(20)
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .padding(20)
        }
        .frame(width: 620, height: 480)
    }
}

// MARK: - Services tab

private struct ServicesSettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var editingService: Service?
    @State private var showingPresetPicker = false
    @State private var serviceToDelete: Service?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Monitored services")
                    .font(.headline)
                Spacer()
                Button {
                    showingPresetPicker = true
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 12)

            if settings.services.isEmpty {
                emptyState
            } else {
                serviceList
            }
        }
        .sheet(isPresented: $showingPresetPicker) {
            PresetPickerSheet { pickedService in
                if let pickedService {
                    editingService = pickedService
                }
            }
        }
        .sheet(item: $editingService) { svc in
            ServiceEditorSheet(service: svc) { saved in
                if let saved {
                    if settings.services.contains(where: { $0.id == saved.id }) {
                        settings.update(saved)
                    } else {
                        settings.add(saved)
                    }
                }
            }
        }
        .alert(item: $serviceToDelete) { svc in
            Alert(
                title: Text("Delete \"\(svc.name)\"?"),
                message: Text("Claudia will stop monitoring this service. You can re-add it later from presets."),
                primaryButton: .destructive(Text("Delete")) {
                    settings.delete(svc)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No services yet")
                .font(.callout)
            Text("Click Add Service to pick from common presets or define your own.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var serviceList: some View {
        List {
            ForEach(settings.services) { svc in
                ServiceListRow(
                    service: svc,
                    onToggle: { newValue in
                        var copy = svc
                        copy.enabled = newValue
                        settings.update(copy)
                    },
                    onEdit:   { editingService = svc },
                    onDelete: { serviceToDelete = svc }
                )
            }
            .onMove { offsets, dest in
                settings.move(from: offsets, to: dest)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }
}

private struct ServiceListRow: View {
    let service: Service
    let onToggle: (Bool) -> Void
    let onEdit:   () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { service.enabled }, set: { onToggle($0) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.body)
                Text(service.check.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit")

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Delete")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - General tab

private struct GeneralSettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Send notifications when a service goes down", isOn: $settings.notificationsEnabled)
                Text("Recovery notifications (a service coming back up) always fire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Launch Claudia at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
            Section {
                LabeledContent("Poll interval", value: "Every 5 seconds")
                Text("Polling cadence is fixed at 5 seconds with small jitter. Configurable in a future release if there's demand.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
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
