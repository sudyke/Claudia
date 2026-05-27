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
                Text("Claudia will run `supabase start` in this folder when you click the Supabase row while it's down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dev Server") {
                pathPicker(
                    label: "Project folder",
                    binding: $settings.devServerProjectPath
                )
                LabeledContent("Start command") {
                    TextField("", text: $settings.devServerCommand, prompt: Text("npm run dev"))
                        .textFieldStyle(.roundedBorder)
                }
                Text("Claudia will open Terminal and run this command in the project folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 360)
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
