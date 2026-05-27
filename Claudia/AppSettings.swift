import Foundation
import Observation

// App-wide user preferences. Backed by UserDefaults; observed via @Observable so SwiftUI
// views re-render on change. Singleton because preferences are genuinely global state
// and the Settings scene can't easily share an @Environment object with the popover.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var supabaseProjectPath: String {
        didSet { UserDefaults.standard.set(supabaseProjectPath, forKey: Keys.supabasePath) }
    }
    var devServerProjectPath: String {
        didSet { UserDefaults.standard.set(devServerProjectPath, forKey: Keys.devServerPath) }
    }
    var devServerCommand: String {
        didSet { UserDefaults.standard.set(devServerCommand, forKey: Keys.devServerCommand) }
    }
    var supabasePort: Int {
        didSet { UserDefaults.standard.set(supabasePort, forKey: Keys.supabasePort) }
    }
    var devServerPort: Int {
        didSet { UserDefaults.standard.set(devServerPort, forKey: Keys.devServerPort) }
    }

    private init() {
        let d = UserDefaults.standard
        supabaseProjectPath = d.string(forKey: Keys.supabasePath) ?? ""
        devServerProjectPath = d.string(forKey: Keys.devServerPath) ?? ""
        devServerCommand = d.string(forKey: Keys.devServerCommand) ?? "npm run dev"
        // Defaults match Supabase CLI (54321) and Next.js / Vite-default (3000).
        let storedSupabase = d.integer(forKey: Keys.supabasePort)
        supabasePort = storedSupabase > 0 ? storedSupabase : 54321
        let storedDev = d.integer(forKey: Keys.devServerPort)
        devServerPort = storedDev > 0 ? storedDev : 3000
    }

    private enum Keys {
        static let supabasePath     = "claudia.supabaseProjectPath"
        static let devServerPath    = "claudia.devServerProjectPath"
        static let devServerCommand = "claudia.devServerCommand"
        static let supabasePort     = "claudia.supabasePort"
        static let devServerPort    = "claudia.devServerPort"
    }
}
