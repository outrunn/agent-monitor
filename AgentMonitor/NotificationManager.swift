import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func notify(session: AgentSession) {
        let content = UNMutableNotificationContent()

        let label = session.issueTitle ?? session.issue ?? String(session.prompt.prefix(50))

        if let question = session.pendingQuestion {
            content.title = "Agent Needs Input"
            content.subtitle = label
            content.body = String(question.prefix(200))
            content.sound = .default
        } else if session.status == .failed {
            content.title = "Agent Failed"
            content.subtitle = label
            content.sound = UNNotificationSound.defaultCritical
        } else {
            content.title = "Agent Completed"
            content.subtitle = label
            if let cost = session.costUSD {
                content.body = String(format: "$%.4f", cost)
            }
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "agent-\(session.id)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
