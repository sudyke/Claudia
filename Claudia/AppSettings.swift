import Foundation
import Observation

// App-wide user preferences. Backed by UserDefaults; observed via @Observable so SwiftUI
// views re-render on change. Singleton because preferences are genuinely global state
// and the Settings scene can't easily share an @Environment object with the popover.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var services: [Service] {
        didSet { persistServices() }
    }
    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    var hasCompletedFirstRun: Bool {
        didSet { UserDefaults.standard.set(hasCompletedFirstRun, forKey: Keys.firstRunComplete) }
    }

    private init() {
        let d = UserDefaults.standard

        // Notifications default to on.
        if d.object(forKey: Keys.notificationsEnabled) == nil {
            notificationsEnabled = true
        } else {
            notificationsEnabled = d.bool(forKey: Keys.notificationsEnabled)
        }

        hasCompletedFirstRun = d.bool(forKey: Keys.firstRunComplete)

        // Load services. Three paths:
        //   1. JSON exists → decode.
        //   2. Legacy keys exist → migrate to Services and write JSON.
        //   3. Neither → seed with Presets.defaults().
        if let data = d.data(forKey: Keys.servicesJSON),
           let decoded = try? JSONDecoder().decode([Service].self, from: data) {
            services = decoded
        } else if AppSettings.hasLegacyKeys(in: d) {
            services = AppSettings.migrateLegacy(from: d)
            // Mark first-run complete so a user with a working setup isn't shown the picker.
            hasCompletedFirstRun = true
        } else {
            services = Presets.defaults()
        }

        // Persist whatever path we took so the JSON key is always present from now on.
        persistServices()
    }

    private func persistServices() {
        guard let data = try? JSONEncoder().encode(services) else { return }
        UserDefaults.standard.set(data, forKey: Keys.servicesJSON)
    }

    func add(_ service: Service) {
        services.append(service)
    }

    func update(_ service: Service) {
        guard let idx = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[idx] = service
    }

    func delete(_ service: Service) {
        services.removeAll { $0.id == service.id }
    }

    func move(from offsets: IndexSet, to destination: Int) {
        // Manual move (avoids importing SwiftUI in the model layer).
        let moving = offsets.map { services[$0] }
        var remaining = services
        for index in offsets.sorted(by: >) {
            remaining.remove(at: index)
        }
        let removedBefore = offsets.filter { $0 < destination }.count
        let insertionIndex = destination - removedBefore
        remaining.insert(contentsOf: moving, at: max(0, min(insertionIndex, remaining.count)))
        services = remaining
    }

    // MARK: - Legacy migration

    private static func hasLegacyKeys(in d: UserDefaults) -> Bool {
        LegacyKeys.all.contains(where: { d.object(forKey: $0) != nil })
    }

    private static func migrateLegacy(from d: UserDefaults) -> [Service] {
        let supabasePort  = (d.object(forKey: LegacyKeys.supabasePort) as? Int).flatMap { $0 > 0 ? $0 : nil } ?? 54321
        let devServerPort = (d.object(forKey: LegacyKeys.devServerPort) as? Int).flatMap { $0 > 0 ? $0 : nil } ?? 3000
        let supabasePath  = d.string(forKey: LegacyKeys.supabasePath) ?? ""
        let devServerPath = d.string(forKey: LegacyKeys.devServerPath) ?? ""
        let devCommand    = d.string(forKey: LegacyKeys.devServerCommand) ?? "npm run dev"

        let docker = Service(
            name: "Docker",
            check: .shell(binary: BinaryResolver.resolveOrFirst("docker"), args: ["info"]),
            startCommand: .openApp(name: "Docker")
        )
        let supabase = Service(
            name: "Supabase",
            check: .http(url: "http://localhost:\(supabasePort)/health", method: .get),
            startCommand: .terminal(workdir: supabasePath, command: "supabase start")
        )
        let devServer = Service(
            name: "Dev Server",
            check: .http(url: "http://localhost:\(devServerPort)", method: .head),
            startCommand: .terminal(workdir: devServerPath, command: devCommand)
        )

        // Clean up legacy keys so we don't re-migrate.
        LegacyKeys.all.forEach { d.removeObject(forKey: $0) }

        return [docker, supabase, devServer]
    }

    private enum Keys {
        static let servicesJSON         = "claudia.services.v1"
        static let notificationsEnabled = "claudia.notificationsEnabled"
        static let firstRunComplete     = "claudia.firstRunComplete"
    }

    private enum LegacyKeys {
        static let supabasePath     = "claudia.supabaseProjectPath"
        static let devServerPath    = "claudia.devServerProjectPath"
        static let devServerCommand = "claudia.devServerCommand"
        static let supabasePort     = "claudia.supabasePort"
        static let devServerPort    = "claudia.devServerPort"

        static let all = [
            supabasePath, devServerPath, devServerCommand,
            supabasePort, devServerPort,
        ]
    }
}
