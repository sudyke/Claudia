import SwiftUI
import AppKit

/// Shown once on first launch to introduce Claudia and let the user pick starter services
/// from the preset library. Marks AppSettings.hasCompletedFirstRun on dismiss.
struct WelcomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    @State private var selected: Set<String> = ["docker", "supabase", "nextjs"]

    private var groups: [(PresetCategory, [ServicePreset])] {
        Presets.grouped()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groups, id: \.0) { (cat, items) in
                        sectionView(cat, items)
                    }
                }
                .padding()
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 600)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome to Claudia")
                .font(.title2.weight(.semibold))
            Text("Pick which local services you'd like Claudia to monitor. You can add or remove any of these later in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var footer: some View {
        HStack {
            Button("Skip") {
                finish(replaceServices: false)
            }
            Spacer()
            Text("\(selected.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Add selected") {
                finish(replaceServices: true)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }

    private func sectionView(_ category: PresetCategory, _ items: [ServicePreset]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 4) {
                ForEach(items) { preset in
                    PresetCheckRow(
                        preset: preset,
                        isOn: Binding(
                            get: { selected.contains(preset.id) },
                            set: { newValue in
                                if newValue { selected.insert(preset.id) }
                                else        { selected.remove(preset.id) }
                            }
                        )
                    )
                }
            }
        }
    }

    private func finish(replaceServices: Bool) {
        if replaceServices && !selected.isEmpty {
            let chosen = groups.flatMap { $0.1 }.filter { selected.contains($0.id) }
            settings.services = chosen.map { $0.makeService() }
        }
        settings.hasCompletedFirstRun = true
        dismiss()
    }
}

private struct PresetCheckRow: View {
    let preset: ServicePreset
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(preset.name).font(.body)
                    if preset.needsPath {
                        Text("• needs path")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
    }
}
