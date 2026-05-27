import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Supabase") {
                pathPicker(
                    label: "Project folder",
                    binding: $settings.supabaseProjectPath
                )
                portField(label: "Health-check port", binding: $settings.supabasePort)
                Text("Claudia probes `http://localhost:<port>/health` and runs `supabase start` in the project folder when you click the row while it's down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dev Server") {
                pathPicker(
                    label: "Project folder",
                    binding: $settings.devServerProjectPath
                )
                portField(label: "Port", binding: $settings.devServerPort)
                LabeledContent("Start command") {
                    TextField("", text: $settings.devServerCommand, prompt: Text("npm run dev"))
                        .textFieldStyle(.roundedBorder)
                }
                Text("Claudia probes `http://localhost:<port>` and opens Terminal to run the command in the project folder when you click the row while it's down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 460)
    }

    private func portField(label: String, binding: Binding<Int>) -> some View {
        LabeledContent(label) {
            TextField("", value: binding, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
        }
    }

    private func pathPicker(label: String, binding: Binding<String>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField("", text: binding, prompt: Text("/path/to/repo"))
                    .textFieldStyle(.roundedBorder)
                    .truncationMode(.middle)
                Button("Choose…") {
                    if let chosen = pickFolder(startingAt: binding.wrappedValue) {
                        binding.wrappedValue = chosen
                    }
                }
            }
        }
    }

    private func pickFolder(startingAt path: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path)
        }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
