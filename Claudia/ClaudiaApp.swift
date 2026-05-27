import SwiftUI

@main
struct ClaudiaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The Settings scene gives us Cmd+, and the openSettings environment value.
        // LSUIElement keeps the app out of the Dock; AppDelegate brings the Settings
        // window to front via NSApp.activate when opened from the popover.
        Settings {
            SettingsView()
        }
    }
}
