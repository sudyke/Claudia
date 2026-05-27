import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private var authorized = false
    private var authorizationChecked = false

    func notify(service: String, isDown: Bool) {
        Task { @MainActor in
            await ensureAuthorized()
            guard authorized else { return }

            let content = UNMutableNotificationContent()
            if isDown {
                content.title = "\(service) went down"
                content.body = "Claudia stopped seeing \(service) respond."
            } else {
                content.title = "\(service) is back"
                content.body = "\(service) is responding again."
            }
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func ensureAuthorized() async {
        if authorizationChecked { return }
        authorizationChecked = true
        let center = UNUserNotificationCenter.current()
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            authorized = false
        }
    }
}
