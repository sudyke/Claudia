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

    private init() {
        let d = UserDefaults.standard
        supabaseProjectPath = d.string(forKey: Keys.supabasePath) ?? ""
        devServerProjectPath = d.string(forKey: Keys.devServerPath) ?? ""
        devServerCommand = d.string(forKey: Keys.devServerCommand) ?? "npm run dev"
    }

    private enum Keys {
        static let supabasePath    = "claudia.supabaseProjectPath"
        static let devServerPath   = "claudia.devServerProjectPath"
        static let devServerCommand = "claudia.devServerCommand"
    }
}
