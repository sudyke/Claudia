import SwiftUI
import AppKit

/// Form to add or edit a single Service. Receives a Service (new or existing) and returns
/// either a saved Service (possibly modified) or nil (cancelled) via onSave.
struct ServiceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    // Local form state
    @State private var name: String
    @State private var enabled: Bool
    @State private var checkKind: CheckKind
    @State private var startKind: StartKind

    // Check fields
    @State private var httpURL: String
    @State private var httpMethod: HTTPMethod
    @State private var tcpHost: String
    @State private var tcpPort: Int
    @State private var checkBinary: String
    @State private var checkArgs: String

    // Start fields
    @State private var openAppName: String
    @State private var terminalWorkdir: String
    @State private var terminalCommand: String
    @State private var startBinary: String
    @State private var startArgs: String

    private let originalID: UUID
    let onSave: (Service?) -> Void

    init(service: Service, onSave: @escaping (Service?) -> Void) {
        self.originalID = service.id
        self.onSave = onSave
        _name    = State(initialValue: service.name)
        _enabled = State(initialValue: service.enabled)
        _checkKind = State(initialValue: service.check.kind)
        _startKind = State(initialValue: service.startCommand.kind)

        switch service.check {
        case .http(let url, let method):
            _httpURL = State(initialValue: url)
            _httpMethod = State(initialValue: method)
            _tcpHost = State(initialValue: "localhost"); _tcpPort = State(initialValue: 5432)
            _checkBinary = State(initialValue: ""); _checkArgs = State(initialValue: "")
        case .tcp(let host, let port):
            _httpURL = State(initialValue: "http://localhost:8080"); _httpMethod = State(initialValue: .head)
            _tcpHost = State(initialValue: host); _tcpPort = State(initialValue: port)
            _checkBinary = State(initialValue: ""); _checkArgs = State(initialValue: "")
        case .shell(let binary, let args):
            _httpURL = State(initialValue: "http://localhost:8080"); _httpMethod = State(initialValue: .head)
            _tcpHost = State(initialValue: "localhost"); _tcpPort = State(initialValue: 5432)
            _checkBinary = State(initialValue: binary); _checkArgs = State(initialValue: args.joined(separator: " "))
        }

        switch service.startCommand {
        case .none:
            _openAppName = State(initialValue: "")
            _terminalWorkdir = State(initialValue: ""); _terminalCommand = State(initialValue: "")
            _startBinary = State(initialValue: ""); _startArgs = State(initialValue: "")
        case .some(.openApp(let n)):
            _openAppName = State(initialValue: n)
            _terminalWorkdir = State(initialValue: ""); _terminalCommand = State(initialValue: "")
            _startBinary = State(initialValue: ""); _startArgs = State(initialValue: "")
        case .some(.terminal(let dir, let cmd)):
            _openAppName = State(initialValue: "")
            _terminalWorkdir = State(initialValue: dir); _terminalCommand = State(initialValue: cmd)
            _startBinary = State(initialValue: ""); _startArgs = State(initialValue: "")
        case .some(.shell(let bin, let args)):
            _openAppName = State(initialValue: "")
            _terminalWorkdir = State(initialValue: ""); _terminalCommand = State(initialValue: "")
            _startBinary = State(initialValue: bin); _startArgs = State(initialValue: args.joined(separator: " "))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Edit service").font(.title3.weight(.semibold))
                Spacer()
                Button("Cancel") { onSave(nil); dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Save") {
                    onSave(buildService())
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding()

            Form {
                Section("Basic") {
                    TextField("Name", text: $name)
                    Toggle("Enabled", isOn: $enabled)
                }

                Section("Health check") {
                    Picker("Type", selection: $checkKind) {
                        ForEach(CheckKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch checkKind {
                    case .http:
                        TextField("URL", text: $httpURL, prompt: Text("http://localhost:3000"))
                        Picker("Method", selection: $httpMethod) {
                            ForEach(HTTPMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        captionText("Any HTTP response counts as up. Use HEAD if the server doesn't have a /health endpoint.")
                    case .tcp:
                        TextField("Host", text: $tcpHost, prompt: Text("localhost"))
                        portField("Port", binding: $tcpPort)
                        captionText("Up if the TCP socket accepts a connection. Use for databases without an HTTP layer.")
                    case .shell:
                        binaryPicker(label: "Binary", binding: $checkBinary)
                        TextField("Arguments", text: $checkArgs, prompt: Text("info"))
                        captionText("Up if the command exits with status 0. Login-launched apps inherit a minimal PATH — use absolute paths.")
                    }
                }

                Section("Start action") {
                    Picker("When down, clicking ▶ Start will:", selection: $startKind) {
                        ForEach(StartKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch startKind {
                    case .none:
                        captionText("No start action. The row shows a down status but no button.")
                    case .openApp:
                        TextField("App name", text: $openAppName, prompt: Text("Docker"))
                        captionText("Runs `open -a <name>`. Use the name as it appears in /Applications.")
                    case .terminal:
                        pathPicker(label: "Working folder", binding: $terminalWorkdir)
                        TextField("Command", text: $terminalCommand, prompt: Text("npm run dev"))
                        captionText("Opens Terminal.app and runs `cd <folder> && <command>`. Use for long-running dev servers.")
                    case .shell:
                        binaryPicker(label: "Binary", binding: $startBinary)
                        TextField("Arguments", text: $startArgs, prompt: Text("services start postgresql"))
                        captionText("Runs the command and waits for it to finish. Use for one-shot commands that return quickly.")
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 580, height: 600)
    }

    // MARK: - Helper views

    private func captionText(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func portField(_ label: String, binding: Binding<Int>) -> some View {
        LabeledContent(label) {
            TextField("", value: binding, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
        }
    }

    private func pathPicker(label: String, binding: Binding<String>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField("", text: binding, prompt: Text("/path/to/project"))
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

    private func binaryPicker(label: String, binding: Binding<String>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField("", text: binding, prompt: Text("/opt/homebrew/bin/docker"))
                    .textFieldStyle(.roundedBorder)
                    .truncationMode(.middle)
                Button("Choose…") {
                    if let chosen = pickFile(startingAt: binding.wrappedValue) {
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
        if !path.isEmpty { panel.directoryURL = URL(fileURLWithPath: path) }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func pickFile(startingAt path: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if !path.isEmpty { panel.directoryURL = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent) }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    // MARK: - Build Service from form state

    private func buildService() -> Service {
        let check: CheckSpec = {
            switch checkKind {
            case .http:  return .http(url: httpURL, method: httpMethod)
            case .tcp:   return .tcp(host: tcpHost, port: tcpPort)
            case .shell: return .shell(binary: checkBinary, args: splitArgs(checkArgs))
            }
        }()

        let start: StartSpec? = {
            switch startKind {
            case .none:     return nil
            case .openApp:  return .openApp(name: openAppName)
            case .terminal: return .terminal(workdir: terminalWorkdir, command: terminalCommand)
            case .shell:    return .shell(binary: startBinary, args: splitArgs(startArgs))
            }
        }()

        return Service(id: originalID, name: name, check: check, startCommand: start, enabled: enabled)
    }

    private func splitArgs(_ s: String) -> [String] {
        s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }
}
