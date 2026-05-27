import SwiftUI

/// Modal that shows the preset library grouped by category, plus a "Custom" option.
/// On dismissal, returns either a pre-filled Service (from a preset) or nil (cancelled).
struct PresetPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (Service?) -> Void

    @State private var query: String = ""

    private var groups: [(PresetCategory, [ServicePreset])] {
        let all = Presets.grouped()
        guard !query.isEmpty else { return all }
        let q = query.lowercased()
        return all.compactMap { (cat, items) in
            let filtered = items.filter { $0.name.lowercased().contains(q) || $0.description.lowercased().contains(q) }
            return filtered.isEmpty ? nil : (cat, filtered)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Add a service")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Cancel") {
                    onPick(nil)
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search presets", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    customCard
                    ForEach(groups, id: \.0) { (cat, items) in
                        sectionView(cat, items)
                    }
                }
                .padding()
            }
        }
        .frame(width: 560, height: 540)
    }

    private var customCard: some View {
        Button {
            let blank = Service(
                name: "New Service",
                check: .http(url: "http://localhost:8080", method: .head),
                startCommand: nil
            )
            onPick(blank)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.title3)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom service").font(.body.weight(.medium))
                    Text("Configure your own check and start command")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    PresetRow(preset: preset) {
                        onPick(preset.makeService())
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PresetRow: View {
    let preset: ServicePreset
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 28)
                    .foregroundStyle(.secondary)
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
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(.background.opacity(0.001))  // makes whole row clickable
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch preset.category {
        case .container: return "shippingbox"
        case .database:  return "cylinder.split.1x2"
        case .devServer: return "server.rack"
        case .tool:      return "wrench.and.screwdriver"
        }
    }
}
